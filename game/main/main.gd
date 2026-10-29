extends Node3D

@onready var run_state: ScenarioState = $ScenarioState
@onready var radio: RadioConsole = $RadioConsole
@onready var director: ScenarioDirector = $ScenarioDirector
@onready var room: WorkstationRoom = $WorkstationRoom
@onready var player: PlayerRig = $PlayerRig
@onready var hud: WorkstationHUD = $HUD
var station_audio: StationAudio

func _ready() -> void:
	station_audio = StationAudio.new()
	add_child(station_audio)
	director.setup(run_state, radio)
	hud.bind(director, radio, run_state)
	player.station_object_selected.connect(hud.show_station_object)
	player.frequency_wheel.connect(radio.adjust_frequency)
	radio.tuning_changed.connect(func(_freq: float) -> void: _sync_screens())
	radio.quality_changed.connect(func(_quality: float) -> void: _sync_screens())
	radio.signal_acquired.connect(func(_freq: float) -> void: station_audio.cue("acquired"))
	director.contact_started.connect(func(_contact: ContactDefinition, _n: int, _total: int) -> void: _sync_screens())
	director.phase_changed.connect(func(_phase: String) -> void: _sync_screens())
	director.message_emitted.connect(func(_speaker: String, _line: String, id: String) -> void:
		if id.ends_with("_AUTH"):
			station_audio.cue("auth")
	)
	director.consequence_emitted.connect(func(_line: String) -> void: station_audio.cue("decision"))
	director.begin_run()

func _sync_screens() -> void:
	if director.contact != null:
		room.update_station(director.contact, run_state, radio, director.phase == "VERIFYING" or director.phase == "RESOLVING")
