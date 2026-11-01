class_name ScenarioDirector
extends Node

signal contact_started(contact: ContactDefinition, number: int, total: int)
signal phase_changed(phase: String)
signal message_emitted(speaker: String, message: String, line_id: String)
signal consequence_emitted(message: String)
signal run_finished(report: String)
signal opening_transcript_complete

const CONTACTS: Array[Resource] = [
	preload("res://content/contacts/contact_01_training.tres"),
	preload("res://content/contacts/contact_02_echo2.tres"),
	preload("res://content/contacts/contact_03_first_fake.tres"),
	preload("res://content/contacts/contact_04_consequence.tres"),
	preload("res://content/contacts/contact_05_duplicate.tres"),
	preload("res://content/contacts/contact_06_old_auth.tres"),
	preload("res://content/contacts/contact_07_learned_copy.tres"),
	preload("res://content/contacts/contact_08_final.tres")
]

var run_state: ScenarioState
var radio: RadioConsole
var phase: String = "WAITING"
var index: int = -1
var contact: ContactDefinition
var auth_requested: bool = false
## False for test harnesses and transcript-only integration.
## Main enables it and signals when every available voiced line is finished.
var opening_audio_gate := false

func setup(state_node: ScenarioState, radio_node: RadioConsole) -> void:
	run_state = state_node
	radio = radio_node
	radio.signal_acquired.connect(_on_signal_acquired)
	radio.signal_lost.connect(_on_signal_lost)

func begin_run(resume_index: int = -1) -> void:
	contact = null
	auth_requested = false
	if resume_index < 0 or resume_index > CONTACTS.size():
		run_state.reset_run()
		index = -1
	else:
		index = resume_index - 1
		run_state.append_log("[STATION] Previous shift checkpoint restored.")
	_set_phase("WAITING")
	advance()

func advance() -> void:
	if phase != "WAITING" and phase != "RESOLVING":
		return
	index += 1
	while index < CONTACTS.size():
		var candidate := CONTACTS[index] as ContactDefinition
		if not run_state.can_access(candidate.channel):
			run_state.append_log("[STATION] %s BLOCKED. %s cannot connect." % [
				String(candidate.channel), String(candidate.id)
			])
			index += 1
			continue
		if _eligible(candidate):
			break
		index += 1
	if index >= CONTACTS.size():
		_finish_campaign()
		return
	contact = CONTACTS[index] as ContactDefinition
	auth_requested = false
	# Set phase *before* radio configuration. An already-aligned dial can lock
	# in the same stack frame, and that acquisition must not be discarded.
	_set_phase("TUNING")
	contact_started.emit(contact, index + 1, CONTACTS.size())
	run_state.append_log("[STATION] Incoming carrier near %.2f MHz." % contact.frequency)
	if contact.terminal_anomaly and run_state.knows("station_terminal_sync"):
		run_state.flags["terminal_unreliable"] = true
		run_state.append_log("[STATION] Data sync completed. Terminal location index refreshed.")
	radio.configure(contact, false)

func _eligible(candidate: ContactDefinition) -> bool:
	for flag in candidate.required_flags:
		if not run_state.has_flag(flag):
			return false
	for flag in candidate.excluded_flags:
		if run_state.has_flag(flag):
			return false
	return true

func _ghost_prepared(required: PackedStringArray) -> bool:
	for fact in required:
		if not run_state.knows(fact):
			return false
	return true

func _on_signal_acquired(_frequency: float) -> void:
	if phase != "TUNING" or contact == null:
		return
	_set_phase("RECEIVING")
	var prepared := contact.actual_source != &"GHOST" or _ghost_prepared(contact.required_ghost_knowledge)
	var spoken := contact.opening_for(run_state.flags)
	var line_id := contact.opening_id(run_state.flags)
	if not prepared:
		spoken = "Unidentified carrier. [Identifier fails to resolve.]"
		line_id = "%s_OPEN_UNIDENTIFIED" % String(contact.id)
	elif contact.actual_source == &"GHOST" and not String(contact.opening_requires_knowledge).is_empty():
		if not run_state.knows(String(contact.opening_requires_knowledge)):
			spoken = contact.fallback_opening
			line_id = "%s_OPEN_FALLBACK" % String(contact.id)
	_emit_message(String(contact.claimed_callsign) if prepared else "UNIDENTIFIED", spoken, line_id)
	# A second caller on the monitor is a separate intercept, never an extra
	# learned identity. It is available only when the GHOST knows the voice.
	if not contact.parallel_line.is_empty() and _ghost_prepared(contact.parallel_requires_knowledge):
		var parallel := "[%.2f MHz] %s" % [contact.parallel_frequency, contact.parallel_line]
		_emit_message(String(contact.parallel_callsign), parallel, "%s_PARALLEL" % String(contact.id))
	for fact in contact.learned_on_receive:
		run_state.learn(fact, "%s:open_carrier" % String(contact.id))
	if opening_audio_gate:
		opening_transcript_complete.emit()
	else:
		_set_phase("VERIFYING")

func opening_voice_finished() -> void:
	if phase == "RECEIVING":
		_set_phase("VERIFYING")

func _on_signal_lost() -> void:
	if phase != "VERIFYING" and phase != "RECEIVING":
		return
	run_state.append_log("[STATION] Signal lost. Retune before transmitting.")
	_set_phase("TUNING")

func request_repeat() -> void:
	if phase != "VERIFYING" or contact == null:
		return
	var line := contact.repeat_line if not contact.repeat_line.is_empty() else contact.opening_for(run_state.flags)
	var line_id := "%s_REPEAT" % String(contact.id)
	if contact.actual_source == &"GHOST":
		if not _ghost_prepared(contact.required_ghost_knowledge):
			line = "[Static.] The claimed identifier remains unreadable."
			line_id = "%s_OPEN_UNIDENTIFIED" % String(contact.id)
		elif not String(contact.opening_requires_knowledge).is_empty():
			if not run_state.knows(String(contact.opening_requires_knowledge)):
				line = contact.fallback_opening
				line_id = "%s_OPEN_FALLBACK" % String(contact.id)
	_emit_message(String(contact.claimed_callsign), line, line_id)

func request_authentication() -> void:
	if phase != "VERIFYING" or auth_requested or contact == null:
		return
	auth_requested = true
	run_state.append_log("[OPERATOR] Challenge %s broadcast." % String(contact.challenge_id))
	var answer := contact.authentication_line
	var auth_line_id := "%s_AUTH" % String(contact.id)
	if contact.actual_source == &"GHOST":
		var authorized := _ghost_prepared(contact.required_ghost_knowledge)
		if not String(contact.auth_requires_knowledge).is_empty():
			authorized = authorized and run_state.knows(String(contact.auth_requires_knowledge))
		if not authorized:
			answer = contact.fallback_authentication_line
			auth_line_id = "%s_AUTH_FALLBACK" % String(contact.id)
	_emit_message(String(contact.claimed_callsign), answer, auth_line_id)
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
	run_state.append_log("[OPERATOR] %s sent to %s." % [String(action), String(contact.claimed_callsign)])
	var effects: Variant = contact.action_outcomes.get(String(action), PackedStringArray())
	if effects is PackedStringArray or effects is Array:
		for effect in effects:
			run_state.apply_effect(String(effect))
	_resolve_contact(contact.consequence_for(action))

func quarantine_current() -> void:
	if phase != "VERIFYING" or contact == null:
		return
	if not run_state.has_flag("quarantine_available"):
		return
	if not run_state.quarantine_channel(contact.channel):
		return
	_set_phase("DECIDING")
	run_state.decisions[String(contact.id)] = "QUARANTINE"
	for effect in contact.quarantine_outcomes:
		run_state.apply_effect(effect)
	run_state.append_log("[OPERATOR] Permanently sealed %s." % String(contact.channel))
	_resolve_contact(contact.quarantine_consequence)

func _resolve_contact(consequence: String) -> void:
	if contact.unlock_quarantine_after:
		run_state.flags["quarantine_available"] = true
		run_state.append_log("[STATION] Quarantine guard released. Irreversible channel lock is available.")
	_set_phase("RESOLVING")
	consequence_emitted.emit(consequence)
	run_state.append_log("[STATION] " + consequence)
	if not run_state.save_checkpoint(index + 1):
		push_warning("Campaign checkpoint could not be saved after %s." % String(contact.id))

func _emit_message(speaker: String, message: String, line_id: String) -> void:
	run_state.append_log("[%s] %s" % [speaker, message])
	message_emitted.emit(speaker, message, line_id)

func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_changed.emit(phase)

func _finish_campaign() -> void:
	contact = null
	_set_phase("COMPLETE")
	var family := run_state.ending_family()
	var detail := ""
	match family:
		"CONTAINED":
			detail = "The copied route is silent. Both agents remain available. The last verified reports agree."
		"ISOLATED":
			detail = "The copied route is contained, but at least one legitimate field agent cannot be reached."
		_:
			detail = "A compromised transmission path remains open. The shift ends without reliable isolation."
	var sealed_channels := PackedStringArray()
	for channel in run_state.quarantined_channels.keys():
		sealed_channels.append(str(channel))
	var blocked := ", ".join(sealed_channels)
	if blocked.is_empty():
		blocked = "none"
	var report := "SHIFT CLOSED / %s\n\n%s\n\nChannels sealed: %s\nAgents: Actual=%s | Two=%s\nGHOST learned facts: %d\nExposure incidents: %d\nConfirmed operator decisions: %d\n\nRestart to discover another consequence." % [
		family, detail, blocked,
		run_state.agent_status["ECHO-ACTUAL"], run_state.agent_status["ECHO-2"],
		run_state.ghost_knowledge.size(), run_state.exposure_count, run_state.decisions.size()
	]
	run_state.append_log("[ENDING] " + family)
	run_state.clear_checkpoint()
	run_finished.emit(report)
