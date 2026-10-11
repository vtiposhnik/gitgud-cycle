extends SceneTree

var checks := 0
var failures := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hitstop_enabled = false
	game.sound.muted = true
	await frames(5)
	if game.has_method("start_fight"): game.start_fight()
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	b.enabled = false
	await frames(6)
	check(p.is_on_floor(), "player lands on the arena collision floor")
	var old_x := p.position.x
	Input.action_press("move_right")
	await frames(15)
	Input.action_release("move_right")
	check(p.position.x > old_x + 10, "InputMap movement accelerates the player")
	Input.action_press("jump")
	await frames(5)
	Input.action_release("jump")
	check(p.position.y < 210, "jump input produces airborne movement")
	await frames(50)
	check(p.is_on_floor(), "jump returns to the floor")
	p.enabled = false
	p.position = Vector2(210,218)
	b.position = Vector2(243,218)
	p.facing = 1
	b.facing = -1
	p.begin_attack("light")
	await frames(4)
	p.hitbox.active = true
	var before := b.health
	p.hitbox.sample()
	p.hitbox.sample()
	check(b.health == before - 11, "player Area2D hits boss exactly once per swing")
	p.hitbox.active = false
	p.immunity = 0
	p.change_state("idle")
	b.begin_attack("slash")
	await frames(4)
	b.hitbox.active = true
	before = p.health
	b.hitbox.sample()
	check(p.health == before - 20, "boss Area2D damages player")
	p.immunity = 0
	p.change_state("parry")
	p.state_time = 0.04
	b.begin_attack("slash")
	b.hitbox.active = true
	before = p.health
	b.hitbox.sample()
	check(p.health == before and b.state == "staggered", "timed frontal parry interrupts boss without health loss")
	check(b.posture >= 31, "parry damages boss posture")
	p.change_state("dodge")
	p.state_time = 0.1
	check(p.receive_attack(b, b.attacks.sweep) == "dodge", "dodge invulnerability avoids unparryable sweep")
	p.change_state("parry")
	p.state_time = 0.3
	p.immunity = 0
	before = p.health
	p.receive_attack(b, b.attacks.slash)
	check(p.health < before, "failed parry recovery is vulnerable")
	p.health = 100
	p.immunity = 0
	p.defensive = true
	p.change_state("parry")
	p.state_time = 0.13
	check(p.receive_attack(b, b.attacks.slash) == "parry", "defensive stance extends the parry window")
	p.immunity = 0
	p.change_state("parry")
	p.state_time = 0.2
	check(p.receive_attack(b, b.attacks.slash) == "guard", "late defensive parry guards with chip and posture damage")
	b.posture = 95
	b.on_parried(31)
	check(b.stun_duration == b.stagger_duration and b.posture == 0, "boss posture break opens a long punish window")
	check(b.attacks.size() == 6, "six distinct configured attacks exist")
	b.enabled = true
	b.health = b.max_health * 0.69
	await frames(2)
	check(b.phase == 2 and b.state == "transition", "70 percent health triggers phase two")
	b.state_time = b.transition_duration
	await frames(2)
	b.health = b.max_health * 0.34
	await frames(2)
	check(b.phase == 3 and b.state == "transition", "35 percent health triggers phase three")
	check(b.max_combo_attacks[2] > b.max_combo_attacks[0] and b.combo_frequency[2] > b.combo_frequency[0], "phase three adds longer attack sequences")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
