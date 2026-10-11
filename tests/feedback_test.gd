extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
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
	game.start_fight()
	game.player.enabled = false
	game.boss.enabled = false
	var cues := ["light_hit","heavy_hit","parry","parry_fail","dodge","break"]
	var hashes: Dictionary = {}
	for cue in cues: hashes[hash(game.sound.sounds[cue].data)] = true
	check(hashes.size() == cues.size(), "six required combat cues contain distinct waveforms")
	game.on_feedback("light_hit",Vector2(100,100),1)
	var light_stop: float = game.hitstop
	var directed := true
	for particle in game.particles: directed = directed and particle.velocity.x > 0
	check(directed, "ordinary hit sparks travel in the impact direction")
	game.hitstop = 0
	game.on_feedback("heavy_hit",Vector2(100,100),1)
	check(game.hitstop > light_stop and game.flash_kind == "heavy_hit", "heavy hit has stronger hit-stop and an impact flash")
	game.hitstop = 0
	game.on_feedback("parry",Vector2(100,100),1)
	check(game.flash_kind == "parry" and game.flash_time > 0.08, "perfect parry emits its distinct clash flash")
	game.hitstop = 0
	game.on_feedback("break",Vector2(100,100),1)
	check(game.hitstop > game.hitstop_durations.parry, "posture break gets the strongest brief hit-stop")
	game.boss.receive_attack(game.player,{"id":"heavy","damage":10,"posture":2})
	check(game.boss.recoil > 0 and game.flash_kind == "heavy_hit", "actual heavy contact triggers knockback and heavy feedback")
	game.hitstop = 0
	Engine.time_scale = 1
	game.on_feedback("parry_fail",Vector2.ZERO)
	check(game.hitstop == 0 and Engine.time_scale == 1, "failed parry cue does not freeze combat")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
