class_name AudioMixer
extends Node

## Audio graph configured once per scene, not an autoload. GHOST and its
## original agent share the same voice bus, so processing never reveals source.
const VOICE_BUS := "RadioVoice"
const STATIC_BUS := "RadioStatic"
const INTERFACE_BUS := "Interface"

func _ready() -> void:
	_ensure_bus(VOICE_BUS)
	_ensure_bus(STATIC_BUS)
	_ensure_bus(INTERFACE_BUS)
	_configure_voice()

func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	var position := AudioServer.bus_count
	AudioServer.add_bus(position)
	AudioServer.set_bus_name(position, name)
	AudioServer.set_bus_send(position, "Master")

func _configure_voice() -> void:
	var index := AudioServer.get_bus_index(VOICE_BUS)
	if index < 0:
		return
	# Prevent applying effects twice after restarting the scene.
	if AudioServer.get_bus_effect_count(index) > 0:
		return
	var high := AudioEffectHighPassFilter.new()
	high.cutoff_hz = 300.0
	high.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(index, high)
	var low := AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3200.0
	low.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(index, low)
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = -21.0
	compressor.ratio = 2.8
	compressor.gain = 2.5
	compressor.attack_us = 350.0
	compressor.release_ms = 180.0
	AudioServer.add_bus_effect(index, compressor)
