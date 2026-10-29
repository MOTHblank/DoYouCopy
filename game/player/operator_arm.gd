class_name OperatorArm
extends Node3D

## Small procedural stand-in for the future rigged arm. No animation assets needed.
var rest_position := Vector3(0.62, -0.71, -1.04)
var current_tween: Tween

func _ready() -> void:
	position = rest_position
	_make_part(Vector3(0.00, -0.14, -0.12), Vector3(0.17, 0.39, 0.18), Color("#344f55"))
	_make_part(Vector3(-0.05, 0.14, -0.33), Vector3(0.125, 0.38, 0.13), Color("#ba9981"))
	_make_part(Vector3(-0.08, 0.33, -0.40), Vector3(0.145, 0.13, 0.18), Color("#b9947c"))

func _make_part(pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	add_child(mesh)

func animate_action(action: String) -> void:
	if current_tween != null and current_tween.is_running():
		current_tween.kill()
	position = rest_position
	var reach := Vector3(0.2, -0.45, -1.50)
	match action:
		"frequency":
			reach = Vector3(-0.20, -0.43, -1.65)
		"cleanup":
			reach = Vector3(-0.12, -0.43, -1.52)
		"quarantine":
			reach = Vector3(0.48, -0.30, -1.43)
		"paper":
			reach = Vector3(0.34, -0.50, -1.46)
		"microphone":
			reach = Vector3(0.08, -0.42, -1.28)
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position", reach, 0.20)
	current_tween.tween_interval(0.10 if action != "quarantine" else 0.23)
	current_tween.tween_property(self, "position", rest_position, 0.28)
