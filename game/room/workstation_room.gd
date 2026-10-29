class_name WorkstationRoom
extends Node3D

var spectrum: SpectrumDisplay
var terminal: TerminalDisplay
var field_map: FieldMapDisplay
var status_light: OmniLight3D
var ceiling_light: OmniLight3D
var frequency_readout: Label3D

func _ready() -> void:
	_build_room()
	_build_equipment()

func _material(color: String, lit: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.79
	if lit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(color)
	return mat

func _box(name: String, pos: Vector3, dimensions: Vector3, color: String, action: String = "") -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	add_child(holder)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = _material(color)
	holder.add_child(mesh)
	if not action.is_empty():
		var target := Area3D.new()
		target.set_meta("station_action", action)
		target.collision_layer = 1
		target.collision_mask = 1
		holder.add_child(target)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions + Vector3(0.08, 0.08, 0.08)
		collision.shape = shape
		target.add_child(collision)
	return holder

func _label(message: String, pos: Vector3, color: String = "#d8e5db", scale_factor: float = 1.0) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = pos
	label.pixel_size = 0.0029 * scale_factor
	label.font_size = 36
	label.modulate = Color(color)
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)

func _build_room() -> void:
	_box("Floor", Vector3(0, -0.04, -1), Vector3(7, 0.2, 7), "#555f63")
	_box("BackWall", Vector3(0, 2.25, -3.3), Vector3(7, 4.6, 0.2), "#7a8a84")
	_box("LeftWall", Vector3(-3.45, 2.25, -1), Vector3(0.2, 4.6, 7), "#667772")
	_box("RightWall", Vector3(3.45, 2.25, -1), Vector3(0.2, 4.6, 7), "#667772")
	_box("Ceiling", Vector3(0, 4.5, -1), Vector3(7, 0.15, 7), "#a1a7a0")
	_box("Desk", Vector3(0, 0.87, -0.90), Vector3(4.3, 0.16, 1.75), "#665f51")
	_box("DeskLeftLeg", Vector3(-1.85, 0.42, -0.9), Vector3(0.12, 0.82, 1.15), "#4d4f4d")
	_box("DeskRightLeg", Vector3(1.85, 0.42, -0.9), Vector3(0.12, 0.82, 1.15), "#4d4f4d")
	_box("Door", Vector3(-2.25, 1.4, -3.18), Vector3(1.08, 2.8, 0.11), "#454d4b")
	_box("DoorWindow", Vector3(-2.25, 1.94, -3.07), Vector3(0.54, 0.48, 0.02), "#192c2d")
	_box("Shelves", Vector3(2.55, 1.32, -3.06), Vector3(1.12, 0.15, 0.5), "#4a5551")
	_box("Clock", Vector3(0, 2.6, -3.17), Vector3(0.54, 0.33, 0.08), "#3b4542")
	_label("COMMS / SHIFT 04", Vector3(0, 2.6, -3.09), "#b6ccc0", 0.7)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#17252a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b2baad")
	environment.ambient_light_energy = 0.50
	env.environment = environment
	add_child(env)
	ceiling_light = OmniLight3D.new()
	ceiling_light.position = Vector3(0.05, 3.45, -0.48)
	ceiling_light.light_energy = 1.3
	ceiling_light.omni_range = 6.0
	ceiling_light.light_color = Color("#fff1d6")
	add_child(ceiling_light)
	_box("CeilingFixture", Vector3(0, 4.37, -0.5), Vector3(1.3, 0.08, 0.3), "#d9d4be")
	status_light = OmniLight3D.new()
	status_light.position = Vector3(1.60, 1.12, -0.57)
	status_light.omni_range = 1.25
	status_light.light_energy = 0.0
	status_light.light_color = Color("#cf9c57")
	add_child(status_light)

func _monitor(name: String, center: Vector3, width: float, height: float, display: Control) -> void:
	_box(name + "Shell", center - Vector3(0, 0, 0.045), Vector3(width + 0.14, height + 0.14, 0.16), "#202d2b", name.to_lower())
	var viewport := SubViewport.new()
	viewport.name = name + "Viewport"
	viewport.size = Vector2i(650, 370)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(display)
	# These Controls are rendered at a fixed resolution inside SubViewport.
	# Do not combine opposing stretch anchors with explicit size: that caused
	# Godot 4.7 to warn and could overwrite the monitor's intended dimensions.
	display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	display.position = Vector2.ZERO
	display.custom_minimum_size = Vector2(float(viewport.size.x), float(viewport.size.y))
	display.size = display.custom_minimum_size
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var screen := MeshInstance3D.new()
	screen.name = name + "Screen"
	screen.mesh = quad
	screen.position = center + Vector3(0, 0, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	screen.material_override = mat
	add_child(screen)

func _build_equipment() -> void:
	spectrum = SpectrumDisplay.new()
	_monitor("Spectrum", Vector3(-0.92, 1.62, -1.69), 1.42, 0.78, spectrum)
	terminal = TerminalDisplay.new()
	_monitor("Terminal", Vector3(0.90, 1.62, -1.69), 1.42, 0.78, terminal)
	field_map = FieldMapDisplay.new()
	_monitor("Map", Vector3(2.13, 2.20, -3.04), 1.48, 0.98, field_map)
	_box("Radio", Vector3(-1.14, 1.03, -0.73), Vector3(1.48, 0.22, 0.54), "#333b3b", "radio")
	_box("FrequencyKnob", Vector3(-1.51, 1.17, -0.65), Vector3(0.24, 0.08, 0.25), "#bfa377", "frequency")
	_box("CleanupKnob", Vector3(-0.98, 1.17, -0.65), Vector3(0.24, 0.08, 0.25), "#91a9a5", "cleanup")
	_label("FREQ  /  SIGNAL", Vector3(-1.12, 1.30, -1.51), "#b2ddd1", 0.65)
	frequency_readout = Label3D.new()
	frequency_readout.position = Vector3(-1.17, 1.41, -1.18)
	frequency_readout.text = "101.00 MHz / STATIC"
	frequency_readout.pixel_size = 0.0026
	frequency_readout.font_size = 30
	frequency_readout.modulate = Color("#e8d6a4")
	add_child(frequency_readout)
	_box("RepeatButton", Vector3(-1.77, 1.19, -0.87), Vector3(0.17, 0.10, 0.16), "#a0a8a0", "repeat")
	_box("AuthButton", Vector3(-0.56, 1.19, -0.87), Vector3(0.17, 0.10, 0.16), "#c5a372", "authenticate")
	_label("REP", Vector3(-1.76, 1.33, -0.98), "#c6e0d3", 0.50)
	_label("AUTH", Vector3(-0.56, 1.33, -0.98), "#e4cd91", 0.50)
	_box("Paper", Vector3(0.52, 0.99, -0.62), Vector3(0.85, 0.025, 0.62), "#c6bfa5", "paper")
	_box("PaperTab", Vector3(0.52, 1.013, -0.55), Vector3(0.65, 0.025, 0.035), "#565c56", "paper")
	var paper_print := Label3D.new()
	paper_print.text = "ECHO / AUTH\nREFERENCE"
	paper_print.position = Vector3(0.52, 1.035, -0.63)
	paper_print.rotation.x = -PI / 2.0
	paper_print.pixel_size = 0.002
	paper_print.font_size = 32
	paper_print.modulate = Color("#39433f")
	add_child(paper_print)
	for entry in [
		{"name": "HOLD", "x": 0.13, "color": "#889a91"},
		{"name": "PROCEED", "x": 0.60, "color": "#8ca98f"},
		{"name": "REROUTE", "x": 1.11, "color": "#9b947c"}
	]:
		_box("Response" + str(entry["name"]), Vector3(float(entry["x"]), 1.05, -1.17), Vector3(0.39, 0.12, 0.27), str(entry["color"]), str(entry["name"]).to_lower())
		_label(str(entry["name"]), Vector3(float(entry["x"]), 1.19, -1.22), "#e0e6d9", 0.56)
	_box("MicrophoneStand", Vector3(-0.12, 1.07, -0.53), Vector3(0.18, 0.28, 0.18), "#414a48", "microphone")
	_box("Microphone", Vector3(-0.12, 1.24, -0.53), Vector3(0.40, 0.15, 0.16), "#92a7a3", "microphone")
	_label("PUSH TO TRANSMIT", Vector3(-0.12, 1.46, -0.59), "#f1d5a1", 0.55)
	_box("QuarantineGuard", Vector3(1.65, 1.03, -0.54), Vector3(0.43, 0.24, 0.44), "#6c4f42", "quarantine")
	_box("QuarantineSwitch", Vector3(1.65, 1.18, -0.54), Vector3(0.16, 0.10, 0.16), "#b55246", "quarantine")
	_label("AUTHORIZED PERSONNEL ONLY", Vector3(0.60, 2.40, -3.12), "#33433e", 0.8)
	_label("FIELD: RELAY - JUNCTION - PUMP B - EAST SERVICE", Vector3(0.50, 2.22, -3.12), "#45574b", 0.67)

func update_station(contact: ContactDefinition, state_node: ScenarioState, radio_node: RadioConsole, receiving: bool) -> void:
	if contact == null:
		return
	var phantom := 101.85 if state_node.has_flag("terminal_unreliable") and state_node.quarantined_channels.has("A-ALT") else -1.0
	spectrum.set_signal(radio_node.frequency, contact.frequency, radio_node.quality, radio_node.blocked, phantom)
	terminal.set_data(contact, state_node, radio_node, receiving)
	field_map.update_verified_positions(state_node.agent_locations, state_node.agent_status)
	if frequency_readout != null:
		frequency_readout.text = "%.2f MHz / %02d%%" % [radio_node.frequency, roundi(radio_node.quality * 100.0)]
	if ceiling_light != null:
		# The same ordinary office gradually changes temperature, not scenery.
		var escalation := clampf(float(int(String(contact.id).substr(1)) - 1) / 7.0, 0.0, 1.0)
		ceiling_light.light_energy = lerpf(1.3, 0.99, escalation)
		ceiling_light.light_color = Color("#fff1d6").lerp(Color("#c2d3d5"), escalation * 0.70)
	if status_light != null:
		status_light.light_energy = 0.7 if state_node.has_flag("quarantine_available") else 0.0
		status_light.light_color = Color("#c45e49") if state_node.has_flag("terminal_unreliable") else Color("#cf9c57")
