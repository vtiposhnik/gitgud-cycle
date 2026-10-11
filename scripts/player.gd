class_name Challenger
extends Fighter

@export var run_speed: float = 108.0
@export var acceleration: float = 1800.0
@export var ground_friction: float = 2100.0
@export var air_acceleration: float = 760.0
@export var air_friction: float = 320.0
@export var gravity: float = 920.0
@export var jump_height: float = 42.0
var jump_speed: float:
	get: return sqrt(2.0 * gravity * jump_height)
@export var coyote_window: float = 0.09
@export var jump_buffer_window: float = 0.12
@export var offensive_parry_window: float = 0.085
@export var defensive_parry_window: float = 0.16
@export var parry_recovery: float = 0.40
@export var parry_posture_damage: float = 31.0
@export var dodge_distance: float = 46.0
@export var dodge_duration: float = 0.1333333333
@export var dodge_invulnerability: float = 0.11
@export var dodge_recovery: float = 0.05
@export var dodge_cooldown: float = 0.34
@export var action_buffer_window: float = 0.16
@export var defense_buffer_window: float = 0.10
@export var light_startup: float = 0.10
@export var light_recovery: float = 0.19
@export var heavy_startup: float = 0.25
@export var heavy_recovery: float = 0.31
@export var light_posture_damage: float = 9.0
@export var heavy_posture_damage: float = 19.0
var coyote: float = 0
var jump_buffer: float = 0
var attack_buffer: float = 0
var buffered_attack: String = ""
var dodge_wait: float = 0
var parry_success: bool = false
var stun_duration: float = 0.35
var dash_direction: float = 1
var dash_elapsed: float = 0
var defense_buffer: float = 0
var buffered_defense: String = ""
var landing_time: float = 0
var stance_time: float = 0

func _ready() -> void:
	super._ready()
	hitbox = SwordHitbox.new()
	hitbox.wielder = self
	add_child(hitbox)

func _physics_process(delta: float) -> void:
	tick_common(delta)
	if not enabled: return
	dodge_wait = maxf(0, dodge_wait - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	attack_buffer = maxf(0, attack_buffer - delta)
	defense_buffer = maxf(0, defense_buffer - delta)
	landing_time = maxf(0, landing_time - delta)
	stance_time = maxf(0, stance_time - delta)
	var was_grounded := is_on_floor()
	coyote = coyote_window if was_grounded else maxf(0, coyote - delta)
	if health > 0:
		if Input.is_action_just_pressed("stance"):
			defensive = not defensive
			stance_time = 0.16
			feedback.emit("stance", global_position + Vector2(0, -18))
		if Input.is_action_just_pressed("jump"): jump_buffer = jump_buffer_window
		for action in ["light", "heavy"]:
			if Input.is_action_just_pressed(action):
				buffered_attack = action
				attack_buffer = action_buffer_window
		for action in ["dodge", "parry"]:
			if Input.is_action_just_pressed(action):
				buffered_defense = action
				defense_buffer = defense_buffer_window
		if state == "idle":
			if defense_buffer > 0 and buffered_defense == "dodge" and dodge_wait <= 0:
				begin_dodge()
			elif defense_buffer > 0 and buffered_defense == "parry":
				defense_buffer = 0
				parry_success = false
				change_state("parry")
			elif attack_buffer > 0:
				begin_attack(buffered_attack)
	match state:
		"idle":
			var direction := Input.get_axis("move_left", "move_right")
			var responsiveness: float = acceleration if was_grounded else air_acceleration
			if direction == 0: responsiveness = ground_friction if was_grounded else air_friction
			velocity.x = move_toward(velocity.x, direction * run_speed * (0.86 if defensive else 1.0), responsiveness * delta)
			if direction != 0: facing = direction
			if jump_buffer > 0 and coyote > 0:
				velocity.y = -jump_speed
				jump_buffer = 0
				coyote = 0
		"dodge":
			# Clamp the final integration step: distance never depends on tick rounding.
			var step := minf(delta, maxf(0, dodge_duration - dash_elapsed))
			velocity.x = dash_direction * dodge_distance / maxf(dodge_duration, 0.001) * step / delta
			dash_elapsed += step
		"dodge_recovery":
			velocity.x = 0
			if state_time >= dodge_recovery: change_state("idle")
		"startup":
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			if state_time >= float(attack.startup):
				change_state("active")
				hitbox.active = true
				feedback.emit("heavy_swing" if attack.id == "heavy" else "swing", global_position)
		"active":
			velocity.x = facing * (42 if attack.id == "heavy" else 23)
			hitbox.sample()
			if state_time >= float(attack.active):
				hitbox.active = false
				change_state("recovery")
		"recovery":
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			if state_time >= float(attack.recovery): change_state("idle")
		"parry":
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			if state_time >= (0.22 if parry_success else parry_recovery):
				if not parry_success: feedback.emit("parry_fail", global_position + Vector2(facing*8,-18))
				change_state("idle")
		"staggered":
			velocity.x = move_toward(velocity.x, 0, 420 * delta)
			if state_time >= stun_duration: change_state("idle")
		"dead":
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
	velocity.y += gravity * delta
	if Input.is_action_just_released("jump") and velocity.y < -90: velocity.y *= 0.55
	move_and_slide()
	position.x = clampf(position.x, 18, 462)
	if state == "dodge" and dash_elapsed >= dodge_duration - 0.00001:
		velocity.x = 0
		change_state("dodge_recovery")
	if not was_grounded and is_on_floor():
		landing_time = 0.10
		feedback.emit("land", global_position)

func begin_dodge() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0: facing = direction
	dash_direction = facing
	dash_elapsed = 0
	defense_buffer = 0
	dodge_wait = dodge_cooldown
	change_state("dodge")
	feedback.emit("dodge", global_position)

func begin_attack(kind: String) -> void:
	var heavy := kind == "heavy"
	var tempo: float = 1.2 if defensive else 1.0
	attack = {"id": kind, "damage": (23.0 if heavy else 11.0) * (0.85 if defensive else 1.0),
		"posture": heavy_posture_damage if heavy else light_posture_damage, "startup": (heavy_startup if heavy else light_startup) * tempo,
		"active": 0.10, "recovery": (heavy_recovery if heavy else light_recovery) * tempo,
		"size": Vector2(42 if heavy else 34, 27), "reach": 27 if heavy else 23, "height": -18}
	attack_buffer = 0
	hitbox.prepare(attack)
	change_state("startup")

func receive_attack(source: Fighter, data: Dictionary) -> String:
	if health <= 0 or immunity > 0: return "immune"
	if state == "dodge" and state_time < dodge_invulnerability: return "dodge"
	var window: float = defensive_parry_window if defensive else offensive_parry_window
	var front := (source.position.x - position.x) * facing >= -3
	if state == "parry" and state_time <= window and front and data.get("parryable", true):
		parry_success = true
		posture = maxf(0, posture - 18)
		source.on_parried(parry_posture_damage)
		feedback.emit("parry", global_position + Vector2(facing * 9, -20))
		return "parry"
	# Defensive stance catches a slightly late parry as a costly guard.
	var guard: bool = defensive and state == "parry" and state_time <= window + 0.065 and front and data.get("parryable", true)
	var adjusted := data.duplicate()
	if guard: adjusted.damage = float(data.damage) * 0.2
	if state == "parry": feedback.emit("parry_fail", global_position + Vector2(facing*8,-18))
	var result := super.receive_attack(source, adjusted)
	posture += float(data.get("posture", 25)) * (0.65 if defensive else 1.0)
	immunity = 0.52
	hitbox.active = false
	if health > 0:
		stun_duration = 0.25 if guard else 0.32
		if posture >= max_posture:
			posture = 0
			stun_duration = 0.95
			feedback.emit("break", global_position + Vector2(0,-20))
		change_state("staggered")
		velocity.x = source.facing * 75
	return "guard" if guard else result
