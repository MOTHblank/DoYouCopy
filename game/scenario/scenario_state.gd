class_name ScenarioState
extends Node

## Run-local truth: never allow a presenter to mutate this directly.
var agent_locations: Dictionary = {}
var agent_status: Dictionary = {}
var trust: Dictionary = {}
var quarantined_channels: Dictionary = {}
var ghost_knowledge: Dictionary = {}
var knowledge_history: Array[String] = []
var flags: Dictionary = {}
var decisions: Dictionary = {}
var communication_log: Array[String] = []
var exposure_count: int = 0
var quarantine_count: int = 0

const CHANNEL_OWNERS := {
	"A-PRIMARY": "ECHO-ACTUAL",
	"B-PRIMARY": "ECHO-2"
}

const SAVE_VERSION := 1
const SAVE_PATH := "user://campaign_save.json"
const SAVE_TEMP_PATH := "user://campaign_save.tmp"
const SAVE_BACKUP_PATH := "user://campaign_save.bak"

func reset_run() -> void:
	agent_locations = {"ECHO-ACTUAL": "Relay", "ECHO-2": "Pump Station B"}
	agent_status = {"ECHO-ACTUAL": "AVAILABLE", "ECHO-2": "AVAILABLE"}
	trust = {"ECHO-ACTUAL": 0, "ECHO-2": 0}
	quarantined_channels.clear()
	ghost_knowledge.clear()
	knowledge_history.clear()
	flags.clear()
	decisions.clear()
	communication_log.clear()
	exposure_count = 0
	quarantine_count = 0

func save_checkpoint(next_contact_index: int) -> bool:
	if next_contact_index < 0:
		push_warning("Refusing to save invalid campaign checkpoint index.")
		return false
	var payload := {
		"version": SAVE_VERSION,
		"next_contact_index": next_contact_index,
		"state": snapshot()
	}
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open campaign checkpoint for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null

	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var had_active := FileAccess.file_exists(SAVE_PATH)
	if had_active:
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_warning("Could not preserve previous campaign checkpoint: %s" % backup_error)
			return false

	var promote_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if promote_error != OK:
		if had_active and FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		push_warning("Could not publish campaign checkpoint: %s" % promote_error)
		return false
	return true

func load_checkpoint() -> int:
	for path in [SAVE_PATH, SAVE_BACKUP_PATH]:
		var payload := _load_checkpoint_file(path)
		if payload.is_empty():
			continue
		if int(payload.get("version", -1)) != SAVE_VERSION:
			continue
		var next_contact_index := int(payload.get("next_contact_index", -1))
		var state_variant: Variant = payload.get("state", {})
		if next_contact_index < 0 or not (state_variant is Dictionary):
			continue
		var state_data: Dictionary = state_variant
		if restore_snapshot(state_data):
			return next_contact_index
	return -1

func clear_checkpoint() -> void:
	for path in [SAVE_PATH, SAVE_TEMP_PATH, SAVE_BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func restore_snapshot(data: Dictionary) -> bool:
	var raw_locations: Variant = data.get("locations", {})
	var raw_status: Variant = data.get("status", {})
	var raw_trust: Variant = data.get("trust", {})
	if not (raw_locations is Dictionary) or not (raw_status is Dictionary) or not (raw_trust is Dictionary):
		return false

	reset_run()
	for callsign in agent_locations.keys():
		if raw_locations.has(callsign):
			agent_locations[callsign] = str(raw_locations[callsign])
		if raw_status.has(callsign):
			agent_status[callsign] = str(raw_status[callsign])
		if raw_trust.has(callsign):
			trust[callsign] = int(raw_trust[callsign])

	var raw_channels: Variant = data.get("channels", {})
	if raw_channels is Dictionary:
		quarantined_channels = raw_channels.duplicate(true)
	var raw_knowledge: Variant = data.get("ghost_knowledge", {})
	if raw_knowledge is Dictionary:
		ghost_knowledge = raw_knowledge.duplicate(true)
	var raw_flags: Variant = data.get("flags", {})
	if raw_flags is Dictionary:
		flags = raw_flags.duplicate(true)
	var raw_decisions: Variant = data.get("decisions", {})
	if raw_decisions is Dictionary:
		decisions = raw_decisions.duplicate(true)

	knowledge_history.clear()
	var raw_history: Variant = data.get("knowledge_history", [])
	if raw_history is Array:
		for entry in raw_history:
			knowledge_history.append(str(entry))

	communication_log.clear()
	var raw_log: Variant = data.get("communication_log", [])
	if raw_log is Array:
		var first := maxi(0, raw_log.size() - 45)
		for entry_index in range(first, raw_log.size()):
			communication_log.append(str(raw_log[entry_index]))

	exposure_count = maxi(0, int(data.get("exposure", 0)))
	quarantine_count = clampi(int(data.get("quarantines", quarantined_channels.size())), 0, 2)
	return true

func _load_checkpoint_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return parsed

func has_flag(flag: String) -> bool:
	return flags.has(flag)

func knows(fact: String) -> bool:
	return ghost_knowledge.has(fact)

func learn(fact: String, origin: String) -> void:
	if fact.is_empty() or ghost_knowledge.has(fact):
		return
	ghost_knowledge[fact] = true
	knowledge_history.append("%s <- %s" % [fact, origin])

func can_access(channel: StringName) -> bool:
	return not quarantined_channels.has(String(channel))

func quarantine_channel(channel: StringName) -> bool:
	var key := String(channel)
	if key.is_empty() or not can_access(channel) or quarantine_count >= 2:
		return false
	quarantined_channels[key] = true
	quarantine_count += 1
	if CHANNEL_OWNERS.has(key):
		var owner: String = CHANNEL_OWNERS[key]
		if agent_status[owner] == "AVAILABLE":
			agent_status[owner] = "UNREACHABLE"
	flags["quarantined_" + key] = true
	return true

func append_log(line: String) -> void:
	communication_log.append(line)
	if communication_log.size() > 45:
		communication_log.pop_front()

func displayed_location(callsign: String) -> String:
	# This lie changes only the terminal rendering. The paper map and true field
	# state continue to use agent_locations.
	if has_flag("terminal_unreliable") and callsign == "ECHO-ACTUAL":
		return "East Service [STATION SYNC]"
	return str(agent_locations.get(callsign, "UNKNOWN"))

## Effects are limited to approved verbs; no arbitrary code in .tres files.
func apply_effect(effect: String) -> void:
	var parts := effect.split(":", false)
	if parts.size() < 2:
		push_warning("Invalid scenario effect: " + effect)
		return
	match parts[0]:
		"flag":
			if parts.size() == 2:
				flags[parts[1]] = true
		"location":
			if parts.size() == 3 and agent_locations.has(parts[1]):
				agent_locations[parts[1]] = parts[2]
		"status":
			if parts.size() == 3 and agent_status.has(parts[1]):
				agent_status[parts[1]] = parts[2]
		"trust":
			if parts.size() == 3 and trust.has(parts[1]) and parts[2].is_valid_int():
				trust[parts[1]] = int(trust[parts[1]]) + int(parts[2])
		"exposure":
			if parts.size() == 2 and parts[1].is_valid_int():
				exposure_count += int(parts[1])
		_:
			push_warning("Unknown scenario effect: " + effect)

func ending_family() -> String:
	# An unquarantined alternate route can also be contained by consistently
	# rejecting the learned copy and rerouting the last verified agent.
	var sealed: bool = quarantined_channels.has("A-ALT")
	if decisions.get("C08", "") == "PROCEED":
		# A final blind clearance compromises even an otherwise secure shift.
		return "OPEN_LINE"
	if not sealed:
		# HOLD and REROUTE protect lives, but do not physically isolate
		# an alternate carrier. Only a sealed route is contained.
		return "OPEN_LINE"
	var agent_lost: bool = (
		agent_status["ECHO-ACTUAL"] != "AVAILABLE"
		or agent_status["ECHO-2"] != "AVAILABLE"
	)
	return "ISOLATED" if agent_lost else "CONTAINED"

func snapshot() -> Dictionary:
	return {
		"locations": agent_locations.duplicate(true),
		"status": agent_status.duplicate(true),
		"trust": trust.duplicate(true),
		"channels": quarantined_channels.duplicate(true),
		"ghost_knowledge": ghost_knowledge.duplicate(true),
		"knowledge_history": knowledge_history.duplicate(),
		"flags": flags.duplicate(true),
		"decisions": decisions.duplicate(true),
		"communication_log": communication_log.duplicate(),
		"exposure": exposure_count,
		"quarantines": quarantine_count
	}
