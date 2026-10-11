extends Node

var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor: int = 0
var muted: bool = false

func _ready() -> void:
	# Frequency, duration, noise mix, metallic ring, downward pitch sweep.
	var recipes := {
		"light_hit":[470.0,0.13,0.38,0.35,0.18], "heavy_hit":[135.0,0.22,0.52,0.65,0.48],
		"boss_hit":[190.0,0.16,0.48,0.32,0.3], "major_hit":[78.0,0.25,0.60,0.58,0.5],
		"parry":[1380.0,0.26,0.08,0.95,0.06], "parry_fail":[235.0,0.09,0.58,0.10,0.65],
		"break":[85.0,0.38,0.66,0.85,0.52], "swing":[440.0,0.08,0.82,0.0,0.7],
		"heavy_swing":[240.0,0.13,0.76,0.05,0.75], "boss_swing":[170.0,0.17,0.7,0.08,0.6],
		"land":[65.0,0.07,0.8,0.0,0.25], "dodge":[550.0,0.095,0.82,0.05,0.8],
		"stance":[610.0,0.1,0.05,0.15,0.0], "phase":[70.0,0.7,0.18,0.3,0.3]}

	for key in recipes:
		sounds[key] = synth(recipes[key][0],recipes[key][1],recipes[key][2],recipes[key][3],recipes[key][4])
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)

func play(kind: String) -> void:
	if muted or not sounds.has(kind): return
	var voice := voices[cursor % voices.size()]
	cursor += 1
	voice.stream = sounds[kind]
	voice.play()

func synth(frequency: float, duration: float, noise_mix: float, metallic: float = 0, slide: float = 0) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency)
	for i in range(count):
		var t := float(i) / sample_rate
		var envelope := pow(1.0 - float(i)/count,2.4) * minf(t * 500,1.0)
		var phase := TAU * frequency * (t - slide*t*t/(2*duration))
		var tone := sin(phase) * 0.7 + sin(phase*2.73)*0.3
		var ring := (sin(TAU*1900*t)+sin(TAU*3107*t)*0.55)*exp(-t*18)*metallic*0.22
		var sample := clampf((lerpf(tone,rng.randf_range(-1,1),noise_mix)*envelope + ring*minf(t*500,1))*0.65,-1,1)
		bytes.encode_s16(i*2,int(sample*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()
