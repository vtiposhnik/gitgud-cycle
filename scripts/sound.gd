extends Node

var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor: int = 0
var muted: bool = false

func _ready() -> void:
	var recipes := {"hit": [100.0,0.13,0.65], "parry": [1120.0,0.23,0.08], "break": [180.0,0.36,0.6],
		"swing": [280.0,0.10,0.7], "boss_swing": [140.0,0.19,0.65], "land": [65.0,0.07,0.8],
		"dodge": [180.0,0.12,0.7], "stance": [610.0,0.1,0.05], "phase": [70.0,0.7,0.18]}
	for key in recipes:
		sounds[key] = synth(recipes[key][0],recipes[key][1],recipes[key][2])
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

func synth(frequency: float, duration: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency)
	for i in range(count):
		var t := float(i) / sample_rate
		var envelope := pow(1.0 - float(i)/count,2.4) * minf(t * 500,1.0)
		var tone := sin(TAU*frequency*t) * 0.7 + sin(TAU*frequency*2.73*t)*0.3
		var sample := lerpf(tone,rng.randf_range(-1,1),noise_mix)*envelope*0.65
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
