class_name ContactDefinition
extends Resource

## Immutable authored carrier data. ScenarioDirector executes the rules.
@export var id: StringName = &""
@export var frequency: float = 101.30
@export var tolerance: float = 0.42
@export_range(0.0, 1.0) var cleanup_target: float = 0.76
@export var channel: StringName = &""
@export var claimed_callsign: StringName = &""
@export var actual_source: StringName = &""

@export_group("Transmission")
@export_multiline var opening_line: String = ""
@export_multiline var fallback_opening: String = ""
@export var opening_requires_knowledge: StringName = &""
@export_multiline var repeat_line: String = ""
@export var parallel_callsign: StringName = &""
@export var parallel_frequency: float = 0.0
@export_multiline var parallel_line: String = ""
@export var parallel_requires_knowledge: PackedStringArray = PackedStringArray()

@export_group("Evidence")
@export var last_reported_location: String = ""
@export var objective: String = ""
@export var challenge_id: StringName = &""
@export var authentication_line: String = ""
@export var auth_requires_knowledge: StringName = &""
@export var fallback_authentication_line: String = ""

@export_group("Progression")
@export var possible_actions: PackedStringArray = PackedStringArray(["HOLD", "PROCEED"])
@export var required_flags: PackedStringArray = PackedStringArray()
@export var excluded_flags: PackedStringArray = PackedStringArray()
@export var required_ghost_knowledge: PackedStringArray = PackedStringArray()
@export var learned_on_receive: PackedStringArray = PackedStringArray()
@export var learned_on_authentication: PackedStringArray = PackedStringArray()
@export var unlock_quarantine_after: bool = false
@export var terminal_anomaly: bool = false
@export var action_outcomes: Dictionary = {}
@export var branch_openings: Dictionary = {}
@export var consequence_text: Dictionary = {}
@export var quarantine_outcomes: PackedStringArray = PackedStringArray()
@export_multiline var quarantine_consequence: String = "Channel sealed. No further contact permitted."

func opening_for(flags: Dictionary) -> String:
	for flag in branch_openings.keys():
		if flags.has(str(flag)):
			return str(branch_openings[flag])
	return opening_line

func opening_id(flags: Dictionary) -> String:
	for flag in branch_openings.keys():
		if flags.has(str(flag)):
			return "%s_OPEN_%s" % [String(id), str(flag)]
	return "%s_OPEN" % String(id)

func consequence_for(action: StringName) -> String:
	return str(consequence_text.get(String(action), "Instruction transmitted. Awaiting field confirmation."))
