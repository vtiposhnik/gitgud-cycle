class_name Challenger
extends Fighter

@export var run_speed: float = 103.0
@export var acceleration: float = 960.0
@export var gravity: float = 920.0
@export var jump_speed: float = 278.0
@export var coyote_window: float = 0.09
@export var jump_buffer_window: float = 0.12
@export var offensive_parry_window: float = 0.085
@export var defensive_parry_window: float = 0.16
@export var parry_recovery: float = 0.40
@export var parry_posture_damage: float = 31.0
@export var dodge_speed: float = 265.0
@export var dodge_duration: float = 0.26
@export var dodge_cooldown: float = 0.52
var coyote: float = 0
var jump_buffer: float = 0
var attack_buffer: float = 0
var buffered_attack: String = ""
var dodge_wait: float = 0
var parry_success: bool = false
var stun_duration: float = 0.35

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
	var was_grounded := is_on_floor()
	coyote = coyote_window if was_grounded else maxf(0, coyote - delta)
	if health > 0:
		if Input.is_action_just_pressed("stance"):
			defensive = not defensive
			feedback.emit("stance", global_position + Vector2(0, -18))
		if Input.is_action_just_pressed("jump"): jump_buffer = jump_buffer_window
		for action in ["light", "heavy"]:
			if Input.is_action_just_pressed(action):
				buffered_attack = action
				attack_buffer = 0.16
		if state == "idle":
			if Input.is_action_just_pressed("dodge") and dodge_wait <= 0:
				var direction := Input.get_axis("move_left", "move_right")
				if direction != 0: facing = direction
				change_state("dodge")
				dodge_wait = dodge_cooldown
				feedback.emit("dodge", global_position)
			elif Input.is_action_just_pressed("parry"):
				parry_success = false
				change_state("parry")
			elif attack_buffer > 0:
				begin_attack(buffered_attack)
	match state:
		"idle":
			var direction := Input.get_axis("move_left", "move_right")
			velocity.x = move_toward(velocity.x, direction * run_speed * (0.86 if defensive else 1.0), acceleration * delta)
			if direction != 0: facing = direction
			if jump_buffer > 0 and coyote > 0:
				velocity.y = -jump_speed
				jump_buffer = 0
				coyote = 0
		"dodge":
			velocity.x = facing * dodge_speed
			if state_time >= dodge_duration: change_state("idle")
		"startup":
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			if state_time >= float(attack.startup):
				change_state("active")
				hitbox.active = true
				feedback.emit("swing", global_position)
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
			if state_time >= (0.22 if parry_success else parry_recovery): change_state("idle")
		"staggered":
			velocity.x = move_toward(velocity.x, 0, 420 * delta)
			if state_time >= stun_duration: change_state("idle")
		"dead":
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
	velocity.y += gravity * delta
	if Input.is_action_just_released("jump") and velocity.y < -90: velocity.y *= 0.55
	move_and_slide()
	position.x = clampf(position.x, 18, 462)
	if not was_grounded and is_on_floor(): feedback.emit("land", global_position)

func begin_attack(kind: String) -> void:
	var heavy := kind == "heavy"
	var tempo: float = 1.2 if defensive else 1.0
	attack = {"id": kind, "damage": (23.0 if heavy else 11.0) * (0.85 if defensive else 1.0),
		"posture": 19.0 if heavy else 9.0, "startup": (0.27 if heavy else 0.11) * tempo,
		"active": 0.10, "recovery": (0.31 if heavy else 0.19) * tempo,
		"size": Vector2(42 if heavy else 34, 27), "reach": 27 if heavy else 23, "height": -18}
	attack_buffer = 0
	hitbox.prepare(attack)
	change_state("startup")

func receive_attack(source: Fighter, data: Dictionary) -> String:
	if health <= 0 or immunity > 0: return "immune"
	if state == "dodge" and state_time < 0.19: return "dodge"
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
