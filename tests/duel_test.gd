# Deterministic input-driven demonstration: no health, damage, phase, or timing cheats.
extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.sound.muted = true
	# Hit-stop is presentation; keep fixed-step test time independent of rendering.
	game.hitstop_enabled = false
	game.start_fight()
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	b.rng.seed = 713
	var seen_phases: Dictionary = {}
	var parries: int = 0
	var used_attacks: Dictionary = {}
	for frame in range(18000):
		await physics_frame
		for action in ["light","heavy","parry","dodge","jump","stance","move_left","move_right"]:
			Input.action_release(action)
		seen_phases[b.phase] = true
		if game.mode != "fight": break
		var distance := absf(b.position.x-p.position.x)
		var direction := signf(b.position.x-p.position.x)
		if p.state == "idle":
			if not p.defensive: Input.action_press("stance")
			if distance > 31 or p.facing != direction:
				Input.action_press("move_right" if direction > 0 else "move_left")
			if b.state == "startup":
				used_attacks[b.attack.id] = true
				var remaining: float = b.attack.startup - b.state_time
				if b.attack.parryable and remaining < 0.07 and distance < 70:
					Input.action_press("parry")
					parries += 1
				elif not b.attack.parryable and remaining < 0.10:
					Input.action_press("dodge")
			elif b.state == "staggered" and distance < 39:
				Input.action_press("light")
			elif b.state == "recovery" and b.attack.recovery - b.state_time > 0.42 and distance < 39:
				Input.action_press("light")
	if game.mode == "ending" and seen_phases.size() == 3:
		print("PASS: input-driven duel defeated boss through all three phases")
		print("DETAIL: player HP %.1f, parry attempts %d, attack types encountered %s" % [p.health,parries,str(used_attacks.keys())])
	else:
		push_error("Duel incomplete: mode=%s player=%.1f boss=%.1f phase=%d parries=%d" % [game.mode,p.health,b.health,b.phase,parries])
	var passed: bool = game.mode == "ending" and seen_phases.size() == 3
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
