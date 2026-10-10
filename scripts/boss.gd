class_name FormerVictor
extends Fighter

signal phase_changed(value: int)

@export var approach_speed: float = 46.0
@export var stagger_duration: float = 2.0
@export var parry_stun: float = 0.44
@export var transition_duration: float = 1.65
var target: Challenger
var pattern_index: int = 0
var combo: Array = []
var stun_duration: float = 0.44
var decision_wait: float = 0.75
var attack_count: int = 0
var patterns := {
	1: [["slash"], ["overhead"], ["thrust"], ["slash", "thrust"]],
	2: [["sweep", "recall"], ["slash", "feint"], ["thrust", "slash"], ["overhead", "recall"]],
	3: [["sweep", "recall", "thrust"], ["feint", "slash", "overhead"], ["thrust", "sweep", "recall"]]
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
			if state_time >= decision_wait and target.health > 0: change_state("approach")
		"approach":
			face_target()
			var distance := absf(target.position.x - position.x)
			if distance < 58 or state_time > 2.5:
				combo = patterns[phase][pattern_index % patterns[phase].size()].duplicate()
				pattern_index += 1
				begin_attack(combo.pop_front())
			else: velocity.x = facing * approach_speed * (1.0 + (phase - 1) * 0.18)
		"reposition":
			velocity.x = -facing * 42
			if state_time >= 0.32: change_state("approach")
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
			if state_time >= float(attack.recovery):
				if not combo.is_empty() and target.health > 0: begin_attack(combo.pop_front())
				else:
					decision_wait = 0.55 if phase == 1 else (0.30 if phase == 2 else 0.16)
					change_state("reposition" if absf(target.position.x-position.x) < 25 else "idle")
		"staggered":
			velocity.x = 0
			if state_time >= stun_duration: change_state("idle")
		"transition":
			velocity.x = 0
			if state_time >= transition_duration: change_state("idle")
		"dead": velocity.x = 0
	move_and_slide()
	position.x = clampf(position.x, 24, 456)

func face_target() -> void:
	if target != null: facing = 1 if target.position.x >= position.x else -1

func begin_attack(id: String) -> void:
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
	hitbox.active = false
	posture = 0
	change_state("transition")
	phase_changed.emit(phase)
	feedback.emit("phase", global_position + Vector2(0,-25))

func on_parried(amount: float) -> void:
	if health <= 0: return
	hitbox.active = false
	combo.clear()
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
		posture += float(data.get("posture", 10))
		posture_delay = 2.6
		if posture >= max_posture: on_parried(0)
	if health <= 0:
		hitbox.active = false
		combo.clear()
	return result
