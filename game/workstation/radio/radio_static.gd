class_name RadioStatic
extends Node

## Precomputed 0.37-second PCM loop; no per-frame sound synthesis.
const RATE := 22050
const FRAMES := 8192
var playback: AudioStreamPlayer
var quality := 0.0
var voice_active := false

func _ready() -> void:
	playback = AudioStreamPlayer.new()
	playback.bus = "RadioStatic"
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
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.stereo = false
	audio.data = bytes
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_begin = 0
	audio.loop_end = FRAMES
	playback.stream = audio
	playback.play()
	_refresh_volume()

func set_signal_quality(value: float) -> void:
	quality = clampf(value, 0.0, 1.0)
	_refresh_volume()

func set_voice_active(active: bool) -> void:
	voice_active = active
	_refresh_volume()

func _refresh_volume() -> void:
	if playback == null:
		return
	var base_volume := lerpf(-23.0, -47.0, quality)
	playback.volume_db = base_volume - (9.0 if voice_active else 0.0)
