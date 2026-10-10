extends SceneTree

var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hitstop_enabled = false
	game.sound.muted = true
	game.start_fight()
	game.boss.enabled = false
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	await frames(5)
	p.position.y = 212
	p.velocity.y = 50
	await frames(1)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(8)
	check(p.velocity.y < 0, "jump buffer consumes a jump just before landing")
	await frames(60)
	# Move off the floor collision briefly to simulate an edge, then request jump.
	p.position.y = 213
	p.velocity.y = 0
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(p.velocity.y < -150, "coyote time permits a jump shortly after leaving ground")
	await frames(60)
	p.begin_attack("light")
	p.change_state("recovery")
	p.state_time = 0.13
	Input.action_press("heavy")
	await frames(1)
	Input.action_release("heavy")
	await frames(6)
	check(p.state == "startup" and p.attack.id == "heavy", "attack buffer starts heavy after light recovery")
	p.enabled = false
	p.position = Vector2(200,218)
	b.position = Vector2(230,218)
	p.immunity = 0
	p.facing = -1
	p.change_state("parry")
	p.state_time = 0.03
	check(p.receive_attack(b,b.attacks.slash) == "hit", "parry cannot defend an attack from behind")
	p.health = 100
	p.immunity = 0
	p.posture = 99
	p.change_state("idle")
	p.receive_attack(b,b.attacks.slash)
	check(p.state == "staggered" and p.stun_duration > 0.9, "player posture break causes a vulnerability window")
	p.health = 100
	p.immunity = 0
	p.facing = 1
	p.change_state("parry")
	p.state_time = 0.02
	check(p.receive_attack(b,b.attacks.sweep) == "hit", "violet chain sweep cannot be parried")
	# Hit-stop is verified independently from combat fixed-step timing.
	game.hitstop_enabled = true
	game.on_feedback("parry",Vector2(220,198))
	check(Engine.time_scale < 0.1, "perfect parry starts hit-stop")
	for i in range(12): await process_frame
	check(Engine.time_scale == 1.0, "hit-stop restores normal time automatically")
	game.on_feedback("parry",Vector2(220,198))
	game.retry()
	check(Engine.time_scale == 1.0 and game.hitstop == 0, "retry clears any remaining hit-stop")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames(3)
	quit(1 if failures else 0)
