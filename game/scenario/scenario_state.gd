class_name ScenarioState
extends Node

## The run's only persistent state. No UI, timers or audio.
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

func append_log(line: String) -> void:
	communication_log.append(line)
	if communication_log.size() > 28:
		communication_log.pop_front()

## Whitelisted verbs are intentionally small. Resource files author consequences;
## this parser owns their mutation semantics.
func apply_effect(effect: String) -> void:
	var parts := effect.split(":", false)
	if parts.size() < 2:
		push_warning("Invalid scenario effect: " + effect)
		return
	match parts[0]:
		"flag":
			flags[parts[1]] = true
		"location":
			if parts.size() == 3 and agent_locations.has(parts[1]):
				agent_locations[parts[1]] = parts[2]
		"status":
			if parts.size() == 3 and agent_status.has(parts[1]):
				agent_status[parts[1]] = parts[2]
		"trust":
			if parts.size() == 3 and trust.has(parts[1]) and parts[2].is_valid_int():
				trust[parts[1]] += int(parts[2])
		"exposure":
			if parts[1].is_valid_int():
				exposure_count += int(parts[1])
		_:
			push_warning("Unknown scenario effect: " + effect)

func snapshot() -> Dictionary:
	return {
		"locations": agent_locations.duplicate(true),
		"status": agent_status.duplicate(true),
		"trust": trust.duplicate(true),
		"channels": quarantined_channels.duplicate(true),
		"ghost_knowledge": ghost_knowledge.duplicate(true),
		"flags": flags.duplicate(true),
		"decisions": decisions.duplicate(true),
		"exposure": exposure_count
	}
