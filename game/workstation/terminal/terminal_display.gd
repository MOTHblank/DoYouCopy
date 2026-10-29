class_name TerminalDisplay
extends Control

var current_contact: ContactDefinition
var run_state: ScenarioState
var radio: RadioConsole
var is_acquired: bool = false

func set_data(contact: ContactDefinition, state_node: ScenarioState, radio_node: RadioConsole, acquired: bool) -> void:
	current_contact = contact
	run_state = state_node
	radio = radio_node
	is_acquired = acquired
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071a16"))
	var font := ThemeDB.fallback_font
	var green := Color("#8cc6a2")
	var grey := Color("#5e9387")
	draw_string(font, Vector2(22, 34), "ECHO / FIELD TERMINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, green)
	draw_line(Vector2(20, 45), Vector2(size.x - 20, 45), grey, 1.5)
	if current_contact == null or run_state == null or radio == null:
		return
	var status := "SEARCHING" if not is_acquired else "RECEIVING"
	var lines := [
		"RX: %.2f MHz   %s" % [radio.frequency, status],
		"CLAIMED: %s" % (String(current_contact.claimed_callsign) if is_acquired else "UNCONFIRMED"),
		"VERIFIED A: %s" % str(run_state.agent_locations["ECHO-ACTUAL"]),
		"VERIFIED 2: %s" % str(run_state.agent_locations["ECHO-2"]),
		"STATUS A: %s" % str(run_state.agent_status["ECHO-ACTUAL"]),
		"STATUS 2: %s" % str(run_state.agent_status["ECHO-2"]),
		"JOB: %s" % current_contact.objective.substr(0, 48)
	]
	for i in range(lines.size()):
		draw_string(font, Vector2(23, 79 + 33 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, green if i < 2 else grey)
