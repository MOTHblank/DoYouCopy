extends Node3D

@onready var run_state: ScenarioState = $ScenarioState
@onready var radio: RadioConsole = $RadioConsole
@onready var director: ScenarioDirector = $ScenarioDirector
@onready var room: WorkstationRoom = $WorkstationRoom
@onready var player: PlayerRig = $PlayerRig
@onready var hud: WorkstationHUD = $HUD
var station_audio: StationAudio
var radio_voice: RadioVoice

func _ready() -> void:
	station_audio = StationAudio.new()
	add_child(station_audio)
	radio_voice = RadioVoice.new()
	add_child(radio_voice)
	director.setup(run_state, radio)
	hud.bind(director, radio, run_state)
	player.station_object_selected.connect(hud.show_station_object)
	player.frequency_wheel.connect(radio.adjust_frequency)
	radio.tuning_changed.connect(func(_freq: float) -> void: _sync_screens())
	radio.quality_changed.connect(func(_quality: float) -> void: _sync_screens())
	radio.signal_acquired.connect(func(_freq: float) -> void: station_audio.cue("acquired"))
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
	director.consequence_emitted.connect(func(_line: String) -> void: station_audio.cue("decision"))
	director.run_finished.connect(func(_report: String) -> void: radio_voice.stop_all())
	director.begin_run()

func _sync_screens() -> void:
	if director.contact != null:
		room.update_station(director.contact, run_state, radio, director.phase == "VERIFYING" or director.phase == "RESOLVING")
