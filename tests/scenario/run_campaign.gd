extends SceneTree

## Run headlessly:
## godot --headless --path . --script res://tests/scenario/run_campaign.gd
var errors: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		errors.append(label)
		printerr("FAIL: " + label)

func _tune(director: ScenarioDirector, radio: RadioConsole) -> void:
	_check(director.contact != null, "Expected a contact to tune")
	if director.contact == null:
		return
	radio.set_frequency(director.contact.frequency)
	radio.set_cleanup(director.contact.cleanup_target)
	_check(director.phase == "VERIFYING", "Unable to acquire %s" % String(director.contact.id))

func _logged(state: ScenarioState, needle: String) -> bool:
	for line in state.communication_log:
		if line.contains(needle):
			return true
	return false

func _run() -> void:
	var state := ScenarioState.new()
	var radio := RadioConsole.new()
	var director := ScenarioDirector.new()
	root.add_child(state)
	root.add_child(radio)
	root.add_child(director)
	director.setup(state, radio)

	var unique_ids: Dictionary = {}
	for candidate_resource in ScenarioDirector.CONTACTS:
		var candidate: ContactDefinition = candidate_resource as ContactDefinition
		_check(candidate != null, "Contact resource loads")
		if candidate == null:
			continue
		_check(not unique_ids.has(String(candidate.id)), "Unique contact ID " + String(candidate.id))
		unique_ids[String(candidate.id)] = true
		_check(candidate.frequency >= 100.0 and candidate.frequency <= 110.0, "Carrier within receiver range")
		_check(candidate.channel != &"", "Contact has a channel")
		_check(candidate.challenge_id != &"", "Contact has an auth challenge")
		_check(candidate.possible_actions.size() > 0, "Contact offers operational choices")
	_check(unique_ids.size() == 8, "Eight major contacts authored")

	director.begin_run()
	_check(String(director.contact.id) == "C01", "Start at training")
	_check(not state.knows("delta4_answer"), "GHOST does not begin with authentication")
	_tune(director, radio)
	director.request_authentication()
	_check(state.knows("delta4_answer"), "C01 challenge can be intercepted")
	_check(state.knows("actual_procedure"), "GHOST learned Actual's speaking procedure")
	director.decide(&"PROCEED")
	director.advance()

	_check(String(director.contact.id) == "C02", "Reach ECHO-2")
	_tune(director, radio)
	director.request_authentication()
	_check(state.knows("tide2_answer"), "C02 challenge can be intercepted")
	director.decide(&"HOLD")
	director.advance()

	_check(String(director.contact.id) == "C03", "Reach first discrepancy")
	_tune(director, radio)
	director.request_authentication()
	_check(_logged(state, "Response: river"), "First impersonation uses overheard retired answer")
	_check(not state.has_flag("quarantine_available"), "Quarantine locked during early contacts")
	director.quarantine_current()
	_check(state.quarantine_count == 0, "Early quarantine cannot be used")
	director.decide(&"HOLD")
	director.advance()

	_check(String(director.contact.id) == "C04", "Consequences reach follow-up")
	_tune(director, radio)
	_check(_logged(state, "Good hold"), "C04 references C03 hold")
	director.request_authentication()
	_check(state.knows("bravo6_answer"), "Current auth learned only when overheard")
	director.decide(&"HOLD")
	director.advance()

	_check(String(director.contact.id) == "C05", "Duplicate voice contact reachable")
	_tune(director, radio)
	_check(_logged(state, "[101.85 MHz]"), "Secondary GHOST carrier intercepted")
	director.decide(&"HOLD")
	director.advance()

	_check(String(director.contact.id) == "C06", "Old authentication contact reachable")
	_tune(director, radio)
	director.request_authentication()
	_check(_logged(state, "DELTA-4. Keyboard"), "Old answer used only after it was learned")
	director.decide(&"HOLD")
	_check(state.has_flag("quarantine_available"), "Quarantine unlocked after C06")
	director.advance()

	_check(String(director.contact.id) == "C07", "Learned copy reachable")
	_tune(director, radio)
	director.request_authentication()
	_check(_logged(state, "BRAVO-6. Shadow. Operator"), "Learned copy uses current auth after intercepted answer")
	director.quarantine_current()
	_check(state.quarantine_count == 1, "Quarantine is counted")
	_check(not state.can_access(&"A-ALT"), "Quarantined alternate channel cannot be used")
	director.advance()

	_check(String(director.contact.id) == "C08", "Final remains reachable after alternate quarantine")
	_check(state.has_flag("terminal_unreliable"), "Machine intrusion triggered by learned protocol")
	_check(state.displayed_location("ECHO-ACTUAL") != str(state.agent_locations["ECHO-ACTUAL"]), "Terminal conflict does not overwrite true map")
	_tune(director, radio)
	director.decide(&"HOLD")
	director.advance()
	_check(director.phase == "COMPLETE", "Complete the eight-contact shift")
	_check(state.ending_family() == "CONTAINED", "Containment ending reachable")

	state.reset_run()
	_check(state.quarantine_channel(&"A-ALT"), "Alternate channel can be sealed")
	_check(not state.quarantine_channel(&"A-ALT"), "Repeated quarantine is rejected")
	state.decisions["C08"] = "HOLD"
	_check(state.ending_family() == "CONTAINED", "Contained family uses verified safety")
	state.agent_status["ECHO-2"] = "MISSING"
	_check(state.ending_family() == "ISOLATED", "Agent lost yields isolated ending")
	state.decisions["C08"] = "PROCEED"
	_check(state.ending_family() == "OPEN_LINE", "Unsafe final clearance reopens line")

	# A fresh run that never requested early authentication must not produce
	# those answers in later impersonations.
	director.begin_run()
	for n in range(5):
		_tune(director, radio)
		if n == 2:
			director.request_authentication()
			_check(_logged(state, "I... can't read that"), "No TIDE-2 answer without prior interception")
		director.decide(&"HOLD")
		director.advance()
	_check(String(director.contact.id) == "C06", "Reach old-auth branch without challenges")
	_tune(director, radio)
	director.request_authentication()
	_check(_logged(state, "Authentication readback lost"), "GHOST cannot invent DELTA-4 response")
	director.decide(&"HOLD")
	director.advance()
	_tune(director, radio)
	director.request_authentication()
	_check(_logged(state, "I cannot provide the current answer"), "GHOST cannot invent BRAVO-6 response")

	if errors.is_empty():
		print("PASS: DoYouCopy campaign resources, deterministic progression, GHOST learning, quarantine and endings")
		quit(0)
	else:
		printerr("%d scenario failures:\n%s" % [errors.size(), "\n".join(errors)])
		quit(1)
