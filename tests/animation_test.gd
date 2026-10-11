extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count): await process_frame
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
	await frames(3)
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	var pv: Node2D = p.visual
	var bv: Node2D = b.visual
	var files: Dictionary = {}
	for visual in [pv,bv]:
		for name in visual.library.metadata:
			files[visual.library.metadata[name].file] = true
	check(files.size() == 12, "all twelve supplied sheets are integrated")
	check(pv.sprite is AnimatedSprite2D and bv.sprite is AnimatedSprite2D, "characters use Godot AnimatedSprite2D")
	check(pv.sprite.scale == Vector2.ONE and bv.sprite.scale == Vector2.ONE, "sprite nodes use integer 1:1 scale")
	check(pv.sprite.sprite_frames.get_frame_count("dash") == 8, "grid sheet excludes the ninth blank cell")
	check(pv.sprite.sprite_frames.get_frame_count("jump") == 5 and pv.sprite.sprite_frames.get_frame_count("fall") == 2, "jump sheet has explicit rise and fall sections")
	var pi: Image = pv.sprite.sprite_frames.get_frame_texture("idle",0).get_image()
	var bi: Image = bv.sprite.sprite_frames.get_frame_texture("idle",0).get_image()
	check(pi.get_pixel(0,0).a == 0 and bi.get_pixel(0,0).a == 0, "opaque color-key backgrounds become transparent")
	check(pi.get_width() == 32 and bi.get_width() == 58, "different native dimensions retain configured pixel scale")
	var prior_frame: int = pv.sprite.frame
	await frames(12)
	check(pv.sprite.frame != prior_frame, "idle animation actually advances")
	p.facing = 1
	pv.update_animation()
	check(pv.sprite.flip_h, "left-facing source mirrors when fighter faces right")
	p.facing = -1
	pv.update_animation()
	check(not pv.sprite.flip_h, "source orientation restored facing left")
	check(pv.sprite.offset == Vector2(-16,-31) and bv.sprite.offset.y == -57, "feet anchors account for per-sheet dimensions")
	p.begin_attack("light")
	pv.update_animation()
	check(pv.missing_animation == "light_attack" and pv.sprite.animation == "parry", "missing attack uses same-character pose with explicit missing state")
	check(not p.hitbox.active, "animation fallback does not activate gameplay hitboxes early")
	check(pv.show_missing_labels, "development missing-animation labels default on")
	Input.action_press("animation_debug")
	await frames(1)
	Input.action_release("animation_debug")
	await frames(1)
	check(not pv.show_missing_labels and not bv.show_missing_labels, "F3 toggles both missing-animation labels")
	game.retry()
	check(not game.player.visual.show_missing_labels, "animation debug preference survives retry")
	game.player.visual.update_animation()
	check(game.player.visual.missing_animation == "offensive_stance" and game.player.visual.sprite.is_playing(), "missing stance keeps the supplied idle loop animated")
	game.boss.enabled = false
	b = game.boss
	b.begin_attack("slash")
	b.change_state("active")
	b.state_time = 0.07
	b.visual.update_animation()
	check(b.visual.missing_animation.is_empty() and b.visual.sprite.frame in [3,4,5], "authored boss slash uses active frames synchronized to combat")
	b.begin_attack("sweep")
	b.visual.update_animation()
	check(b.visual.missing_animation == "chain_sweep" and b.visual.sprite.animation == "slash", "missing chain attack uses verified sword pose without claiming an asset")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames(2)
	quit(1 if failures else 0)
