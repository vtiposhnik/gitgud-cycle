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
	await frame_wait(20)
	await capture("title")
	game.start_fight()
	game.player.position.x = 250
	game.boss.position.x = 315
	game.boss.begin_attack("overhead")
	game.boss.enabled = false
	await frame_wait(15)
	await capture("duel")
	game.boss.phase = 3
	game.boss.begin_attack("sweep")
	game.banner = "INHERITANCE"
	game.banner_time = 3
	await frame_wait(22)
	await capture("inheritance")
	game.queue_free()
	await frame_wait(3)
	quit()
