class_name WorkstationHUD
extends CanvasLayer

## Paper content is authorable independently of presentation and GHOST knowledge.
const AUTH_PAPERWORK: AuthenticationPaperwork = preload("res://content/authentication/paperwork.tres")

signal action_transmitted(action: String)
signal opening_skip_requested

## Readable operator UI complements the in-world screens; it never judges identity.
var director: ScenarioDirector
var radio: RadioConsole
var run_state: ScenarioState
var frequency_input: SpinBox
var cleanup_input: HSlider
var squelch_input: HSlider
var bandwidth_input: HSlider
var meter: ProgressBar
var status_label: Label
var phase_label: Label
var contact_label: Label
var objective_label: Label
var latest_label: Label
var transcript: RichTextLabel
var full_subtitles: CheckBox
var transcript_entries: Array[Dictionary] = []
var evidence_text: RichTextLabel
var tabs: OptionButton
var action_buttons: Dictionary = {}
var repeat_button: Button
var auth_button: Button
var next_button: Button
var quarantine_button: Button
var transmit_button: Button
var selected_action: String = ""
var quarantine_confirmation: ConfirmationDialog
var active_contact: ContactDefinition
var last_message: String = "Waiting for a carrier."
var result_message: String = ""
var report_text: String = ""
var complete: bool = false
var total_contacts: int = 0

func _ready() -> void:
	_build_ui()

func bind(director_node: ScenarioDirector, radio_node: RadioConsole, state_node: ScenarioState) -> void:
	director = director_node
	radio = radio_node
	run_state = state_node
	director.contact_started.connect(_contact_started)
	director.phase_changed.connect(_phase_changed)
	director.message_emitted.connect(_message_emitted)
	director.transcript_refined.connect(_transcript_refined)
	director.consequence_emitted.connect(_consequence_emitted)
	director.run_finished.connect(_run_finished)
	radio.tuning_changed.connect(_frequency_changed)
	radio.quality_changed.connect(_quality_changed)
	frequency_input.value = radio.frequency
	cleanup_input.value = radio.cleanup
	squelch_input.value = radio.squelch
	bandwidth_input.value = radio.bandwidth
	_refresh()

func _panel(root: Control, left: float, top: float, right: float, bottom: float, anchor_left_value: float, anchor_right_value: float, anchor_top_value: float, anchor_bottom_value: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = anchor_left_value
	panel.anchor_right = anchor_right_value
	panel.anchor_top = anchor_top_value
	panel.anchor_bottom = anchor_bottom_value
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.042, 0.075, 0.078, 0.95)
	style.border_color = Color("#365f5b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	return column

func _text(parent: Node, value: String, font_size: int = 16, color: String = "#c8d8d1", wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 37.0
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	var banner := PanelContainer.new()
	banner.anchor_right = 1.0
	banner.offset_bottom = 56
	canvas.add_child(banner)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color("#132528")
	banner.add_theme_stylebox_override("panel", banner_style)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	banner.add_child(header)
	_text(header, "   ECHO / COMMUNICATIONS", 21, "#e7cf9b", false)
	phase_label = _text(header, "WAITING", 17, "#a9dbcd", false)
	_text(header, "RMB: LOOK  |  LMB: OPERATE  |  WHEEL: KNOB  |  SPACE: TRANSMIT", 12, "#a1b9b3", false)

	var left := _panel(canvas, 14, 72, 356, -14, 0, 0, 0, 1)
	left.add_theme_constant_override("separation", 6)
	_text(left, "RECEIVER  /  01", 22, "#e7cf9b")
	contact_label = _text(left, "No contact", 16)
	_text(left, "FREQUENCY / MHz", 14, "#9cc1b4")
	frequency_input = SpinBox.new()
	frequency_input.min_value = 100.0
	frequency_input.max_value = 110.0
	frequency_input.step = 0.05
	frequency_input.value = 101.0
	frequency_input.suffix = " MHz"
	frequency_input.custom_minimum_size.y = 42
	left.add_child(frequency_input)
	frequency_input.value_changed.connect(func(value: float) -> void:
		if radio != null:
			radio.set_frequency(value)
	)
	_text(left, "SIGNAL CLEANUP", 14, "#9cc1b4")
	cleanup_input = HSlider.new()
	cleanup_input.min_value = 0.0
	cleanup_input.max_value = 1.0
	cleanup_input.step = 0.01
	cleanup_input.value = 0.40
	cleanup_input.custom_minimum_size.y = 27
	left.add_child(cleanup_input)
	cleanup_input.value_changed.connect(func(value: float) -> void:
		if radio != null:
			radio.set_cleanup(value)
	)
	_text(left, "SQUELCH / STATIC GATE", 13, "#9cc1b4")
	squelch_input = HSlider.new()
	squelch_input.min_value = 0.0
	squelch_input.max_value = 1.0
	squelch_input.step = 0.01
	squelch_input.value = 0.22
	squelch_input.custom_minimum_size.y = 24
	squelch_input.tooltip_text = "Suppress static; excessive squelch mutes weak carriers."
	left.add_child(squelch_input)
	squelch_input.value_changed.connect(func(value: float) -> void:
		if radio != null:
			radio.set_squelch(value)
	)
	_text(left, "BANDWIDTH / FILTER WIDTH", 13, "#9cc1b4")
	bandwidth_input = HSlider.new()
	bandwidth_input.min_value = 0.0
	bandwidth_input.max_value = 1.0
	bandwidth_input.step = 0.01
	bandwidth_input.value = 0.55
	bandwidth_input.custom_minimum_size.y = 24
	bandwidth_input.tooltip_text = "Narrow rejects interference; wide retains voice detail."
	left.add_child(bandwidth_input)
	bandwidth_input.value_changed.connect(func(value: float) -> void:
		if radio != null:
			radio.set_bandwidth(value)
	)
	meter = ProgressBar.new()
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.show_percentage = false
	meter.custom_minimum_size.y = 13
	left.add_child(meter)
	status_label = _text(left, "STATIC / NO CARRIER", 16, "#e7cf9b")
	_text(left, "FIELD INSTRUCTION", 14, "#9cc1b4")
	objective_label = _text(left, "Tune to the assigned frequency to start.", 15)
	repeat_button = _button(left, "R / REQUEST REPEAT", func() -> void: director.request_repeat())
	auth_button = _button(left, "A / AUTHENTICATE", func() -> void: director.request_authentication())
	var action_row := GridContainer.new()
	action_row.columns = 2
	left.add_child(action_row)
	for action in ["HOLD", "PROCEED", "REROUTE"]:
		var selected := StringName(action)
		var button := _button(action_row, action, func() -> void: _choose_action(String(selected)))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_buttons[action] = button
	transmit_button = _button(left, "SPACE / SELECT AN INSTRUCTION", func() -> void: _transmit_action())
	quarantine_button = _button(left, "CHANNEL QUARANTINE / LOCKED", func() -> void: _request_quarantine_confirmation())
	_text(left, "Quarantine is irreversible; its guard unlocks later.", 12, "#b4a18b")
	next_button = _button(left, "CONTINUE / NEXT CARRIER", func() -> void:
		if complete:
			director.begin_run()
		else:
			director.advance()
	)
	next_button.disabled = true

	quarantine_confirmation = ConfirmationDialog.new()
	quarantine_confirmation.title = "Seal radio channel?"
	quarantine_confirmation.ok_button_text = "SEAL PERMANENTLY"
	quarantine_confirmation.confirmed.connect(func() -> void:
		if director != null:
			director.quarantine_current()
			if director.phase == "RESOLVING":
				action_transmitted.emit("quarantine")
	)
	add_child(quarantine_confirmation)

	var right := _panel(canvas, -354, 72, -14, -14, 1, 1, 0, 1)
	_text(right, "REFERENCE DESK", 22, "#e7cf9b")
	tabs = OptionButton.new()
	tabs.add_item("TERMINAL")
	tabs.add_item("AUTH PAPER")
	tabs.add_item("FIELD MAP")
	tabs.add_item("COMMS LOG")
	right.add_child(tabs)
	tabs.item_selected.connect(func(_index: int) -> void: _update_evidence())
	full_subtitles = CheckBox.new()
	full_subtitles.text = "FULL VOICE SUBTITLES / ACCESSIBILITY"
	full_subtitles.tooltip_text = "Show complete authored speech even when reception is weak."
	right.add_child(full_subtitles)
	full_subtitles.toggled.connect(func(_enabled: bool) -> void:
		_rebuild_transcript()
		_update_evidence()
	)
	evidence_text = RichTextLabel.new()
	evidence_text.fit_content = false
	evidence_text.scroll_active = true
	evidence_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_text.add_theme_color_override("default_color", Color("#c1d9c9"))
	evidence_text.add_theme_font_size_override("normal_font_size", 17)
	right.add_child(evidence_text)
	_text(right, "Terminal data is not an identity verdict. Compare independent sources.", 13, "#9bb7aa")

	var bottom := _panel(canvas, 18, -238, -18, -14, 0.24, 0.76, 1, 1)
	_text(bottom, "RECEIVED TRANSMISSION / OPERATOR LOG", 15, "#e7cf9b")
	latest_label = _text(bottom, "No intelligible transmission.", 18, "#d9e5d6")
	transcript = RichTextLabel.new()
	transcript.fit_content = false
	transcript.scroll_active = true
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.add_theme_color_override("default_color", Color("#9ac7b5"))
	bottom.add_child(transcript)

func _contact_started(contact: ContactDefinition, number: int, total: int) -> void:
	complete = false
	report_text = ""
	if number == 1:
		transcript_entries.clear()
		transcript.clear()
		latest_label.text = "No intelligible transmission."
		tabs.select(0)
	total_contacts = total
	active_contact = contact
	last_message = "Search for the active carrier; compare it to the assigned frequency."
	result_message = ""
	selected_action = ""
	contact_label.text = "CONTACT %02d / %02d    SEEKING CARRIER" % [number, total]
	objective_label.text = "Acquire the carrier, then verify the caller against independent records."
	_refresh()
	_update_evidence()

func _phase_changed(_new_phase: String) -> void:
	_refresh()
	_update_evidence()

func _message_emitted(speaker: String, message: String, line_id: String) -> void:
	contact_label.text = "CONTACT %02d / %02d    CLAIM %s" % [director.index + 1, total_contacts, speaker]
	var full := director.full_transcript_for(line_id)
	transcript_entries.append({"speaker": speaker, "line_id": line_id, "received": message, "full": full if not full.is_empty() else message})
	if transcript_entries.size() > 80:
		transcript_entries.pop_front()
	last_message = "%s: %s" % [speaker, full if full_subtitles.button_pressed else message]
	objective_label.text = active_contact.objective if active_contact != null else "Confirm the caller."
	latest_label.text = last_message
	_rebuild_transcript()
	_refresh()
	_update_evidence()

func _transcript_refined(speaker: String, message: String, line_id: String) -> void:
	for n in range(transcript_entries.size() - 1, -1, -1):
		var entry: Dictionary = transcript_entries[n]
		if String(entry["line_id"]) != line_id:
			continue
		entry["received"] = message
		if n == transcript_entries.size() - 1:
			last_message = "%s: %s" % [speaker, String(entry["full"]) if full_subtitles.button_pressed else message]
			latest_label.text = last_message
		break
	_rebuild_transcript()
	_update_evidence()

func _rebuild_transcript() -> void:
	if transcript == null:
		return
	transcript.clear()
	for entry in transcript_entries:
		var caption := String(entry["full"]) if full_subtitles != null and full_subtitles.button_pressed else String(entry["received"])
		var speaker := String(entry["speaker"])
		if speaker.is_empty():
			transcript.append_text("[%s] %s\n" % [String(entry["line_id"]), caption])
		else:
			transcript.append_text("[%s] %s: %s\n" % [String(entry["line_id"]), speaker, caption])
	if not transcript_entries.is_empty() and full_subtitles != null and full_subtitles.button_pressed:
		var last: Dictionary = transcript_entries[-1]
		if not String(last["speaker"]).is_empty():
			latest_label.text = "%s: %s" % [String(last["speaker"]), String(last["full"]) ]

func _consequence_emitted(message: String) -> void:
	result_message = message
	last_message = "FIELD RESULT: " + message
	latest_label.text = last_message
	transcript_entries.append({"speaker": "", "line_id": "RESULT", "received": message, "full": message})
	_rebuild_transcript()
	_refresh()
	_update_evidence()

func _run_finished(report: String) -> void:
	complete = true
	report_text = report
	last_message = report
	latest_label.text = "SHIFT COMPLETE — ENDING REPORT AT RIGHT"
	transcript_entries.append({"speaker": "", "line_id": "SHIFT REPORT", "received": report, "full": report})
	_rebuild_transcript()
	tabs.select(0)
	_refresh()
	_update_evidence()

func _frequency_changed(value: float) -> void:
	if absf(frequency_input.value - value) >= 0.01:
		frequency_input.value = value
	_refresh()

func _quality_changed(value: float) -> void:
	meter.value = value * 100.0
	_refresh()

func _refresh() -> void:
	if radio == null or director == null:
		return
	phase_label.text = "STATE: " + director.phase
	status_label.text = radio.signal_label()
	if complete:
		next_button.text = "RESTART SHIFT"
	elif director.phase == "RESOLVING":
		next_button.text = "CONTINUE / NEXT CARRIER"
	next_button.disabled = not (complete or director.phase == "RESOLVING")
	var active := director.phase == "VERIFYING"
	if director.phase == "RECEIVING":
		status_label.text = "RECEIVING / SPACE SKIPS VOICE"
	repeat_button.disabled = not active
	auth_button.disabled = not active or director.auth_requested
	auth_button.text = "A / AUTHENTICATE" if not director.auth_requested else "AUTH RESPONSE LOGGED"
	for action in action_buttons.keys():
		var allowed := active and active_contact != null and active_contact.possible_actions.has(str(action))
		var button: Button = action_buttons[action]
		button.disabled = not allowed
		button.text = ("> " if selected_action == str(action) else "") + str(action)
	transmit_button.disabled = not active or selected_action.is_empty()
	transmit_button.text = ("SPACE / TRANSMIT " + selected_action) if not selected_action.is_empty() else "SPACE / SELECT AN INSTRUCTION"
	var can_seal := (
		active and active_contact != null
		and run_state.has_flag("quarantine_available")
		and run_state.can_access(active_contact.channel)
		and run_state.quarantine_count < 2
	)
	quarantine_button.disabled = not can_seal
	quarantine_button.text = (
		"SEAL %s / IRREVERSIBLE" % String(active_contact.channel)
		if can_seal else "CHANNEL QUARANTINE / LOCKED"
	)

func _choose_action(action: String) -> void:
	if director == null or director.phase != "VERIFYING" or active_contact == null:
		return
	if not active_contact.possible_actions.has(action):
		return
	selected_action = action
	latest_label.text = "SELECTED: %s. Use MICROPHONE / SPACE to transmit." % action
	_refresh()

func _transmit_action() -> void:
	if director == null or director.phase != "VERIFYING":
		return
	if selected_action.is_empty():
		latest_label.text = "Choose HOLD, PROCEED or REROUTE first."
		return
	var action := selected_action
	director.decide(StringName(action))
	if director.phase == "RESOLVING":
		action_transmitted.emit("microphone")

func adjust_station(control: String, amount: float) -> void:
	if radio == null:
		return
	match control:
		"cleanup":
			radio.set_cleanup(radio.cleanup + amount * 0.015)
			cleanup_input.set_value_no_signal(radio.cleanup)
		"squelch":
			radio.set_squelch(radio.squelch + amount * 0.015)
			squelch_input.set_value_no_signal(radio.squelch)
		"bandwidth":
			radio.set_bandwidth(radio.bandwidth + amount * 0.015)
			bandwidth_input.set_value_no_signal(radio.bandwidth)
		_:
			radio.adjust_frequency(amount)

func _request_quarantine_confirmation() -> void:
	if director == null or director.phase != "VERIFYING" or active_contact == null:
		return
	if not run_state.has_flag("quarantine_available"):
		return
	if not run_state.can_access(active_contact.channel) or run_state.quarantine_count >= 2:
		return
	var channel := String(active_contact.channel)
	var owner := str(ScenarioState.CHANNEL_OWNERS.get(channel, "NONE"))
	quarantine_confirmation.dialog_text = (
		"This permanently blocks %s for the rest of the shift.\n" % channel
		+ "Primary field agent using this channel: %s.\n\n" % owner
		+ "The action cannot be undone. Your next contact may be lost."
	)
	quarantine_confirmation.popup_centered()

func show_station_object(action: String) -> void:
	match action:
		"paper":
			tabs.select(1)
		"terminal":
			tabs.select(0)
		"map":
			tabs.select(2)
		"spectrum", "radio", "frequency":
			frequency_input.grab_focus()
		"cleanup":
			cleanup_input.grab_focus()
		"squelch":
			squelch_input.grab_focus()
		"bandwidth":
			bandwidth_input.grab_focus()
		"repeat":
			if director != null:
				director.request_repeat()
		"authenticate":
			if director != null:
				director.request_authentication()
		"hold":
			_choose_action("HOLD")
		"proceed":
			_choose_action("PROCEED")
		"reroute":
			_choose_action("REROUTE")
		"microphone":
			_transmit_action()
		"quarantine":
			_request_quarantine_confirmation()
	_update_evidence()

func _update_evidence() -> void:
	if evidence_text == null or run_state == null:
		return
	if complete:
		evidence_text.text = report_text
		return
	if active_contact == null:
		evidence_text.text = "Station booting..."
		return
	match tabs.selected:
		0:
			evidence_text.text = "ECHO FIELD TERMINAL\n----------------------------\nRX: %.2f MHz\nCALL CLAIM: %s\n\nLAST VERIFIED:\nACTUAL: %s / %s\nECHO-2: %s / %s\n\nCURRENT OBJECTIVE:\n%s\n\nWARNING: a caller claim is not a verified location." % [
				radio.frequency, String(active_contact.claimed_callsign) if director.phase != "TUNING" else "UNCONFIRMED",
				run_state.displayed_location("ECHO-ACTUAL"), run_state.agent_status["ECHO-ACTUAL"],
				run_state.agent_locations["ECHO-2"], run_state.agent_status["ECHO-2"],
				active_contact.objective]
		1:
			var reference := AUTH_PAPERWORK.reference_for(director.index + 1, run_state.flags)
			evidence_text.text = "PAPER / AUTH CHALLENGES\n----------------------------\n%s\n\nACTIVE CHALLENGE: %s\n\nA matching answer confirms only knowledge, not identity." % [reference, String(active_contact.challenge_id)]
		2:
			evidence_text.text = "FIELD / VERIFIED POSITIONS\n----------------------------\nRELAY -- JUNCTION\n    |        |\nPUMP STATION B -- EAST SERVICE\n\nECHO-ACTUAL: %s\nECHO-2: %s\n\nA reported location is not a verified movement. The map updates from your accepted instructions." % [
				run_state.agent_locations["ECHO-ACTUAL"], run_state.agent_locations["ECHO-2"]]
		3:
			var log_copy := "\n".join(run_state.communication_log)
			if full_subtitles != null and full_subtitles.button_pressed:
				log_copy += "\n\nFULL VOICE SUBTITLES / ACCESSIBILITY\n"
				for entry in transcript_entries:
					if not String(entry["speaker"]).is_empty():
						log_copy += "\n[%s] %s: %s" % [String(entry["line_id"]), String(entry["speaker"]), String(entry["full"])]
			evidence_text.text = log_copy

func _unhandled_input(event: InputEvent) -> void:
	if director == null or not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is SpinBox:
		return
	match event.keycode:
		KEY_R:
			director.request_repeat()
		KEY_A:
			director.request_authentication()
		KEY_1:
			_choose_action("HOLD")
		KEY_2:
			_choose_action("PROCEED")
		KEY_3:
			_choose_action("REROUTE")
		KEY_Q:
			_request_quarantine_confirmation()
		KEY_SPACE:
			if director.phase == "RECEIVING":
				opening_skip_requested.emit()
			else:
				_transmit_action()
		KEY_ENTER:
			if director.phase == "RECEIVING":
				opening_skip_requested.emit()
			elif director.phase == "VERIFYING":
				_transmit_action()
			elif director.phase == "RESOLVING":
				director.advance()
			elif complete:
				director.begin_run()
		KEY_ESCAPE:
			get_viewport().gui_release_focus()
		KEY_UP:
			radio.adjust_frequency(1.0)
		KEY_DOWN:
			radio.adjust_frequency(-1.0)
		_:
			return
	get_viewport().set_input_as_handled()
