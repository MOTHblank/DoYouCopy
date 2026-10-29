extends Node3D

@onready var run_state: ScenarioState = $ScenarioState
@onready var radio: RadioConsole = $RadioConsole
@onready var director: ScenarioDirector = $ScenarioDirector
@onready var room: WorkstationRoom = $WorkstationRoom
@onready var player: PlayerRig = $PlayerRig
@onready var hud: WorkstationHUD = $HUD
var station_audio: StationAudio
var radio_voice: RadioVoice
var radio_static: RadioStatic
var audio_mixer: AudioMixer

func _ready() -> void:
	audio_mixer = AudioMixer.new()
	add_child(audio_mixer)
	station_audio = StationAudio.new()
	add_child(station_audio)
	radio_voice = RadioVoice.new()
	add_child(radio_voice)
	radio_static = RadioStatic.new()
	add_child(radio_static)
	director.setup(run_state, radio)
	director.opening_audio_gate = true
	hud.bind(director, radio, run_state)
	player.station_object_selected.connect(hud.show_station_object)
	player.station_control_adjusted.connect(hud.adjust_station)
	hud.action_transmitted.connect(player.animate_station_action)
	radio.tuning_changed.connect(func(_freq: float) -> void: _sync_screens())
	radio.quality_changed.connect(func(quality: float) -> void:
		radio_static.set_signal_quality(quality)
		radio_voice.set_signal_quality(quality)
		_sync_screens()
	)
	radio.signal_acquired.connect(func(_freq: float) -> void: station_audio.cue("acquired"))
	radio.signal_lost.connect(radio_voice.stop_all)
	radio_voice.voice_activity_changed.connect(radio_static.set_voice_active)
	radio_voice.queue_drained.connect(director.opening_voice_finished)
	director.opening_transcript_complete.connect(func() -> void:
		if not radio_voice.is_busy():
			director.opening_voice_finished()
	)
	director.contact_started.connect(func(_contact: ContactDefinition, _n: int, _total: int) -> void:
		radio_voice.stop_all()
		_sync_screens()
	)
	director.phase_changed.connect(func(_phase: String) -> void: _sync_screens())
	director.message_emitted.connect(func(_speaker: String, _line: String, id: String) -> void:
		radio_voice.enqueue(id, radio.quality)
		if id.contains("_AUTH"):
			station_audio.cue("auth")
	)
	director.consequence_emitted.connect(func(_line: String) -> void:
		radio_voice.stop_all()
		station_audio.cue("decision")
	)
	director.run_finished.connect(func(_report: String) -> void:
		radio_voice.stop_all()
		radio_static.set_signal_quality(1.0)
	)
	director.begin_run()

func _sync_screens() -> void:
	if director.contact != null:
		room.update_station(director.contact, run_state, radio, director.phase == "VERIFYING" or director.phase == "RESOLVING")
