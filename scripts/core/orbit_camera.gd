class_name OrbitCamera
extends Camera3D
## A camera that orbits a target point.
## Right mouse button drag rotates; the mouse wheel zooms.

const MIN_DISTANCE: float = 2.5
const MAX_DISTANCE: float = 14.0
const MIN_PITCH: float = 0.07
const MAX_PITCH: float = 1.48

var target := Vector3(0.0, 2.0, 0.0)
## Where the camera is heading; the target glides toward it (used when tiers are added).
var target_goal := Vector3(0.0, 2.0, 0.0)
var yaw: float = 0.45
var pitch: float = 0.5
var distance: float = 6.5

var _orbiting: bool = false


func _ready() -> void:
	fov = 40.0
	near = 0.1
	far = 200.0
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.92, MIN_DISTANCE, MAX_DISTANCE)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.08, MIN_DISTANCE, MAX_DISTANCE)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _orbiting:
		yaw -= motion.relative.x * 0.006
		pitch = clampf(pitch + motion.relative.y * 0.006, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	target = target.lerp(target_goal, 1.0 - exp(-6.0 * delta))
	_apply()


func _apply() -> void:
	position = target + Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
	look_at(target, Vector3.UP)
