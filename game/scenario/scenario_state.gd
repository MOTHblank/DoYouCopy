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
## In-flight generations remain readable if a rename or backup replacement fails.
const SAVE_ROTATION_PATH := "user://campaign_save.rotating"
const SAVE_BACKUP_TEMP_PATH := "user://campaign_save.bak.tmp"

func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if value is int:
		return value >= minimum and value <= maximum
	if value is float:
		return is_finite(value) and value == floorf(value) and value >= minimum and value <= maximum
	return false

func _valid_snapshot(data: Dictionary) -> bool:
	# Check the complete schema before restore_snapshot resets any live run state.
	for key in ["locations", "status", "trust", "channels", "ghost_knowledge", "flags", "decisions"]:
		if not (data.get(key) is Dictionary):
			return false
	for key in ["knowledge_history", "communication_log"]:
		if not (data.get(key) is Array):
			return false
	var locations: Dictionary = data["locations"]
	var status: Dictionary = data["status"]
	var trust_data: Dictionary = data["trust"]
	for agent in ["ECHO-ACTUAL", "ECHO-2"]:
		if not (locations.get(agent) is String) or str(locations[agent]).is_empty():
			return false
		if not (status.get(agent) is String) or str(status[agent]).is_empty():
			return false
		if not _valid_integer(trust_data.get(agent), -100000, 100000):
			return false
	var channels: Dictionary = data["channels"]
	for channel in channels.keys():
		if not (channel is String) or not (channels[channel] is bool) or not channels[channel]:
			return false
	for field in ["ghost_knowledge", "flags"]:
		var values: Dictionary = data[field]
		for key in values.keys():
			if not (key is String) or not (values[key] is bool) or not values[key]:
				return false
	var decisions_data: Dictionary = data["decisions"]
	for contact_id in decisions_data.keys():
		if not (contact_id is String) or not (decisions_data[contact_id] is String):
			return false
		if not ["HOLD", "PROCEED", "REROUTE", "QUARANTINE"].has(decisions_data[contact_id]):
			return false
	for field in ["knowledge_history", "communication_log"]:
		for entry in data[field]:
			if not (entry is String):
				return false
	if not _valid_integer(data.get("exposure"), 0, 100000):
		return false
	if not _valid_integer(data.get("quarantines"), 0, 2):
		return false
	return int(data["quarantines"]) == channels.size()

func _valid_checkpoint(payload: Dictionary) -> bool:
	if not _valid_integer(payload.get("version"), SAVE_VERSION, SAVE_VERSION):
		return false
	if not _valid_integer(payload.get("next_contact_index"), 0, 10000):
		return false
	# Generation 0 is reserved for checkpoints created before generation tracking.
	if not _valid_integer(payload.get("generation", 0), 0, 2147483647):
		return false
	var raw_state: Variant = payload.get("state")
	return raw_state is Dictionary and _valid_snapshot(raw_state)

func _load_checkpoint_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file = null
	if not (parsed is Dictionary):
		return {}
	if not _valid_checkpoint(parsed):
		return {}
	return parsed

func _checkpoint_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	# Equal-generation ties prefer published data; higher generations always win.
	var paths := [SAVE_PATH, SAVE_BACKUP_PATH, SAVE_ROTATION_PATH, SAVE_BACKUP_TEMP_PATH, SAVE_TEMP_PATH]
	for position in range(paths.size()):
		var payload := _load_checkpoint_file(paths[position])
		if payload.is_empty():
			continue
		candidates.append({
			"path": paths[position],
			"generation": int(payload.get("generation", 0)),
			"priority": paths.size() - position,
			"payload": payload
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["generation"] == b["generation"]:
			return int(a["priority"]) > int(b["priority"])
		return int(a["generation"]) > int(b["generation"])
	)
	return candidates

func save_checkpoint(next_contact_index: int) -> bool:
	if next_contact_index < 0:
		push_warning("Refusing to save invalid campaign checkpoint index.")
		return false
	var generation := 1
	var previous_candidates := _checkpoint_candidates()
	if not previous_candidates.is_empty():
		generation = int(previous_candidates[0]["generation"]) + 1
	var payload := {
		"version": SAVE_VERSION,
		"generation": generation,
		"next_contact_index": next_contact_index,
		"state": snapshot()
	}
	if not _valid_checkpoint(payload):
		push_warning("Refusing to save an inconsistent campaign snapshot.")
		return false

	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open campaign checkpoint for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file = null
	if write_error != OK:
		push_warning("Campaign checkpoint write/flush failed: %s" % write_error)
		return false
	# A successful write is not enough: parse and validate exactly what hit disk.
	var staged := _load_checkpoint_file(SAVE_TEMP_PATH)
	if staged.is_empty() or int(staged.get("generation", -1)) != generation:
		push_warning("Staged campaign checkpoint did not survive readback validation.")
		return false

	var active_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var staged_absolute := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var rotation_absolute := ProjectSettings.globalize_path(SAVE_ROTATION_PATH)
	var backup_absolute := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var backup_temp_absolute := ProjectSettings.globalize_path(SAVE_BACKUP_TEMP_PATH)

	# Stage is now independently recoverable. Keep the previous active and backup
	# generations until the new active has been published and read back.
	if FileAccess.file_exists(SAVE_ROTATION_PATH):
		var rotation_clear_error := DirAccess.remove_absolute(rotation_absolute)
		if rotation_clear_error != OK:
			push_warning("Could not clear interrupted checkpoint rotation: %s" % rotation_clear_error)
			return false
	var had_active := FileAccess.file_exists(SAVE_PATH)
	if had_active:
		var rotation_error := DirAccess.rename_absolute(active_absolute, rotation_absolute)
		if rotation_error != OK:
			push_warning("Could not retain the previous campaign checkpoint: %s" % rotation_error)
			return false

	var publish_error := DirAccess.rename_absolute(staged_absolute, active_absolute)
	if publish_error != OK:
		if had_active:
			DirAccess.rename_absolute(rotation_absolute, active_absolute)
		push_warning("Could not publish campaign checkpoint: %s" % publish_error)
		return false
	var published := _load_checkpoint_file(SAVE_PATH)
	if published.is_empty() or int(published.get("generation", -1)) != generation:
		DirAccess.remove_absolute(active_absolute)
		if had_active:
			DirAccess.rename_absolute(rotation_absolute, active_absolute)
		push_warning("Published checkpoint failed its final integrity check.")
		return false

	# Backup updates happen only AFTER a good active has been published. A
	# failed copy/rename leaves either the old backup or the rotated generation.
	if had_active:
		var rotated := _load_checkpoint_file(SAVE_ROTATION_PATH)
		var backup := _load_checkpoint_file(SAVE_BACKUP_PATH)
		if not rotated.is_empty() and (backup.is_empty() or int(rotated.get("generation", 0)) > int(backup.get("generation", 0))):
			var copy_error := DirAccess.copy_absolute(rotation_absolute, backup_temp_absolute)
			if copy_error == OK and not _load_checkpoint_file(SAVE_BACKUP_TEMP_PATH).is_empty():
				var removal_error := OK
				if FileAccess.file_exists(SAVE_BACKUP_PATH):
					removal_error = DirAccess.remove_absolute(backup_absolute)
				if removal_error == OK:
					var backup_error := DirAccess.rename_absolute(backup_temp_absolute, backup_absolute)
					if backup_error != OK:
						push_warning("New active checkpoint is safe; backup rotation is still pending: %s" % backup_error)
				else:
					push_warning("New active checkpoint is safe; previous backup could not be replaced.")
			else:
				push_warning("New active checkpoint is safe; previous generation could not be copied to backup.")
	# Keep the rotation as an additional readable fallback if backup staging failed.
	return true

func load_checkpoint() -> int:
	for candidate in _checkpoint_candidates():
		var payload: Dictionary = candidate["payload"]
		var state_data: Dictionary = payload["state"]
		if restore_snapshot(state_data):
			return int(payload["next_contact_index"])
	return -1

func clear_checkpoint() -> void:
	for path in [SAVE_PATH, SAVE_TEMP_PATH, SAVE_BACKUP_PATH, SAVE_ROTATION_PATH, SAVE_BACKUP_TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func restore_snapshot(data: Dictionary) -> bool:
	if not _valid_snapshot(data):
		return false
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
