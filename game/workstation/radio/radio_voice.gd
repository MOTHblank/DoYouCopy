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
var current_line_seed: int = 0
var last_dropout_slot: int = -1

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "RadioVoice"
	add_child(player)
	player.finished.connect(_next)

func _process(_delta: float) -> void:
	if player == null or not player.playing:
		return
	var slot := floori(player.get_playback_position() / 0.22)
	if slot != last_dropout_slot:
		last_dropout_slot = slot
		_refresh_voice_level()

func is_busy() -> bool:
	return speaking or not pending.is_empty()

func stop_all() -> void:
	pending.clear()
	player.stop()
	_set_speaking(false)
	last_dropout_slot = -1

func set_signal_quality(value: float) -> void:
	live_quality = clampf(value, 0.0, 1.0)
	_refresh_voice_level()

func _refresh_voice_level() -> void:
	if player == null:
		return
	var level := lerpf(-12.0, -1.0, live_quality)
	if player.playing and live_quality < 0.82:
		# Short repeatable dropouts follow playback time, not GHOST identity.
		# Clean reception immediately restores the uninterrupted recording.
		var slot := floori(player.get_playback_position() / 0.22)
		var pattern := posmod(current_line_seed + slot * 7, 13)
		if pattern < (3 if live_quality < 0.74 else 1):
			level -= 17.0
	player.volume_db = level

func enqueue(line_id: String, signal_quality: float) -> void:
	var clip := "res://content/voices/generated/%s.ogg" % line_id
	if not ResourceLoader.exists(clip):
		# Transcript-only mode is explicitly supported for development.
		return
	pending.append({"path": clip, "quality": signal_quality, "id": line_id})
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
	var line_id := String(record["id"])
	current_line_seed = 0
	for n in range(line_id.length()):
		current_line_seed = (current_line_seed * 31 + line_id.unicode_at(n)) % 10007
	last_dropout_slot = -1
	_set_speaking(true)
	player.play()
	_refresh_voice_level()
