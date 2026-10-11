extends Node2D

@export var hitstop_durations: Dictionary = {"light_hit":0.028,"heavy_hit":0.052,"boss_hit":0.04,"major_hit":0.06,"parry":0.065,"break":0.085,"phase":0.025}
@export var hitstop_scale: float = 0.06
@export var shake_strength: float = 1.0
var flash_time: float = 0
var flash_position: Vector2 = Vector2.ZERO
var flash_kind: String = ""
var player: Challenger
var boss: FormerVictor
var world: Node2D
var arena: Node2D
var hud: Node2D
var sound: Node
var mode: String = "title"
var mode_time: float = 0
var fight_time: float = 0
var deaths: int = 0
var paused: bool = false
var dialogue: String = ""
var banner: String = ""
var banner_time: float = 0
var hitstop: float = 0
var hitstop_enabled: bool = true
var shake: float = 0
var particles: Array[Dictionary] = []
var intro_clashed: bool = false
var show_animation_labels: bool = OS.is_debug_build()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load("res://scripts/controls.gd").install()
	if not InputMap.has_action("mute"):
		InputMap.add_action("mute")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_M
		InputMap.action_add_event("mute",key)
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	arena = Node2D.new()
	arena.set_script(load("res://scripts/arena.gd"))
	arena.game = self
	world.add_child(arena)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(240,230)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(480,24)
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	sound = Node.new()
	sound.set_script(load("res://scripts/sound.gd"))
	add_child(sound)
	spawn_fighters()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Node2D.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.game = self
	layer.add_child(hud)

func spawn_fighters() -> void:
	player = Challenger.new()
	player.position = Vector2(104,218)
	player.enabled = false
	world.add_child(player)
	boss = FormerVictor.new()
	boss.target = player
	boss.position = Vector2(344,218)
	boss.facing = -1
	boss.enabled = false
	world.add_child(boss)
	player.visual.show_missing_labels = show_animation_labels
	boss.visual.show_missing_labels = show_animation_labels
	player.feedback.connect(on_actor_feedback.bind(player))
	boss.feedback.connect(on_actor_feedback.bind(boss))
	player.died.connect(on_player_died)
	boss.died.connect(on_boss_died)
	boss.phase_changed.connect(on_phase_changed)

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale,0.001)
	if hitstop > 0:
		hitstop -= real_delta
		if hitstop <= 0: Engine.time_scale = 1.0
	if Input.is_action_just_pressed("mute"): sound.muted = not sound.muted
	if OS.is_debug_build() and Input.is_action_just_pressed("animation_debug"):
		show_animation_labels = not show_animation_labels
		player.visual.show_missing_labels = show_animation_labels
		boss.visual.show_missing_labels = show_animation_labels
	if Input.is_action_just_pressed("pause") and mode in ["fight","intro"]:
		paused = not paused
		get_tree().paused = paused
	if paused: return
	flash_time = maxf(0,flash_time-delta)
	mode_time += delta
	banner_time = maxf(0,banner_time-delta)
	shake = maxf(0,shake-real_delta*18)
	world.position = Vector2(round(sin(mode_time*103)*shake),round(cos(mode_time*79)*shake*0.5))
	for i in range(particles.size()-1,-1,-1):
		particles[i].life -= delta
		particles[i].position += particles[i].velocity*delta
		particles[i].velocity.y += 100*delta
		if particles[i].life <= 0: particles.remove_at(i)
	match mode:
		"title":
			if Input.is_action_just_pressed("confirm"):
				mode = "intro"
				mode_time = 0
				player.position.x = 35
		"intro":
			if Input.is_action_just_pressed("skip") or Input.is_action_just_pressed("confirm"):
				start_fight()
			else: update_intro(delta)
		"fight": fight_time += delta
		"death":
			if Input.is_action_just_pressed("retry"): retry()
		"ending":
			if mode_time > 1.4:
				player.position.x = move_toward(player.position.x,boss.position.x-23,delta*33)
				player.facing = 1 if player.position.x < boss.position.x else -1
				player.velocity.x = 20 if absf(player.position.x-(boss.position.x-23)) > 2 else 0
			if mode_time > 4:
				player.scale.y = 1.0 + clampf((mode_time-4)/3,0,1)*0.38
				boss.phase = 3
			if mode_time > 7.5 and Input.is_action_just_pressed("retry"): retry()

func update_intro(delta: float) -> void:
	if mode_time < 2:
		player.position.x = move_toward(player.position.x,135,delta*50)
		player.velocity.x = 40
		dialogue = "Why are you—"
	elif mode_time < 4:
		player.velocity.x = 0
		dialogue = "...So that's how it is."
	elif mode_time < 6:
		dialogue = "This must be what he meant..."
	elif mode_time < 7.4:
		dialogue = "We don't need to—"
	elif mode_time < 8:
		player.position.x = move_toward(player.position.x,315,delta*370)
		player.attack = {"id": "light"}
		player.state = "active"
		dialogue = ""
	elif mode_time < 8.6:
		if not intro_clashed:
			intro_clashed = true
			on_feedback("parry",Vector2(323,191))
		player.state = "staggered"
		player.position.x = move_toward(player.position.x,238,delta*180)
	elif mode_time < 10.2:
		player.state = "idle"
		dialogue = "...Alright then."
	else: start_fight()

func start_fight() -> void:
	Engine.time_scale = 1.0
	hitstop = 0
	mode = "fight"
	mode_time = 0
	fight_time = 0
	player.position = Vector2(125,218)
	boss.position = Vector2(344,218)
	player.velocity = Vector2.ZERO
	player.change_state("idle")
	boss.change_state("idle")
	player.enabled = true
	boss.enabled = true
	banner = "THE DUEL"
	banner_time = 2.2

func retry() -> void:
	get_tree().paused = false
	paused = false
	Engine.time_scale = 1.0
	hitstop = 0
	world.remove_child(player)
	world.remove_child(boss)
	player.queue_free()
	boss.queue_free()
	particles.clear()
	flash_time = 0
	spawn_fighters()
	start_fight()

func on_player_died() -> void:
	if mode != "fight": return
	deaths += 1
	mode = "death"
	mode_time = 0
	boss.enabled = false
	boss.hitbox.active = false
	boss.change_state("idle")

func on_boss_died() -> void:
	if mode != "fight": return
	mode = "ending"
	mode_time = 0
	player.enabled = false
	player.hitbox.active = false
	player.change_state("idle")
	player.velocity = Vector2.ZERO
	boss.enabled = false

func on_phase_changed(value: int) -> void:
	banner = "RECOGNITION" if value == 2 else "INHERITANCE"
	banner_time = 2.2

func on_actor_feedback(kind: String, where: Vector2, actor: Fighter) -> void:
	var direction: float = actor.impact_direction if kind.ends_with("hit") else actor.facing
	on_feedback(kind,where-world.position,direction)

func on_feedback(kind: String, where: Vector2, direction: float = 1.0) -> void:
	sound.play(kind)
	var impactful: bool = hitstop_durations.has(kind)
	var strong: bool = kind in ["parry","break","heavy_hit","major_hit"]
	if impactful:
		shake = maxf(shake,(2.8 if strong else 1.1) * shake_strength)
		flash_time = 0.13 if kind == "break" else (0.085 if kind == "parry" else 0.055)
		flash_position = where
		flash_kind = kind
		if hitstop_enabled and mode in ["fight","intro"]:
			hitstop = maxf(hitstop,float(hitstop_durations[kind]))
			Engine.time_scale = hitstop_scale
	var color := Color("c2ffef") if kind == "parry" else Color("e9c18c")
	if kind in ["phase","break"]: color = Color("d2b4ef")
	if kind == "parry_fail": color = Color("a68b99")
	var count: int = 22 if strong else (11 if impactful else 4)
	for i in range(count):
		var angle: float = lerpf(-1.1,1.1,float(i)/maxf(1,count-1))
		var speed: float = (105 if strong else 60) * (0.5 + float(i%3)*0.25)
		var velocity := Vector2(cos(angle)*direction*speed,sin(angle)*speed-20)
		if kind in ["parry","break"]:
			angle = TAU*float(i)/count
			velocity = Vector2(cos(angle),sin(angle))*speed
		particles.append({"position":where,"velocity":velocity,
			"life":0.26 if impactful else 0.13,"color":color})

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
