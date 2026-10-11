extends SceneTree

func _initialize() -> void: call_deferred("run")
func frame_wait(count: int) -> void:
	for i in range(count): await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("GITGUD_CAPTURE_DIR")
	if directory.is_empty(): directory = "user://captures"
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: " + path)
func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.sound.muted = true
	game.hitstop_enabled = false
	await frame_wait(15)
	await capture("title")
	game.start_fight()
	game.player.position.x = 250
	game.boss.position.x = 315
	game.boss.enabled = false
	game.boss.begin_attack("overhead")
	await frame_wait(15)
	await capture("duel")
	game.boss.begin_attack("slash")
	game.boss.change_state("active")
	game.boss.state_time = 0.04
	await frame_wait(1)
	await capture("slash")
	game.player.position.x = 240
	game.player.begin_dodge()
	await frame_wait(4)
	await capture("dash")
	await frame_wait(15)
	game.player.change_state("parry")
	game.player.parry_success = true
	game.on_feedback("parry",game.player.position+Vector2(9,-20))
	await frame_wait(1)
	await capture("parry")
	game.boss.phase = 3
	game.boss.begin_attack("sweep")
	game.banner = "INHERITANCE"
	game.banner_time = 3
	await frame_wait(22)
	await capture("inheritance")
	game.player.visual.show_missing_labels = false
	game.boss.visual.show_missing_labels = false
	await frame_wait(1)
	await capture("labels-hidden")
	game.mode = "ending"
	game.mode_time = 0
	game.player.enabled = false
	game.boss.change_state("dead")
	await frame_wait(40)
	await capture("defeat")
	game.queue_free()
	await frame_wait(3)
	quit()
