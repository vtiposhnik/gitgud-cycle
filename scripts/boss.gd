class_name FormerVictor
extends Fighter

signal phase_changed(value: int)

@export var approach_speed: float = 58.0
@export var phase_aggression: Array[float] = [1.0, 1.20, 1.42]
@export var combo_frequency: Array[float] = [0.35, 0.65, 0.85]
@export var max_combo_attacks: Array[int] = [2, 3, 4]
@export var attack_selection_weights: Dictionary = {"slash":1.2,"overhead":0.9,"thrust":1.0,"sweep":0.85,"feint":0.8,"recall":0.65}
@export var decision_seed: int = 0
@export var repetition_penalty: float = 0.18
@export var minimum_decision_delay: float = 0.10
@export var stagger_duration: float = 2.0
@export var parry_stun: float = 0.44
@export var transition_duration: float = 1.65
var target: Challenger
# Combo is the current committed sequence; branches are chosen only after recovery.
var combo: Array = []
var recent_attacks: Array[String] = []
var rng := RandomNumberGenerator.new()
var stun_duration: float = 0.44
var decision_wait: float = 0.55
var attack_count: int = 0
var branches_taken: int = 0
var pending_followup: String = ""
var reposition_direction: float = 0
var reposition_duration: float = 0.22
var engage_distance: float = 60
var recoil: float = 0
var followup_weights: Dictionary = {
	"slash":{"thrust":1.0,"feint":0.8,"overhead":0.35},
	"overhead":{"recall":1.0,"slash":0.45},
	"thrust":{"slash":1.0,"sweep":0.65},
	"sweep":{"recall":1.0},
	"feint":{"slash":1.0,"overhead":0.5},
	"recall":{"thrust":1.0,"slash":0.6}
}
# Attack specifications are in seconds and native-resolution pixels.
var attacks := {
	"slash": {"name": "HORIZONTAL SLASH", "startup": 0.60, "active": 0.13, "recovery": 0.55, "damage": 20.0, "posture": 23.0, "size": Vector2(67, 29), "reach": 39, "height": -21, "parryable": true},
	"overhead": {"name": "OVERHEAD STRIKE", "startup": 0.84, "active": 0.15, "recovery": 0.85, "damage": 32.0, "posture": 42.0, "size": Vector2(29, 67), "reach": 31, "height": -31, "parryable": true},
	"thrust": {"name": "FORWARD THRUST", "startup": 0.49, "active": 0.17, "recovery": 0.63, "damage": 24.0, "posture": 26.0, "size": Vector2(77, 13), "reach": 48, "height": -18, "parryable": true},
	"sweep": {"name": "CHAIN SWEEP", "startup": 0.90, "active": 0.24, "recovery": 0.60, "damage": 26.0, "posture": 34.0, "size": Vector2(132, 15), "reach": 65, "height": -7, "parryable": false},
	"feint": {"name": "DELAYED HEAVY", "startup": 1.18, "active": 0.15, "recovery": 0.90, "damage": 35.0, "posture": 40.0, "size": Vector2(39, 63), "reach": 32, "height": -29, "parryable": true},
	"recall": {"name": "CHAIN RECALL", "startup": 0.65, "active": 0.19, "recovery": 0.76, "damage": 23.0, "posture": 32.0, "size": Vector2(93, 25), "reach": 59, "height": -23, "parryable": false}
}

func _init() -> void:
	is_boss = true
	max_health = 430
	max_posture = 100

func _ready() -> void:
	super._ready()
	if decision_seed == 0: rng.randomize()
	else: rng.seed = decision_seed
	hitbox = SwordHitbox.new()
	hitbox.wielder = self
	add_child(hitbox)

func _physics_process(delta: float) -> void:
	tick_common(delta)
	if not enabled or target == null: return
	velocity.y += 920 * delta
	if health > 0 and state != "transition":
		var desired: int = 3 if health / max_health < 0.35 else (2 if health / max_health <= 0.70 else 1)
		if desired > phase: enter_phase(desired)
	match state:
		"idle":
			velocity.x = move_toward(velocity.x, 0, 700 * delta)
			if state_time >= decision_wait and target.health > 0: begin_approach()
		"approach":
			face_target()
			var distance := absf(target.position.x - position.x)
			if distance <= engage_distance and state_time >= minimum_decision_delay:
				var opening := choose_attack(distance)
				if not opening.is_empty(): begin_attack(opening)
				else: velocity.x = facing * approach_speed * phase_aggression[phase-1]
			else: velocity.x = facing * approach_speed * phase_aggression[phase-1]
		"reposition":
			velocity.x = reposition_direction * 65 * phase_aggression[phase-1]
			if state_time >= reposition_duration:
				if not pending_followup.is_empty():
					var next := pending_followup
					pending_followup = ""
					begin_attack(next,true)
				else: begin_approach()
		"startup":
			velocity.x = 0
			if state_time >= float(attack.startup):
				change_state("active")
				hitbox.active = true
				feedback.emit("boss_swing", global_position + Vector2(facing * 24, -25))
		"active":
			velocity.x = facing * 112 if attack.id == "thrust" else 0.0
			hitbox.sample()
			if state == "active" and state_time >= float(attack.active):
				hitbox.active = false
				change_state("recovery")
		"recovery":
			velocity.x = move_toward(velocity.x, 0, 750 * delta)
			if state_time >= float(attack.recovery): finish_recovery()
		"staggered":
			velocity.x = 0
			if state_time >= stun_duration: change_state("idle")
		"transition":
			velocity.x = 0
			if state_time >= transition_duration: change_state("idle")
		"dead": velocity.x = 0
	# A small push only during punishable states; startup/active commitment stays intact.
	if state in ["idle","recovery","staggered"]: velocity.x += recoil
	recoil = move_toward(recoil,0,delta*210)
	move_and_slide()
	position.x = clampf(position.x, 24, 456)

func face_target() -> void:
	if target != null: facing = 1 if target.position.x >= position.x else -1

func begin_attack(id: String, followup: bool = false) -> void:
	if not followup: combo.clear()
	else: branches_taken += 1
	combo.append(id)
	recent_attacks.append(id)
	if recent_attacks.size() > 4: recent_attacks.pop_front()
	face_target()
	attack = attacks[id].duplicate()
	attack.id = id
	# Faster cadence without erasing the tells the player learned.
	attack.startup *= 1.0 if phase == 1 else (0.94 if phase == 2 else 0.87)
	attack.recovery *= 0.9 if phase == 3 else 1.0
	attack_count += 1
	hitbox.prepare(attack)
	change_state("startup")

func enter_phase(value: int) -> void:
	phase = value
	combo.clear()
	pending_followup = ""
	hitbox.active = false
	posture = 0
	change_state("transition")
	phase_changed.emit(phase)
	feedback.emit("phase", global_position + Vector2(0,-25))

func on_parried(amount: float) -> void:
	if health <= 0: return
	hitbox.active = false
	combo.clear()
	pending_followup = ""
	posture += amount
	posture_delay = 3.0
	stun_duration = parry_stun
	if posture >= max_posture:
		posture = 0
		stun_duration = stagger_duration
		feedback.emit("break", global_position + Vector2(0,-30))
	change_state("staggered")

func receive_attack(source: Fighter, data: Dictionary) -> String:
	if state == "transition": return "immune"
	var adjusted := data.duplicate()
	if state == "staggered" and stun_duration == stagger_duration:
		adjusted.damage = float(data.damage) * 1.5
	var result := super.receive_attack(source, adjusted)
	if result == "hit" and health > 0:
		recoil = source.facing * (28 if data.get("id","") == "heavy" else 15)
		posture += float(data.get("posture", 10))
		posture_delay = 2.6
		if posture >= max_posture: on_parried(0)
	if health <= 0:
		hitbox.active = false
		combo.clear()
		pending_followup = ""
	return result

func begin_approach() -> void:
	engage_distance = rng.randf_range(39,72 if phase == 1 else 100)
	change_state("approach")

func contextual_weights(distance: float, candidates: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	for id in candidates:
		if phase == 1 and id not in ["slash","overhead","thrust"]: continue
		var spec: Dictionary = attacks[id]
		var reach: float = float(spec.reach) + spec.size.x/2
		if distance > reach - 3: continue
		var weight: float = float(candidates[id]) * float(attack_selection_weights.get(id,1))
		# Spacing and observed height inform decisions; no player Input is queried.
		if id == "thrust": weight *= 1.9 if distance > 52 else 0.65
		if id in ["overhead","feint"]: weight *= 1.5 if distance < 38 else 0.65
		if id in ["sweep","recall"]: weight *= 1.6 if distance > 65 else 0.75
		if id == "sweep" and target != null and target.position.y < position.y-15: weight *= 0.2
		if not recent_attacks.is_empty() and id == recent_attacks.back(): weight *= repetition_penalty
		if recent_attacks.size() >= 2 and id == recent_attacks[-1] and id == recent_attacks[-2]: weight = 0
		if recent_attacks.has(id): weight *= 0.72
		weights[id] = maxf(0,weight)
	return weights

func weighted_choice(weights: Dictionary) -> String:
	var total := 0.0
	for weight in weights.values(): total += float(weight)
	if total <= 0: return ""
	var roll := rng.randf() * total
	for id in weights:
		roll -= float(weights[id])
		if roll < 0: return id
	return ""

func choose_attack(distance: float) -> String:
	var candidates := {}
	for id in attacks: candidates[id] = 1.0
	return weighted_choice(contextual_weights(distance,candidates))

func choose_followup() -> String:
	if target == null or target.health <= 0 or combo.size() >= max_combo_attacks[phase-1]: return ""
	if rng.randf() >= combo_frequency[phase-1]: return ""
	var candidates: Dictionary = followup_weights.get(attack.get("id",""),{})
	return weighted_choice(contextual_weights(absf(target.position.x-position.x),candidates))

func finish_recovery() -> void:
	var next := choose_followup()
	if not next.is_empty():
		# A thrust may reset its spacing before committing to the next full tell.
		if attack.id == "thrust" and next == "slash" and rng.randf() < 0.45:
			pending_followup = next
			begin_reposition(0.15)
		else: begin_attack(next,true)
	else:
		combo.clear()
		decision_wait = rng.randf_range(0.28,0.52) / phase_aggression[phase-1]
		if absf(target.position.x-position.x) < 27 and rng.randf() < 0.6: begin_reposition(0.22)
		else: change_state("idle")

func begin_reposition(duration: float) -> void:
	face_target()
	reposition_direction = -facing
	if position.x < 50: reposition_direction = 1
	if position.x > 430: reposition_direction = -1
	reposition_duration = duration
	change_state("reposition")
