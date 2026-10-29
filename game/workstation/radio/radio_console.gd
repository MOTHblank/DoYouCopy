class_name RadioConsole
extends Node

signal tuning_changed(frequency: float)
signal quality_changed(value: float)
signal signal_acquired(frequency: float)
signal signal_lost

var frequency: float = 101.0
var cleanup: float = 0.40
var target_frequency: float = 101.30
var tolerance: float = 0.42
var cleanup_target: float = 0.76
var quality: float = 0.0
var acquired: bool = false
var blocked: bool = false

func configure(contact: ContactDefinition, quarantined: bool = false) -> void:
	target_frequency = contact.frequency
	tolerance = maxf(contact.tolerance, 0.05)
	cleanup_target = contact.cleanup_target
	blocked = quarantined
	acquired = false
	_recalculate()

func set_frequency(value: float) -> void:
	frequency = snappedf(clampf(value, 100.0, 110.0), 0.05)
	tuning_changed.emit(frequency)
	_recalculate()

func adjust_frequency(steps: float) -> void:
	set_frequency(frequency + steps * 0.05)

func set_cleanup(value: float) -> void:
	cleanup = clampf(value, 0.0, 1.0)
	_recalculate()

func _recalculate() -> void:
	var tune := 1.0 - clampf(absf(frequency - target_frequency) / tolerance, 0.0, 1.0)
	var cleaned := 1.0 - clampf(absf(cleanup - cleanup_target) / 0.80, 0.0, 1.0)
	quality = 0.0 if blocked else tune * cleaned
	quality_changed.emit(quality)
	if quality < 0.35 and acquired:
		acquired = false
		signal_lost.emit()
	if quality >= 0.72 and not acquired:
		acquired = true
		signal_acquired.emit(frequency)

func signal_label() -> String:
	if blocked:
		return "CHANNEL BLOCKED"
	if quality < 0.20:
		return "STATIC / NO CARRIER"
	if quality < 0.45:
		return "WEAK / FRAGMENTED"
	if quality < 0.72:
		return "CARRIER / CLEAN SIGNAL"
	return "VOICE LOCK / RECEIVE"
