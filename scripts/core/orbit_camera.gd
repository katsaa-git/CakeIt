class_name OrbitCamera
extends Camera3D
## A camera that orbits the cake. Input is fed in by the tool controller
## (right-drag orbits, wheel zooms, middle-drag pans up and down). Every move
## eases toward its goal so the view always glides instead of snapping.
##
## Also owns the depth-of-field focus (always on the cake) and a small
## spring "nudge" used for satisfying feedback on big actions.

const MIN_DISTANCE: float = 3.0
const MAX_DISTANCE: float = 13.0
const MIN_PITCH: float = 0.05
const MAX_PITCH: float = 1.45
## Photo mode allows getting closer and looking from lower.
const PHOTO_MIN_DISTANCE: float = 1.2
const PHOTO_MIN_PITCH: float = -0.15
const ORBIT_SPEED: float = 0.0055
const SMOOTHING: float = 14.0

## Where the camera looks, and where that point is gliding to.
var target := Vector3(0.0, 1.5, 0.0)
var target_goal := Vector3(0.0, 1.5, 0.0)
var yaw: float = 0.0
var pitch: float = 0.42
var distance: float = 7.0
var yaw_goal: float = 0.0
var pitch_goal: float = 0.42
var distance_goal: float = 7.0
## Extra vertical offset from middle-drag panning.
var pan_goal: float = 0.0
var pan: float = 0.0
var photo_mode: bool = false
## Where depth of field focuses (world space). Set by whoever knows best.
var focus_point := Vector3(0.0, 1.5, 0.0)

var dof: CameraAttributesPractical

var _nudge := Vector3.ZERO
var _nudge_velocity := Vector3.ZERO


func _ready() -> void:
	fov = 34.0
	near = 0.05
	far = 300.0
	dof = CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_near_enabled = true
	dof.dof_blur_amount = 0.07
	dof.auto_exposure_enabled = false
	attributes = dof
	_apply()


func orbit(relative: Vector2) -> void:
	yaw_goal -= relative.x * ORBIT_SPEED
	var min_pitch: float = PHOTO_MIN_PITCH if photo_mode else MIN_PITCH
	pitch_goal = clampf(pitch_goal + relative.y * ORBIT_SPEED, min_pitch, MAX_PITCH)


func zoom(steps: float) -> void:
	var min_distance: float = PHOTO_MIN_DISTANCE if photo_mode else MIN_DISTANCE
	distance_goal = clampf(distance_goal * pow(0.9, steps), min_distance, MAX_DISTANCE)


func pan_vertical(relative_y: float) -> void:
	pan_goal = clampf(pan_goal + relative_y * 0.004 * distance / 7.0, -1.5, 2.5)


## A small shove that springs back, e.g. when a tier lands. `strength` ~0.1.
func nudge(direction: Vector3, strength: float) -> void:
	_nudge_velocity += direction.normalized() * strength * 6.0


func set_photo_mode(enabled: bool) -> void:
	photo_mode = enabled
	if not enabled:
		distance_goal = clampf(distance_goal, MIN_DISTANCE, MAX_DISTANCE)
		pitch_goal = clampf(pitch_goal, MIN_PITCH, MAX_PITCH)


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-SMOOTHING * delta)
	yaw = lerpf(yaw, yaw_goal, k)
	pitch = lerpf(pitch, pitch_goal, k)
	distance = lerpf(distance, distance_goal, 1.0 - exp(-10.0 * delta))
	pan = lerpf(pan, pan_goal, k)
	target = target.lerp(target_goal, 1.0 - exp(-5.0 * delta))
	# Critically damped spring back to rest.
	var stiffness: float = 120.0
	var damping: float = 2.0 * sqrt(stiffness)
	_nudge_velocity += (-_nudge * stiffness - _nudge_velocity * damping) * delta
	_nudge += _nudge_velocity * delta
	_apply()
	_update_focus()


func _apply() -> void:
	var look_at_point: Vector3 = target + Vector3(0.0, pan, 0.0)
	var offset := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
	position = look_at_point + offset + _nudge
	look_at(look_at_point + _nudge * 0.5, Vector3.UP)


func _update_focus() -> void:
	if dof == null:
		return
	var focus_distance: float = global_position.distance_to(focus_point)
	# Sharp around the cake, gently soft in front of and behind it.
	dof.dof_blur_far_distance = focus_distance + 2.6
	dof.dof_blur_far_transition = 5.0
	dof.dof_blur_near_distance = maxf(focus_distance - 2.8, 0.3)
	dof.dof_blur_near_transition = 1.2
