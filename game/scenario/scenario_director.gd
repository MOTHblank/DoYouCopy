class_name ScenarioDirector
extends Node

signal contact_started(contact: ContactDefinition, number: int, total: int)
signal phase_changed(phase: String)
signal message_emitted(speaker: String, message: String, line_id: String)
signal consequence_emitted(message: String)
signal run_finished(report: String)

const CONTACTS: Array[Resource] = [
	preload("res://content/contacts/contact_01_training.tres"),
	preload("res://content/contacts/contact_02_echo2.tres"),
	preload("res://content/contacts/contact_03_first_fake.tres"),
	preload("res://content/contacts/contact_04_consequence.tres")
]

var run_state: ScenarioState
var radio: RadioConsole
var phase: String = "WAITING"
var index: int = -1
var contact: ContactDefinition
var auth_requested: bool = false

func setup(state_node: ScenarioState, radio_node: RadioConsole) -> void:
	run_state = state_node
	radio = radio_node
	radio.signal_acquired.connect(_on_signal_acquired)
	radio.signal_lost.connect(_on_signal_lost)

func begin_run() -> void:
	run_state.reset_run()
	index = -1
	phase = "WAITING"
	advance()

func advance() -> void:
	if phase != "WAITING" and phase != "RESOLVING":
		return
	index += 1
	while index < CONTACTS.size():
		var candidate: ContactDefinition = CONTACTS[index] as ContactDefinition
		if not run_state.can_access(candidate.channel):
			run_state.append_log("[STATION] %s blocked. No contact." % String(candidate.channel))
			index += 1
			continue
		var eligible := true
		for flag in candidate.required_flags:
			if not run_state.has_flag(flag):
				eligible = false
		for flag in candidate.excluded_flags:
			if run_state.has_flag(flag):
				eligible = false
		if eligible:
			break
		index += 1
	if index >= CONTACTS.size():
		_finish_slice()
		return
	contact = CONTACTS[index] as ContactDefinition
	auth_requested = false
	_set_phase("TUNING")
	contact_started.emit(contact, index + 1, CONTACTS.size())
	run_state.append_log("[STATION] Carrier expected on %.2f MHz." % contact.frequency)
	# An already-aligned dial may acquire immediately; phase must be TUNING first.
	radio.configure(contact, false)

func _on_signal_acquired(_frequency: float) -> void:
	if phase != "TUNING" or contact == null:
		return
	_set_phase("RECEIVING")
	var prepared := true
	if contact.actual_source == &"GHOST":
		for fact in contact.required_ghost_knowledge:
			if not run_state.knows(fact):
				prepared = false
				break
	var spoken := contact.opening_for(run_state.flags)
	if not prepared:
		spoken = "Unidentified carrier. [The identifier fails to resolve.]"
	_emit_message(String(contact.claimed_callsign) if prepared else "UNIDENTIFIED", spoken, "%s_OPEN" % String(contact.id))
	# Information only becomes available to the GHOST after this transmission was heard.
	for fact in contact.learned_on_receive:
		run_state.learn(fact, "%s:open_carrier" % String(contact.id))
	_set_phase("VERIFYING")

func _on_signal_lost() -> void:
	if phase != "VERIFYING":
		return
	run_state.append_log("[STATION] Carrier lost. Retune before transmitting.")
	_set_phase("TUNING")

func request_repeat() -> void:
	if phase != "VERIFYING":
		return
	var line := contact.repeat_line if not contact.repeat_line.is_empty() else contact.opening_for(run_state.flags)
	_emit_message(String(contact.claimed_callsign), line, "%s_REPEAT" % String(contact.id))

func request_authentication() -> void:
	if phase != "VERIFYING" or auth_requested:
		return
	auth_requested = true
	run_state.append_log("[OPERATOR] Authentication requested: %s." % String(contact.challenge_id))
	var answer := contact.authentication_line
	if contact.actual_source == &"GHOST" and not String(contact.auth_requires_knowledge).is_empty():
		if not run_state.knows(String(contact.auth_requires_knowledge)):
			answer = contact.fallback_authentication_line
	_emit_message(String(contact.claimed_callsign), answer, "%s_AUTH" % String(contact.id))
	if contact.actual_source != &"GHOST":
		for fact in contact.learned_on_authentication:
			run_state.learn(fact, "%s:open_authentication" % String(contact.id))

func decide(action: StringName) -> void:
	if phase != "VERIFYING" or contact == null:
		return
	if not contact.possible_actions.has(String(action)):
		return
	_set_phase("DECIDING")
	run_state.decisions[String(contact.id)] = String(action)
	run_state.append_log("[OPERATOR] %s issued to %s." % [String(action), String(contact.claimed_callsign)])
	var effects: Variant = contact.action_outcomes.get(String(action), PackedStringArray())
	if effects is PackedStringArray or effects is Array:
		for effect in effects:
			run_state.apply_effect(String(effect))
	_set_phase("RESOLVING")
	var consequence := contact.consequence_for(action)
	consequence_emitted.emit(consequence)
	run_state.append_log("[STATION] " + consequence)

func quarantine_current() -> void:
	if phase != "VERIFYING" or contact == null:
		return
	if not run_state.has_flag("quarantine_available"):
		return
	if not run_state.can_access(contact.channel):
		return
	_set_phase("DECIDING")
	run_state.quarantined_channels[String(contact.channel)] = true
	run_state.decisions[String(contact.id)] = "QUARANTINE"
	run_state.flags["channel_sacrificed"] = true
	run_state.append_log("[OPERATOR] Permanently blocked %s." % String(contact.channel))
	_set_phase("RESOLVING")
	consequence_emitted.emit("Carrier terminated. The channel is permanently unavailable.")

func _emit_message(speaker: String, message: String, line_id: String) -> void:
	run_state.append_log("[%s] %s" % [speaker, message])
	message_emitted.emit(speaker, message, line_id)

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_changed.emit(phase)

func _finish_slice() -> void:
	contact = null
	_set_phase("COMPLETE")
	var outcome := "The field team remains reachable."
	if run_state.has_flag("impostor_followed"):
		outcome = "ECHO-2 is missing after an unauthorized instruction."
	elif run_state.has_flag("impostor_contained"):
		outcome = "The unauthorized call was held. Both field routes remain under observation."
	var report := "END OF PROTOTYPE SHIFT\n\n%s\n\nGHOST evidence intercepted: %d facts.\nOperator decisions: %d.\n\nThe authored eight-contact campaign and voice assets remain future work." % [
		outcome, run_state.ghost_knowledge.size(), run_state.decisions.size()
	]
	run_finished.emit(report)
