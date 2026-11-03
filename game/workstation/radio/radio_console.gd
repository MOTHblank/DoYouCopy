class_name RadioConsole
extends Node

signal tuning_changed(frequency: float)
signal quality_changed(value: float)
signal signal_acquired(frequency: float)
signal signal_lost

var frequency: float = 101.0
var cleanup: float = 0.40
var squelch: float = 0.22
var bandwidth: float = 0.55
var target_frequency: float = 101.30
var tolerance: float = 0.42
var cleanup_target: float = 0.76
var bandwidth_target: float = 0.55
var interference_level: float = 0.25
var squelch_muted: bool = false
var quality: float = 0.0
var acquired: bool = false
var blocked: bool = false

func configure(contact: ContactDefinition, quarantined: bool = false) -> void:
	target_frequency = contact.frequency
	tolerance = maxf(contact.tolerance, 0.05)
	cleanup_target = contact.cleanup_target
	bandwidth_target = contact.bandwidth_target
	interference_level = contact.interference_level
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

func set_squelch(value: float) -> void:
	squelch = clampf(value, 0.0, 1.0)
	_recalculate()

func set_bandwidth(value: float) -> void:
	bandwidth = clampf(value, 0.0, 1.0)
	_recalculate()

func _recalculate() -> void:
	# Narrow bandwidth rejects noise but also reduces the capture window.
	var effective_tolerance := tolerance * (0.45 + 0.90 * bandwidth)
	var tune := 1.0 - clampf(absf(frequency - target_frequency) / effective_tolerance, 0.0, 1.0)
	var cleaned := 1.0 - clampf(absf(cleanup - cleanup_target) / 0.80, 0.0, 1.0)
	var detail := 1.0 - absf(bandwidth - bandwidth_target) * 0.22
	var carrier_strength := tune * cleaned * detail
	var noise := interference_level * bandwidth * (1.0 - 0.75 * squelch)
	# Tight squelch suppresses static but can entirely mute weak signals.
	squelch_muted = not blocked and tune >= 0.40 and carrier_strength < (0.10 + squelch * 0.70)
	quality = 0.0 if blocked or squelch_muted else carrier_strength * (1.0 - 0.32 * noise)
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
	if squelch_muted:
		return "SQUELCH / CARRIER MUTED"
	if quality < 0.20:
		return "STATIC / NO CARRIER"
	if quality < 0.45:
		return "WEAK / FRAGMENTED"
	if quality < 0.72:
		return "CARRIER / ADJUST FILTERS"
	if transcript_tier() < 3:
		return "VOICE LOCK / PARTIAL COPY"
	return "VOICE LOCK / CLEAR COPY"

## Higher clarity exposes a superset of earlier words. No randomness and no
## identity-aware logic: legitimate and copied voices use the same decoder.
func transcript_tier() -> int:
	if blocked or squelch_muted or quality < 0.55:
		return 0
	if quality < 0.74:
		return 1
	if quality < 0.82:
		return 2
	return 3

func render_transcript(authored: String, line_id: String) -> String:
	var tier := transcript_tier()
	if tier == 3:
		return authored
	if tier == 0:
		return "[Speech unintelligible. Adjust the receiver and request a repeat.]"
	var seed := 0
	for n in range(line_id.length()):
		seed = (seed * 31 + line_id.unicode_at(n)) % 10007
	var threshold := 37 if tier == 2 else 67
	var words := authored.split(" ", false)
	var copy := PackedStringArray()
	var missing := false
	for n in range(words.size()):
		var audible := n < 2 or posmod(seed + n * 71 + n * n * 19, 101) >= threshold
		if audible:
			copy.append(words[n])
			missing = false
		elif not missing:
			copy.append("[unreadable]")
			missing = true
	return " ".join(copy)
