class_name PlayerRig
extends Node3D

signal station_object_selected(action: String)
signal frequency_wheel(steps: float)

var camera: Camera3D
var yaw: float = 0.0
var pitch: float = -0.14
var dragging_view: bool = false

func _ready() -> void:
	position = Vector3(0, 1.62, 1.78)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 82.0
	add_child(camera)
	_update_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_view = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_interact_at_pointer()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			frequency_wheel.emit(1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			frequency_wheel.emit(-1.0)
	elif event is InputEventMouseMotion and dragging_view:
		yaw = clampf(yaw - event.relative.x * 0.003, -0.85, 0.85)
		pitch = clampf(pitch - event.relative.y * 0.003, -0.54, 0.38)
		_update_view()

func _update_view() -> void:
	rotation.y = yaw
	camera.rotation.x = pitch

func _interact_at_pointer() -> void:
	var pointer := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pointer)
	var end := origin + camera.project_ray_normal(pointer) * 8.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var hit: Object = result["collider"]
	if hit.has_meta("station_action"):
		station_object_selected.emit(str(hit.get_meta("station_action")))
