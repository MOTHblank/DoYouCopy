class_name RadioVoice
extends Node

## Reads authored offline-rendered clips. Missing assets never block progression:
## the same line is always printed by the director on the terminal.
var player: AudioStreamPlayer
var pending: Array[Dictionary] = []
var live_quality: float = 1.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_next)

func stop_all() -> void:
	pending.clear()
	player.stop()

func set_signal_quality(quality: float) -> void:
	live_quality = clampf(quality, 0.0, 1.0)
	if player != null and player.playing:
		player.volume_db = lerpf(-7.0, -1.0, live_quality)

func enqueue(line_id: String, signal_quality: float) -> void:
	var clip := "res://content/voices/generated/%s.ogg" % line_id
	if not ResourceLoader.exists(clip):
		return
	pending.append({"path": clip, "quality": signal_quality})
	if not player.playing:
		_next()

func _next() -> void:
	if pending.is_empty():
		return
	var record: Dictionary = pending.pop_front()
	var stream: AudioStream = load(str(record["path"])) as AudioStream
	if stream == null:
		_next()
		return
	player.stream = stream
	# Keep critical words audible. Missing voice files are shown as transcripts.
	set_signal_quality(float(record["quality"]))
	player.volume_db = lerpf(-7.0, -1.0, live_quality)
	player.play()
