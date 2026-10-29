class_name WorkstationRoom
extends Node3D

var spectrum: SpectrumDisplay
var terminal: TerminalDisplay

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
	_box("FieldMap", Vector3(2.10, 2.18, -3.07), Vector3(1.36, 0.98, 0.085), "#c6c3a9", "map")
	_label("RELAY - JUNCTION\nPUMP B - EAST", Vector3(2.10, 2.18, -2.99), "#34443e", 0.75)
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
	var light := OmniLight3D.new()
	light.position = Vector3(0.05, 3.45, -0.48)
	light.light_energy = 1.3
	light.omni_range = 6.0
	add_child(light)
	_box("CeilingFixture", Vector3(0, 4.37, -0.5), Vector3(1.3, 0.08, 0.3), "#d9d4be")

func _monitor(name: String, center: Vector3, width: float, height: float, display: Control) -> void:
	_box(name + "Shell", center - Vector3(0, 0, 0.045), Vector3(width + 0.14, height + 0.14, 0.16), "#202d2b", name.to_lower())
	var viewport := SubViewport.new()
	viewport.name = name + "Viewport"
	viewport.size = Vector2i(650, 370)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(display)
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
	_box("Radio", Vector3(-1.14, 1.03, -0.73), Vector3(1.48, 0.22, 0.54), "#333b3b", "radio")
	_box("FrequencyKnob", Vector3(-1.51, 1.17, -0.65), Vector3(0.24, 0.08, 0.25), "#bfa377", "radio")
	_box("CleanupKnob", Vector3(-0.98, 1.17, -0.65), Vector3(0.24, 0.08, 0.25), "#91a9a5", "radio")
	_label("FREQ  /  SIGNAL", Vector3(-1.12, 1.30, -1.51), "#b2ddd1", 0.65)
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
	_box("MicrophoneStand", Vector3(-0.12, 1.07, -0.53), Vector3(0.18, 0.28, 0.18), "#414a48", "microphone")
	_box("Microphone", Vector3(-0.12, 1.24, -0.53), Vector3(0.40, 0.15, 0.16), "#92a7a3", "microphone")
	_box("QuarantineGuard", Vector3(1.65, 1.03, -0.54), Vector3(0.43, 0.24, 0.44), "#6c4f42", "quarantine")
	_box("QuarantineSwitch", Vector3(1.65, 1.18, -0.54), Vector3(0.16, 0.10, 0.16), "#b55246", "quarantine")
	_label("AUTHORIZED PERSONNEL ONLY", Vector3(0.60, 2.40, -3.12), "#33433e", 0.8)
	_label("FIELD: RELAY - JUNCTION - PUMP B - EAST SERVICE", Vector3(0.50, 2.22, -3.12), "#45574b", 0.67)

func update_station(contact: ContactDefinition, state_node: ScenarioState, radio_node: RadioConsole, receiving: bool) -> void:
	if contact == null:
		return
	spectrum.set_signal(radio_node.frequency, contact.frequency, radio_node.quality, radio_node.blocked)
	terminal.set_data(contact, state_node, radio_node, receiving)
