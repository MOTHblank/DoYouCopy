class_name RadioStatic
extends Node

## One small deterministic PCM loop. No allocation or random noise per frame.
const RATE := 22050
const FRAMES := 8192
var playback: AudioStreamPlayer

func _ready() -> void:
	playback = AudioStreamPlayer.new()
	playback.volume_db = -27.0
	add_child(playback)
	var bytes := PackedByteArray()
	bytes.resize(FRAMES * 2)
	var seed: int = 41257
	var previous := 0.0
	for i in range(FRAMES):
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var random_sample := float((seed >> 12) & 0xffff) / 32768.0 - 1.0
		previous = lerpf(previous, random_sample, 0.46)
		var sample := int(clampf(previous * 0.28, -1.0, 1.0) * 32767.0)
		bytes[i * 2] = sample & 255
		bytes[i * 2 + 1] = (sample >> 8) & 255
	var sample_stream := AudioStreamWAV.new()
	sample_stream.format = AudioStreamWAV.FORMAT_16_BITS
	sample_stream.mix_rate = RATE
	sample_stream.stereo = false
	sample_stream.data = bytes
	sample_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample_stream.loop_begin = 0
	sample_stream.loop_end = FRAMES
	playback.stream = sample_stream
	playback.play()

func set_signal_quality(quality: float) -> void:
	if playback == null:
		return
	# Quiet enough that speech and important authentication words remain clear.
	playback.volume_db = lerpf(-22.0, -47.0, clampf(quality, 0.0, 1.0))
