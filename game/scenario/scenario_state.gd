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
	var sealed := quarantined_channels.has("A-ALT")
	var disciplined := (
		decisions.get("C07", "") == "HOLD"
		and decisions.get("C08", "") == "REROUTE"
	)
	var ghost_contained := sealed or disciplined
	if decisions.get("C08", "") == "PROCEED":
		# The final automatic location clearance reopens a route despite
		# incompatible evidence, even after an earlier seal.
		return "OPEN_LINE"
	if not ghost_contained:
		return "OPEN_LINE"
	var agent_lost := (
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
		"flags": flags.duplicate(true),
		"decisions": decisions.duplicate(true),
		"exposure": exposure_count,
		"quarantines": quarantine_count
	}
