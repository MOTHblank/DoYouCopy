class_name TerminalDisplay
extends Control

## The terminal is a scrollable document, not a fixed number of drawn lines.
## Its sync feed is deliberately not an authority on identity or location.
var current_contact: ContactDefinition
var run_state: ScenarioState
var radio: RadioConsole
var is_acquired: bool = false
var document_scroll: ScrollContainer
var content_labels: Dictionary = {}

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#071a16")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 7)
	margin.add_child(outer)
	var headline := _label(outer, "ECHO / FIELD TERMINAL     [SCROLL IN REFERENCE DESK]", 20, "#8cc6a2")
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := HSeparator.new()
	outer.add_child(line)
	document_scroll = ScrollContainer.new()
	document_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	document_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(document_scroll)
	var document := VBoxContainer.new()
	document.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document.add_theme_constant_override("separation", 10)
	document_scroll.add_child(document)
	_section(document, "RADIO STATUS", "radio")
	_section(document, "IDENTITY CLAIM / NOT AUTHENTICATED", "identity")
	_section(document, "STATION SYNC / NOT FIELD CONFIRMATION", "records")
	_section(document, "MISSION OBJECTIVE", "objective")
	_section(document, "PREVIOUS RECEIVED TRANSMISSIONS", "transmissions")
	_refresh()

func _label(parent: Node, caption: String, font_size: int, color: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", Color(color))
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _section(parent: Node, title: String, key: String) -> void:
	_label(parent, title, 17, "#6fa694")
	content_labels[key] = _label(parent, "Awaiting station data.", 18, "#d1e2d5")

func set_data(contact: ContactDefinition, state_node: ScenarioState, radio_node: RadioConsole, acquired: bool) -> void:
	current_contact = contact
	run_state = state_node
	radio = radio_node
	is_acquired = acquired
	if is_node_ready():
		_refresh()

func scroll_by(pixels: int) -> void:
	if document_scroll != null:
		document_scroll.scroll_vertical = maxi(0, document_scroll.scroll_vertical + pixels)

func _refresh() -> void:
	if content_labels.is_empty():
		return
	if current_contact == null or run_state == null or radio == null:
		for key in content_labels.keys():
			(content_labels[key] as Label).text = "Waiting for an assigned carrier."
		return
	(content_labels["radio"] as Label).text = "RX %.2f MHz  /  %s  /  QUALITY %d%%\nCHANNEL %s" % [
		radio.frequency, "RECEIVING" if is_acquired else "SEARCHING",
		roundi(radio.quality * 100.0), String(current_contact.channel)
	]
	(content_labels["identity"] as Label).text = "%s\nCallsign is claimed, never authenticated by the display." % (
		String(current_contact.claimed_callsign) if is_acquired else "UNCONFIRMED"
	)
	(content_labels["records"] as Label).text = "ECHO-ACTUAL: %s  [%s]\nECHO-2: %s  [%s]\nCompare this terminal with the independent paper map." % [
		run_state.displayed_location("ECHO-ACTUAL"), str(run_state.agent_status.get("ECHO-ACTUAL", "UNKNOWN")),
		run_state.displayed_location("ECHO-2"), str(run_state.agent_status.get("ECHO-2", "UNKNOWN"))
	]
	# Full authored objective; never silently truncate it to fit the monitor.
	(content_labels["objective"] as Label).text = current_contact.objective
	var previous: Array[String] = []
	for i in range(run_state.evidence_events.size() - 1, -1, -1):
		var event: Dictionary = run_state.evidence_events[i]
		if str(event["kind"]) != "TRANSMISSION":
			continue
		previous.append("#%03d / %s / %s\n%s" % [
			int(event["seq"]), str(event["contact"]), str(event["callsign"]),
			str(event["statement"])
		])
		if previous.size() >= 8:
			break
	(content_labels["transmissions"] as Label).text = "\n\n".join(previous) if not previous.is_empty() else "No received transmissions."
