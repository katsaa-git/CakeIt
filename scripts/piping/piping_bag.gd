class_name PipingBag
extends Node3D
## The piping bag that follows the cursor: a translucent bag (with the chosen
## frosting colour showing through), a coupler and a metal nozzle whose
## opening matches the selected tip. It glides after the cursor, leans like a
## hand-held bag, and squishes when squeezed.

const BAG_SCALE: float = 0.8
## Gap between the nozzle tip and the surface, in tip radii.
const NOZZLE_GAP: float = 1.25

var _body := Node3D.new()
var _frosting_material := StandardMaterial3D.new()
var _nozzle := MeshInstance3D.new()
var _nozzle_material := StandardMaterial3D.new()
var _target_position := Vector3.ZERO
var _target_basis := Basis.IDENTITY
var _squeeze: float = 0.0
var _squeeze_velocity: float = 0.0
var _squeeze_goal: float = 0.0
var _visible_amount: float = 0.0
var _show: bool = false
var _snap_next: bool = true
var _tip_key: String = ""
var _flow_pulse: float = 0.0


func _ready() -> void:
	name = "PipingBag"
	top_level = true
	scale = Vector3.ONE * BAG_SCALE
	add_child(_body)
	_build()
	visible = false


func set_color(color: Color) -> void:
	_frosting_material.albedo_color = color


## Rebuilds the nozzle opening for a tip.
func set_tip(tip: TipDefinition) -> void:
	if tip == null or tip.id == _tip_key:
		return
	_tip_key = tip.id
	_nozzle.mesh = _build_nozzle(tip.shape())


## Moves the bag so its nozzle sits just above `world_point`. The bag is held
## like a right-handed baker would: mostly upright, leaning out from the
## surface and a little to the right, and never pointing at the camera (so we
## always see it side-on and it never hides the spot being piped).
func aim(world_point: Vector3, world_normal: Vector3, camera_position: Vector3, tip_radius: float, lean: Vector3 = Vector3.ZERO) -> void:
	var to_camera: Vector3 = (camera_position - world_point).normalized()
	var camera_right: Vector3 = Vector3.UP.cross(to_camera).normalized()
	var away: Vector3 = -Vector3(to_camera.x, 0.0, to_camera.z).normalized()
	var axis: Vector3 = (Vector3.UP * 1.0 + world_normal * 0.6 + camera_right * 0.45 + away * 0.25 - lean * 0.3).normalized()
	var side: Vector3 = axis.cross(to_camera)
	if side.length_squared() < 0.001:
		side = TubeBuilder.any_perpendicular(axis)
	side = side.normalized()
	var forward: Vector3 = side.cross(axis).normalized()
	_target_basis = Basis(side, axis, forward)
	_target_position = world_point + world_normal * tip_radius * NOZZLE_GAP
	if _snap_next:
		global_position = _target_position
		basis = _target_basis.scaled(Vector3.ONE * BAG_SCALE)
		_snap_next = false


func set_shown(shown: bool) -> void:
	if shown == _show:
		return
	_show = shown
	if shown and _visible_amount <= 0.0:
		_snap_next = true


## 0 = relaxed, 1 = squeezing hard.
func set_squeeze(amount: float) -> void:
	_squeeze_goal = amount


## A quick extra squish, e.g. at the start of a stroke.
func pulse(strength: float = 1.0) -> void:
	_squeeze_velocity += 9.0 * strength


## Gentle breathing while frosting flows (0..1).
func set_flow(amount: float) -> void:
	_flow_pulse = amount


func _process(delta: float) -> void:
	_visible_amount = move_toward(_visible_amount, 1.0 if _show else 0.0, delta * 8.0)
	visible = _visible_amount > 0.0
	if not visible:
		return
	var follow: float = 1.0 - exp(-26.0 * delta)
	global_position = global_position.lerp(_target_position, follow)
	var current: Quaternion = basis.orthonormalized().get_rotation_quaternion()
	var wanted: Quaternion = _target_basis.get_rotation_quaternion()
	var rotation_now: Quaternion = current.slerp(wanted, 1.0 - exp(-12.0 * delta))
	basis = Basis(rotation_now).scaled(Vector3.ONE * BAG_SCALE * _ease_pop(_visible_amount))

	# Springy squeeze: squash wide and short, wobble back.
	var goal: float = _squeeze_goal + sin(Time.get_ticks_msec() * 0.012) * 0.06 * _flow_pulse
	var stiffness: float = 260.0
	var damping: float = 14.0
	_squeeze_velocity += ((goal - _squeeze) * stiffness - _squeeze_velocity * damping) * delta
	_squeeze += _squeeze_velocity * delta
	var squash: float = _squeeze * 0.09
	_body.scale = Vector3(1.0 + squash, 1.0 - squash * 0.7, 1.0 + squash)


static func _ease_pop(t: float) -> float:
	# Small overshoot when appearing.
	return 1.0 + 0.08 * sin(t * PI) if t < 1.0 else 1.0


func _build() -> void:
	# Translucent plastic bag.
	var bag_material := StandardMaterial3D.new()
	bag_material.albedo_color = Color(1.0, 1.0, 1.0, 0.38)
	bag_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bag_material.roughness = 0.28
	bag_material.metallic_specular = 0.6
	bag_material.rim_enabled = true
	bag_material.rim = 0.5
	bag_material.cull_mode = BaseMaterial3D.CULL_BACK
	var bag_points := PackedVector2Array([
		Vector2(0.0, 0.36), Vector2(0.105, 0.36), Vector2(0.15, 0.45), Vector2(0.21, 0.6),
		Vector2(0.27, 0.78), Vector2(0.3, 0.92), Vector2(0.28, 1.04), Vector2(0.2, 1.14),
		Vector2(0.1, 1.2), Vector2(0.055, 1.26), Vector2(0.05, 1.36), Vector2(0.0, 1.38),
	])
	var bag_profile: Dictionary = LatheMesh.smooth_profile(bag_points)
	var bag := MeshInstance3D.new()
	bag.name = "Bag"
	bag.mesh = LatheMesh.build(bag_profile["points"], bag_profile["normals"], 40)
	bag.material_override = bag_material
	bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(bag)

	# Frosting inside the bag, in the current colour.
	_frosting_material.albedo_color = Color(1.0, 0.96, 0.9)
	_frosting_material.roughness = 0.55
	var fill_points := PackedVector2Array([
		Vector2(0.0, 0.37), Vector2(0.095, 0.37), Vector2(0.14, 0.46), Vector2(0.2, 0.61),
		Vector2(0.25, 0.76), Vector2(0.265, 0.84), Vector2(0.2, 0.88), Vector2(0.0, 0.9),
	])
	var fill_profile: Dictionary = LatheMesh.smooth_profile(fill_points)
	var fill := MeshInstance3D.new()
	fill.name = "Frosting"
	fill.mesh = LatheMesh.build(fill_profile["points"], fill_profile["normals"], 32)
	fill.material_override = _frosting_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(fill)

	# Coupler ring.
	var coupler_profile: Dictionary = LatheMesh.rounded_cylinder_profile(0.11, 0.07, 0.02, 3)
	var coupler := MeshInstance3D.new()
	coupler.name = "Coupler"
	coupler.mesh = LatheMesh.build(coupler_profile["points"], coupler_profile["normals"], 32)
	coupler.position.y = 0.3
	coupler.material_override = Materials.standard(Color(0.95, 0.95, 0.97), 0.35)
	coupler.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coupler)

	_nozzle_material.albedo_color = Color(0.86, 0.87, 0.9)
	_nozzle_material.metallic = 1.0
	_nozzle_material.roughness = 0.22
	_nozzle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nozzle.name = "Nozzle"
	_nozzle.material_override = _nozzle_material
	_nozzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nozzle)


# A metal cone that turns from a circle at the coupler into the tip's shape
# at the opening.
func _build_nozzle(shape: ProfileShape) -> ArrayMesh:
	var out := MeshArrays.new()
	var count: int = shape.points.size()
	var rings: int = 6
	var top_radius: float = 0.1
	var tip_radius: float = 0.045
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var y: float = lerpf(0.31, 0.0, t)
		var r: float = lerpf(top_radius, tip_radius, t)
		for j in range(count):
			var p: Vector2 = shape.points[j]
			var a: float = atan2(p.y, p.x)
			var circle := Vector2(cos(a), sin(a))
			var blend: Vector2 = circle.lerp(p, t * t)
			var position := Vector3(blend.x * r, y, blend.y * r)
			var normal := Vector3(blend.x, 0.25, blend.y).normalized()
			out.add_vertex(position, normal, Color.WHITE, Vector2.ZERO)
	for i in range(rings):
		for j in range(count):
			var a: int = i * count + j
			var b: int = i * count + (j + 1) % count
			var c: int = a + count
			var d: int = b + count
			out.add_triangle(a, c, b)
			out.add_triangle(b, c, d)
	return out.to_mesh()
