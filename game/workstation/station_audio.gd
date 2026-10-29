class_name StationAudio
extends Node

## Asset-free interface cues only. Agent voice files are explicitly not yet included.
var output: AudioStreamPlayer
const SAMPLE_RATE := 22050

func _ready() -> void:
	output = AudioStreamPlayer.new()
	output.volume_db = -13.0
	add_child(output)

func cue(kind: String) -> void:
	var frequency := 700.0
	var seconds := 0.16
	match kind:
		"acquired":
			frequency = 880.0
			seconds = 0.21
		"auth":
			frequency = 610.0
			seconds = 0.12
		"decision":
			frequency = 420.0
			seconds = 0.14
		"warning":
			frequency = 170.0
			seconds = 0.30
	var sample_count := int(float(SAMPLE_RATE) * seconds)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(SAMPLE_RATE)
		var fade := minf(1.0, t * 35.0) * minf(1.0, (seconds - t) * 25.0)
		var signal_value := sin(t * frequency * TAU) * fade * 0.22
		var sample := int(clampf(signal_value, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	output.stream = wav
	output.play()
