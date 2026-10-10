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

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	await frames(1)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hitstop_enabled = false
	game.sound.muted = true
	await frames(3)
	check(game.mode == "title", "main scene opens at title")
	await tap("confirm")
	check(game.mode == "intro", "Enter begins the introduction")
	await frames(630)
	check(game.mode == "fight", "complete introduction reaches the fight automatically")
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	await tap("stance")
	check(p.defensive, "Q switches the combat stance")
	await tap("pause")
	var frozen_position := b.position
	var frozen_time := b.state_time
	await frames(15)
	check(paused and b.position == frozen_position and b.state_time == frozen_time, "pause freezes combat simulation")
	await tap("pause")
	check(not paused, "Escape resumes the fight")
	# Idle challenger must eventually die from normal AI, without injected damage.
	await frames(2500)
	check(game.mode == "death" and game.deaths == 1, "natural boss AI kills the idle player and counts the death")
	await tap("retry")
	p = game.player
	b = game.boss
	check(game.mode == "fight" and p.health == p.max_health and b.health == b.max_health, "R immediately creates a fresh duel")
	check(game.deaths == 1 and b.phase == 1, "retry retains death count and resets the phase")
	# Exercise each actual attack state machine and its Area2D against a target.
	p.enabled = false
	for id in b.attacks:
		p.health = p.max_health
		p.immunity = 0
		p.position = Vector2(265,218)
		p.change_state("idle")
		b.position = Vector2(300,218)
		b.combo.clear()
		b.begin_attack(id)
		var health_before := p.health
		await frames(int((float(b.attack.startup)+float(b.attack.active))*60)+4)
		check(p.health < health_before, "%s startup/active hitbox lands damage" % id)
	# Verify boss defeat triggers the ending, transformation and subsequent retry.
	b.enabled = false
	b.change_state("idle")
	b.health = 10
	p.position = Vector2(267,218)
	p.facing = 1
	p.begin_attack("heavy")
	await frames(4)
	p.hitbox.active = true
	p.hitbox.sample()
	check(b.health == 0 and game.mode == "ending", "lethal sword collision starts victory ending")
	await frames(490)
	check(game.mode_time > 7.5 and p.scale.y > 1.3, "ending transforms Challenger and reaches CYCLE COMPLETE")
	await tap("retry")
	check(game.mode == "fight" and game.player.scale == Vector2.ONE, "ending can restart with an untransformed player")
	game.mode = "intro"
	await tap("skip")
	check(game.mode == "fight", "Tab skips the introduction")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await frames(3)
	quit(1 if failures else 0)
