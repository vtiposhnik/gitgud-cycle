extends SceneTree
var checks := 0
var failures := 0
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
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.sound.muted = true
	game.hitstop_enabled = false
	game.start_fight()
	var b: FormerVictor = game.boss
	var p: Challenger = game.player
	b.enabled = false
	p.enabled = false
	b.rng.seed = 713
	p.position = Vector2(220,218)
	b.position = Vector2(250,218)
	var seen: Dictionary = {}
	for i in range(50): seen[b.choose_attack(30)] = true
	check(seen.size() == 3 and not seen.has("sweep"), "phase one varies among only basic sword techniques")
	b.recent_attacks.assign(["slash","slash"])
	var choices: Dictionary = {}
	for i in range(30): choices[b.choose_attack(30)] = true
	check(not choices.has("slash"), "boss cannot repeat the same attack three times")
	b.phase = 2
	b.recent_attacks.clear()
	choices.clear()
	for i in range(50): choices[b.choose_attack(105)] = true
	check(choices.size() > 0 and not choices.has("overhead") and not choices.has("slash"), "long-range decisions exclude attacks that cannot reach")
	check(b.choose_attack(250).is_empty(), "boss approaches instead of swinging beyond every attack's reach")
	b.begin_attack("slash")
	var endings: Dictionary = {}
	for i in range(100): endings[b.choose_followup()] = true
	check(endings.has("") and endings.has("thrust") and endings.has("feint"), "slash may stop or branch into alternative finishers")
	b.phase = 3
	b.combo.assign(["slash","thrust","sweep","recall"])
	check(b.choose_followup().is_empty(), "phase three combos still have a hard limit and an opening")
	b.begin_attack("overhead")
	var facing_before := b.facing
	p.position.x = 300
	b.enabled = true
	b.health = b.max_health*0.3
	await frames(6)
	check(b.state == "startup" and b.facing == facing_before, "boss direction stays committed when player crosses behind during tell")
	b.enabled = false
	p.position = Vector2(220,218)
	b.phase = 2
	b.health = b.max_health*0.5
	b.combo_frequency[1] = 1.0
	b.followup_weights.slash = {"thrust":1.0}
	b.begin_attack("slash")
	b.change_state("recovery")
	b.state_time = float(b.attack.recovery)-0.08
	b.enabled = true
	await frames(2)
	check(b.state == "recovery", "combo branch does not truncate the current punish window")
	await frames(7)
	check(b.state == "startup" and b.attack.id == "thrust" and b.branches_taken > 0, "state machine executes a branch with a fresh anticipation period")
	b.pending_followup = "slash"
	b.on_parried(31)
	check(b.combo.is_empty() and b.pending_followup.is_empty() and b.state == "staggered", "parry cancels both immediate and repositioned follow-ups")
	b.pending_followup = "recall"
	b.enter_phase(3)
	check(b.pending_followup.is_empty() and not b.hitbox.active, "phase transition clears queued attacks and hitboxes")
	check(b.phase_aggression[2] > b.phase_aggression[0] and b.combo_frequency[2] > b.combo_frequency[0], "phases escalate both movement pressure and branching frequency")
	# Reproducibility without making normal gameplay deterministic.
	b.rng.seed = 94
	var first := b.choose_attack(35)
	b.rng.seed = 94
	check(b.choose_attack(35) == first, "debug RNG seed reproduces attack decisions")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
