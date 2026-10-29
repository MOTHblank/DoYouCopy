class_name RadioVoice
extends Node

signal queue_drained
signal voice_activity_changed(active: bool)

## Authored OGG clips only: no runtime TTS or network services.
## Stable line IDs refer to voice assets generated offline.
var player: AudioStreamPlayer
var pending: Array[Dictionary] = []
var live_quality: float = 1.0
var speaking := false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "RadioVoice"
	add_child(player)
	player.finished.connect(_next)

func is_busy() -> bool:
	return speaking or not pending.is_empty()

func stop_all() -> void:
	pending.clear()
	player.stop()
	_set_speaking(false)

func set_signal_quality(value: float) -> void:
	live_quality = clampf(value, 0.0, 1.0)
	if player != null and player.playing:
		player.volume_db = lerpf(-8.0, -1.0, live_quality)

func enqueue(line_id: String, signal_quality: float) -> void:
	var clip := "res://content/voices/generated/%s.ogg" % line_id
	if not ResourceLoader.exists(clip):
		# Transcript-only mode is explicitly supported for development.
		return
	pending.append({"path": clip, "quality": signal_quality})
	if not speaking:
		_next()

func _set_speaking(active: bool) -> void:
	if speaking == active:
		return
	speaking = active
	voice_activity_changed.emit(active)

func _next() -> void:
	if pending.is_empty():
		_set_speaking(false)
		queue_drained.emit()
		return
	var record: Dictionary = pending.pop_front()
	var stream := load(str(record["path"])) as AudioStream
	if stream == null:
		_next()
		return
	player.stream = stream
	live_quality = clampf(float(record["quality"]), 0.0, 1.0)
	player.volume_db = lerpf(-8.0, -1.0, live_quality)
	_set_speaking(true)
	player.play()
