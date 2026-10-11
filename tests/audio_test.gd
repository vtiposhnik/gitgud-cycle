extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sound := Node.new()
	sound.set_script(load("res://scripts/sound.gd"))
	root.add_child(sound)
	var valid: bool = sound.sounds.size() == 14
	for stream in sound.sounds.values():
		valid = valid and stream.data.size() > 100 and stream.mix_rate == 22050
	if not valid:
		push_error("Synthesized audio buffers are incomplete")
		quit(1)
		return
	print("PASS: all fourteen synthesized PCM effects have valid samples")
	sound.play("parry")
	if not sound.voices[0].playing:
		push_error("Audio effect did not start")
		quit(1)
		return
	print("PASS: parry audio starts through AudioStreamPlayer")
	await create_timer(0.5).timeout
	if sound.voices[0].playing:
		push_error("Audio effect did not finish")
		quit(1)
		return
	print("PASS: audio playback completes and releases the voice")
	sound.queue_free()
	await process_frame
	print("RESULT: 3 checks, 0 failures")
	quit()
