extends SceneTree

var checks := 0
var failures := 0
var game: Node2D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hitstop_enabled = false
	game.sound.muted = true
	game.start_fight()
	game.boss.enabled = false
	var p: Challenger = game.player
	await frames(5)
	var start := p.position.x
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(p.state == "dodge" and p.velocity.x > 340, "dash reaches full speed immediately")
	Input.action_press("move_left")
	await frames(3)
	Input.action_release("move_left")
	check(p.facing == 1 and p.velocity.x > 0, "dash direction stays locked despite opposite input")
	await frames(4)
	check(absf(p.position.x-start-p.dodge_distance) < 0.1, "dash travels its configured 46 pixels")
	check(p.velocity.x == 0 and p.state == "dodge_recovery", "dash terminates sharply into brief recovery")
	var end := p.position.x
	await frames(10)
	check(absf(p.position.x-end) < 0.1, "no residual sliding after dash")
	Input.action_press("move_right")
	await frames(6)
	Input.action_release("move_right")
	await frames(5)
	check(p.velocity.x == 0, "ground friction stops movement within five frames")
	p.begin_attack("heavy")
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(p.state == "startup", "dodge cannot cancel committed attack startup")
	await frames(45)
	check(p.state == "idle", "early buffered dodge expires before long attack completes")
	p.begin_attack("light")
	p.change_state("recovery")
	p.state_time = p.light_recovery - 0.05
	Input.action_press("parry")
	await frames(1)
	Input.action_release("parry")
	await frames(5)
	check(p.state == "parry", "late defense input buffers across attack recovery")
	p.enabled = false
	p.change_state("dodge")
	p.state_time = p.dodge_invulnerability + 0.005
	p.immunity = 0
	check(p.receive_attack(game.boss,game.boss.attacks.slash) == "hit", "dash is vulnerable after its configured invulnerability window")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
