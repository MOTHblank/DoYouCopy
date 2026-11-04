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
## Player-facing evidence is a chronology of observations, NOT a truth oracle.
var evidence_events: Array[Dictionary] = []
var map_annotations: Array[Dictionary] = []
var evidence_sequence: int = 0
var annotation_sequence: int = 0
var elapsed_base_seconds: float = 0.0
var shift_started_ms: int = 0

const MAP_STATIONS := ["Relay", "Junction", "Pump Station B", "East Service"]
const ANNOTATION_KINDS := ["SUSPECTED POSITION", "POSSIBLE ORIGIN", "ESCAPE ROUTE"]
const EVIDENCE_KINDS := ["TRANSMISSION", "STATION", "OPERATOR", "DECISION", "FIELD"]
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

func reset_run() -> void:
	# A new shift starts from the first independently recorded field positions.
	agent_locations = {"ECHO-ACTUAL": "Relay", "ECHO-2": "Pump Station B"}
	agent_status = {"ECHO-ACTUAL": "AVAILABLE", "ECHO-2": "AVAILABLE"}
	trust = {"ECHO-ACTUAL": 0, "ECHO-2": 0}
	quarantined_channels.clear()
	ghost_knowledge.clear()
	knowledge_history.clear()
	flags.clear()
	decisions.clear()
	communication_log.clear()
	evidence_events.clear()
	map_annotations.clear()
	evidence_sequence = 0
	annotation_sequence = 0
	elapsed_base_seconds = 0.0
	shift_started_ms = Time.get_ticks_msec()
	exposure_count = 0
	quarantine_count = 0

func shift_seconds() -> float:
	return elapsed_base_seconds + maxf(0.0, float(Time.get_ticks_msec() - shift_started_ms) / 1000.0)

func record_evidence(kind: String, contact_id: String, message: String,
		channel: String = "", callsign: String = "", claimed: String = "") -> void:
	if not EVIDENCE_KINDS.has(kind):
		return
	evidence_sequence += 1
	# Verified positions come ONLY from the field map, never from terminal sync,
	# contact.actual_source, ghost learning, or claimed transmissions.
	var independently_recorded := ""
	if agent_locations.has(callsign):
		independently_recorded = str(agent_locations[callsign])
	evidence_events.append({
		"seq": evidence_sequence, "time": shift_seconds(), "contact": contact_id,
		"kind": kind, "channel": channel, "callsign": callsign,
		"statement": message.substr(0, 2000), "claimed": claimed.substr(0, 240),
		"verified": independently_recorded
	})
	if evidence_events.size() > 250:
		evidence_events.pop_front()

func add_annotation(station: String, kind: String, note: String, contact_id: String) -> int:
	var clean_note := note.strip_edges()
	if not MAP_STATIONS.has(station) or not ANNOTATION_KINDS.has(kind):
		return -1
	if clean_note.is_empty() or clean_note.length() > 140 or map_annotations.size() >= 32:
		return -1
	annotation_sequence += 1
	map_annotations.append({
		"id": annotation_sequence, "station": station, "kind": kind,
		"note": clean_note, "contact": contact_id
	})
	return annotation_sequence

func remove_annotation(annotation_id: int) -> bool:
	for i in range(map_annotations.size()):
		if int(map_annotations[i]["id"]) == annotation_id:
			map_annotations.remove_at(i)
			return true
	return false

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
	# Optional additions to v1 preserve previously saved completed-contact checkpoints.
	if not (data.get("evidence_events", []) is Array) or not (data.get("map_annotations", []) is Array):
		return false
	if not _valid_integer(data.get("evidence_sequence", 0), 0, 100000):
		return false
	if not _valid_integer(data.get("annotation_sequence", 0), 0, 100000):
		return false
	var elapsed: Variant = data.get("elapsed_seconds", 0.0)
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or float(elapsed) < 0.0 or float(elapsed) > 10000000.0:
		return false
	if data.get("evidence_events", []).size() > 250 or data.get("map_annotations", []).size() > 32:
		return false
	var last_seq := 0
	for entry in data.get("evidence_events", []):
		if not (entry is Dictionary):
			return false
		if not _valid_integer(entry.get("seq"), last_seq + 1, 100000):
			return false
		last_seq = int(entry["seq"])
		if not (entry.get("kind") is String) or not EVIDENCE_KINDS.has(entry["kind"]):
			return false
		for key in ["contact", "channel", "callsign", "statement", "claimed", "verified"]:
			if not (entry.get(key) is String) or String(entry[key]).length() > 2000:
				return false
		var event_time: Variant = entry.get("time")
		if not (event_time is int or event_time is float) or not is_finite(float(event_time)) or float(event_time) < 0.0 or float(event_time) > 10000000.0:
			return false
	if int(data.get("evidence_sequence", 0)) < last_seq:
		return false
	var max_annotation_id := 0
	for note in data.get("map_annotations", []):
		if not (note is Dictionary):
			return false
		if not _valid_integer(note.get("id"), 1, 100000):
			return false
		max_annotation_id = maxi(max_annotation_id, int(note["id"]))
		if not (note.get("station") is String) or not MAP_STATIONS.has(note["station"]):
			return false
		if not (note.get("kind") is String) or not ANNOTATION_KINDS.has(note["kind"]):
			return false
		if not (note.get("note") is String) or String(note["note"]).is_empty() or String(note["note"]).length() > 140:
			return false
		if not (note.get("contact") is String) or String(note["contact"]).length() > 32:
			return false
	if int(data.get("annotation_sequence", 0)) < max_annotation_id:
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
		# A crash can leave the only newest valid checkpoint in the temporary
		# slot. Copy it to active and validate before reusing that slot.
		if String(previous_candidates[0]["path"]) == SAVE_TEMP_PATH:
			var rescue_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(SAVE_TEMP_PATH),
				ProjectSettings.globalize_path(SAVE_PATH)
			)
			if rescue_error != OK or _load_checkpoint_file(SAVE_PATH).is_empty():
				push_warning("Could not preserve the recovered temporary checkpoint.")
				return false
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

	evidence_events = (data.get("evidence_events", []) as Array).duplicate(true)
	map_annotations = (data.get("map_annotations", []) as Array).duplicate(true)
	evidence_sequence = int(data.get("evidence_sequence", 0))
	annotation_sequence = int(data.get("annotation_sequence", 0))
	elapsed_base_seconds = float(data.get("elapsed_seconds", 0.0))
	shift_started_ms = Time.get_ticks_msec()
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
		"evidence_events": evidence_events.duplicate(true),
		"map_annotations": map_annotations.duplicate(true),
		"evidence_sequence": evidence_sequence,
		"annotation_sequence": annotation_sequence,
		"elapsed_seconds": shift_seconds(),
		"exposure": exposure_count,
		"quarantines": quarantine_count
	}
