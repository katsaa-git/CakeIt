class_name Turntable
extends Node3D
## The cake stand. Its plate spins (carrying the cake) with gentle inertia
## and friction, so the player can flick it and pipe a smooth line around the
## side while it turns.
##
## Ways to spin:
##  - grab the plate's rim (or anywhere with Space held) and drag: the plate
##    sticks under the cursor, and keeps turning when released with a flick;
##  - hold A / D for a smooth motorised turn;
##  - toggle the slow auto-spin.

signal grab_started
signal grab_ended(speed: float)

const STAND_HEIGHT: float = 0.8
const PLATE_THICKNESS: float = 0.12
const PLATE_RADIUS: float = 2.25
## The rim zone you can grab, measured in from the plate edge.
const RIM_WIDTH: float = 0.5
## How quickly a free spin slows down (higher stops sooner).
const FRICTION: float = 0.9
const MAX_SPEED: float = 9.0
const KEY_SPEED: float = 1.6
const KEY_ACCEL: float = 5.0
const AUTO_SPEED: float = 0.55

## Rotation of the plate, radians (unbounded).
var angle: float = 0.0
## Radians per second.
var velocity: float = 0.0
var auto_spin: bool = false
## -1, 0 or 1 while A / D are held.
var key_direction: float = 0.0

var spin_root: Node3D
var plate_material: StandardMaterial3D

var _grabbing: bool = false
var _grab_offset: float = 0.0
var _grab_mode_drag: bool = false
var _grab_last_x: float = 0.0
var _grab_target: float = 0.0
var _history: Array[Vector2] = []
var _hover_rim: bool = false
var _rim_glow: float = 0.0


func _ready() -> void:
	name = "Turntable"
	_build_stand()


func top_height() -> float:
	return STAND_HEIGHT + PLATE_THICKNESS


func is_grabbing() -> bool:
	return _grabbing


func is_moving() -> bool:
	return absf(velocity) > 0.02 or _grabbing


## True if the cake-frame point (on the plate's top plane) is in the rim zone.
func is_rim_point(cake_point: Vector3, cake_radius: float) -> bool:
	var r: float = Vector2(cake_point.x, cake_point.z).length()
	var inner: float = maxf(PLATE_RADIUS - RIM_WIDTH, cake_radius + 0.12)
	return r >= inner and r <= PLATE_RADIUS + 0.12


func set_rim_hover(hover: bool) -> void:
	_hover_rim = hover


## Starts dragging the plate. `world_point` is where the cursor meets the
## plate plane (world space); pass null to spin with sideways mouse motion.
func begin_grab(world_point: Variant, mouse_x: float) -> void:
	_grabbing = true
	_history.clear()
	velocity = 0.0
	_grab_target = angle
	if world_point == null:
		_grab_mode_drag = true
		_grab_last_x = mouse_x
	else:
		_grab_mode_drag = false
		_grab_offset = _world_angle(world_point) + angle
	grab_started.emit()


func update_grab(world_point: Variant, mouse_x: float) -> void:
	if not _grabbing:
		return
	if _grab_mode_drag or world_point == null:
		_grab_target -= (mouse_x - _grab_last_x) * 0.008
		_grab_last_x = mouse_x
	else:
		var wanted: float = _grab_offset - _world_angle(world_point)
		# Unwrap so crossing the +-PI seam does not jump.
		_grab_target += wrapf(wanted - _grab_target, -PI, PI)


func end_grab() -> void:
	if not _grabbing:
		return
	_grabbing = false
	velocity = clampf(_flick_speed(), -MAX_SPEED, MAX_SPEED)
	if absf(velocity) < 0.15:
		velocity = 0.0
	grab_ended.emit(velocity)


## Instantly stop (e.g. when the player starts a precise action).
func stop() -> void:
	velocity = 0.0


func _process(delta: float) -> void:
	if _grabbing:
		# Follow the cursor closely but not rigidly: smooths mouse jitter.
		var previous: float = angle
		angle = lerpf(angle, _grab_target, 1.0 - exp(-28.0 * delta))
		var now: float = Time.get_ticks_msec() / 1000.0
		_history.append(Vector2(now, angle))
		while _history.size() > 2 and now - _history[0].x > 0.1:
			_history.pop_front()
		velocity = (angle - previous) / maxf(delta, 0.0001)
	elif key_direction != 0.0:
		velocity = move_toward(velocity, key_direction * KEY_SPEED, KEY_ACCEL * delta)
		angle += velocity * delta
	elif auto_spin:
		velocity = move_toward(velocity, AUTO_SPEED, 1.2 * delta)
		angle += velocity * delta
	else:
		velocity *= exp(-FRICTION * delta)
		if absf(velocity) < 0.02:
			velocity = 0.0
		angle += velocity * delta
	spin_root.rotation.y = angle

	var glow_goal: float = 1.0 if (_hover_rim or _grabbing) else 0.0
	_rim_glow = move_toward(_rim_glow, glow_goal, delta * 5.0)
	plate_material.emission_energy_multiplier = _rim_glow * 0.12


func _flick_speed() -> float:
	if _history.size() < 2:
		return 0.0
	var first: Vector2 = _history[0]
	var last: Vector2 = _history[_history.size() - 1]
	var dt: float = last.x - first.x
	if dt < 0.012:
		return 0.0
	return (last.y - first.y) / dt


## Angle of a world point around the stand's axis, as seen from above.
func _world_angle(world_point: Vector3) -> float:
	var local: Vector3 = world_point - global_position
	return atan2(local.z, local.x)


func _build_stand() -> void:
	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_color = Color(0.97, 0.95, 0.91)
	ceramic.roughness = 0.2
	ceramic.metallic_specular = 0.55
	ceramic.clearcoat_enabled = true
	ceramic.clearcoat = 0.4
	ceramic.clearcoat_roughness = 0.15

	# Pedestal: a flared foot, a slim neck and a flared top.
	var pedestal_points := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.06, 0.02), Vector2(1.06, 0.05),
		Vector2(0.98, 0.09), Vector2(0.7, 0.14), Vector2(0.45, 0.2), Vector2(0.33, 0.28),
		Vector2(0.29, 0.38), Vector2(0.28, 0.5), Vector2(0.3, 0.6), Vector2(0.36, 0.68),
		Vector2(0.5, 0.75), Vector2(0.72, 0.79), Vector2(0.8, STAND_HEIGHT), Vector2(0.0, STAND_HEIGHT),
	])
	var pedestal_profile: Dictionary = LatheMesh.smooth_profile(pedestal_points)
	var pedestal := MeshInstance3D.new()
	pedestal.name = "Pedestal"
	pedestal.mesh = LatheMesh.build(pedestal_profile["points"], pedestal_profile["normals"], 96)
	pedestal.material_override = ceramic
	add_child(pedestal)

	spin_root = Node3D.new()
	spin_root.name = "SpinRoot"
	spin_root.position.y = top_height()
	add_child(spin_root)

	plate_material = ceramic.duplicate()
	plate_material.emission_enabled = true
	plate_material.emission = Color(1.0, 0.82, 0.6)
	plate_material.emission_energy_multiplier = 0.0

	# Plate with a softly scalloped rim and a raised lip.
	var t: float = PLATE_THICKNESS
	var r: float = PLATE_RADIUS
	var plate_points := PackedVector2Array([
		Vector2(0.0, -t), Vector2(r - 0.25, -t), Vector2(r - 0.08, -t + 0.01), Vector2(r - 0.01, -t + 0.04),
		Vector2(r, -t * 0.5), Vector2(r - 0.005, -0.02), Vector2(r - 0.03, 0.012), Vector2(r - 0.08, 0.018),
		Vector2(r - 0.14, 0.004), Vector2(r - 0.22, 0.0), Vector2(0.0, 0.0),
	])
	var plate_profile: Dictionary = LatheMesh.smooth_profile(plate_points)
	var normals: PackedVector2Array = plate_profile["normals"]
	# Keep the top and bottom perfectly flat.
	normals[normals.size() - 1] = Vector2(0.0, 1.0)
	normals[normals.size() - 2] = Vector2(0.0, 1.0)
	normals[0] = Vector2(0.0, -1.0)
	normals[1] = Vector2(0.0, -1.0)
	var scallops: Callable = func(a: float) -> float: return 1.0 - 0.012 * (1.0 - absf(cos(a * 12.0)))
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = LatheMesh.build(plate_profile["points"], normals, 288, scallops, 2)
	plate.material_override = plate_material
	spin_root.add_child(plate)
