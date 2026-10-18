class_name DustTool
extends DecoratingTool
## Lustre dust: a soft round brush that dusts shimmer onto a tier where you
## paint it, over the coat, the piping and the decorations alike, in the
## picked colour (metallic and pearl colours look best). The longer you
## brush one spot, the richer it gets, up to the chosen strength; "brush
## off" takes it away again. Each press is one undo step.
##
## The dust lives in the tier's ShimmerMask; the shaders add a soft sheen
## and fine glinting flakes there (art/shaders/shimmer.gdshaderinc).

signal dusting(world_position: Vector3)

## Brush radius for each size preset, in game units (1.5 to 4 cm across).
const SIZES: Array[float] = [0.075, 0.13, 0.2]
const SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]
## Most dust a press can build up, for each strength preset.
const LIMITS: Array[float] = [0.32, 0.6, 1.0]
const STRENGTH_NAMES: Array[String] = ["Whisper", "Shimmer", "Gold paint"]
## How fast dust builds up (amount per second at the middle of the brush).
const RATE: float = 1.6

var _pressing: bool = false
var _tier_id: int = 0
var _before: Image
var _changed := Rect2i()
var _brush: Node3D
var _ring := MeshInstance3D.new()
var _ring_material := StandardMaterial3D.new()
var _tuft_material := StandardMaterial3D.new()
var _target := Transform3D.IDENTITY
var _shown: bool = false


func _init() -> void:
	tool_id = &"dust"


func setup(new_context: EditorContext) -> void:
	super.setup(new_context)
	_ring.mesh = DecorationTool._ring_mesh()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)
	_brush = _build_brush()
	add_child(_brush)
	_brush.visible = false
	context.color_changed.connect(func(_c: Color) -> void: _refresh_look())
	context.dust_changed.connect(_refresh_look)
	_refresh_look()


func activate() -> void:
	_refresh_look()


func deactivate() -> void:
	release()
	_shown = false
	_ring.visible = false
	_brush.visible = false


func is_busy() -> bool:
	return _pressing


func hides_cursor() -> bool:
	return _shown


func brush_radius() -> float:
	return SIZES[context.dust_size_index]


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	if hit == null:
		return false
	if hit.tier_id == CakeModel.BOARD_ID:
		context.toast("Dust the cake itself: brush over a tier")
		return true
	var tier: TierData = context.model.tier_by_id(hit.tier_id)
	if tier == null:
		return false
	if context.dust_erase and not tier.has_shimmer():
		context.toast("No dust to brush off here")
		return true
	_pressing = true
	_tier_id = tier.id
	_before = tier.ensure_shimmer().image.duplicate() as Image
	_changed = Rect2i()
	return true


func release() -> void:
	if not _pressing:
		return
	_pressing = false
	var tier: TierData = context.model.tier_by_id(_tier_id)
	if tier == null or not _changed.has_area():
		_before = null
		return
	var old_part: Image = _before.get_region(_changed)
	var new_part: Image = tier.shimmer.region(_changed)
	_before = null
	context.commands.run(TierCommands.PaintShimmer.new(tier.id, _changed, old_part, new_part, context.dust_erase))


func update(delta: float, hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	_show_cursor(delta, hit)
	if not _pressing or hit == null or hit.tier_id != _tier_id:
		return
	dab(hit.local_position, delta)


## Dusts (or brushes off) round a tier-local point for `delta` seconds of
## brushing. Also used by scripted scenes and tests.
func dab(local_position: Vector3, delta: float) -> void:
	var tier: TierData = context.model.tier_by_id(_tier_id)
	if tier == null:
		return
	var limit: float = LIMITS[context.dust_strength_index]
	var strength: float = RATE * limit * delta
	if context.dust_erase:
		strength = -RATE * delta
	var rect: Rect2i = tier.ensure_shimmer().dab(local_position, brush_radius(), context.color, strength, limit, tier.radius, tier.height)
	if not rect.has_area():
		return
	_changed = rect if not _changed.has_area() else _changed.merge(rect)
	var view: TierView = context.view.view_for(tier.id)
	if view != null:
		view.apply_shimmer(tier, rect)
	dusting.emit(context.picker.to_world(local_position + Vector3(0.0, context.model.tier_base_y(tier.id), 0.0)))


## Brushes a whole stroke of dust in one go (scripted scenes and tests): a
## press, a path of points (tier-local), and a release, one undo step.
func brush_path(tier_id: int, points: PackedVector3Array, seconds_per_point: float = 0.05) -> void:
	var tier: TierData = context.model.tier_by_id(tier_id)
	if tier == null:
		return
	_pressing = true
	_tier_id = tier_id
	_before = tier.ensure_shimmer().image.duplicate() as Image
	_changed = Rect2i()
	for p in points:
		dab(p, seconds_per_point)
	release()


# --- Cursor --------------------------------------------------------------------

func _refresh_look() -> void:
	var color: Color = context.color
	_ring_material.albedo_color = Color(color.lightened(0.2), 0.8) if not context.dust_erase else Color(1.0, 1.0, 1.0, 0.6)
	_tuft_material.albedo_color = color.lerp(Color(0.96, 0.92, 0.86), 0.55) if not context.dust_erase else Color(0.96, 0.92, 0.86)


func _show_cursor(delta: float, hit: CakePicker.Hit) -> void:
	_shown = hit != null and hit.tier_id != CakeModel.BOARD_ID
	if not _shown:
		_ring.visible = false
		_brush.visible = _pressing
		return
	var up: Vector3 = hit.world_normal
	var forward: Vector3 = TubeBuilder.any_perpendicular(up)
	_ring.visible = true
	_ring.global_transform = Transform3D(Basis(up.cross(forward), up, forward).scaled(Vector3.ONE * brush_radius()), hit.world_position + up * 0.004)
	# The brush leans out of the surface toward the camera, bristles down.
	var to_camera: Vector3 = (context.camera.global_position - hit.world_position).normalized()
	var axis: Vector3 = (up * 0.75 + to_camera * 0.5).normalized()
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var press_depth: float = 0.015 if _pressing else 0.0
	_target = Transform3D(Basis(side, axis, side.cross(axis)), hit.world_position + axis * (0.02 - press_depth))
	if not _brush.visible:
		_brush.global_transform = _target
	_brush.visible = true
	_brush.global_transform = _brush.global_transform.interpolate_with(_target, 1.0 - exp(-22.0 * delta))


## A soft dusting brush: a fluffy round tuft of bristles (tinted a little by
## the dust on it), a silver ferrule and a long wooden handle. Its tip is at
## the origin and it points along +Y.
func _build_brush() -> Node3D:
	var root := Node3D.new()
	root.name = "DustBrush"
	root.top_level = true
	var tuft := MeshInstance3D.new()
	var tuft_mesh := SphereMesh.new()
	tuft_mesh.radius = 0.09
	tuft_mesh.height = 0.26
	tuft.mesh = tuft_mesh
	tuft.position = Vector3(0.0, 0.12, 0.0)
	_tuft_material.roughness = 0.9
	tuft.material_override = _tuft_material
	root.add_child(tuft)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.86, 0.86, 0.88)
	steel.metallic = 0.9
	steel.roughness = 0.3
	var ferrule := MeshInstance3D.new()
	var ferrule_mesh := CylinderMesh.new()
	ferrule_mesh.top_radius = 0.045
	ferrule_mesh.bottom_radius = 0.07
	ferrule_mesh.height = 0.14
	ferrule.mesh = ferrule_mesh
	ferrule.position = Vector3(0.0, 0.29, 0.0)
	ferrule.material_override = steel
	root.add_child(ferrule)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.26)
	wood.roughness = 0.4
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.022
	handle_mesh.bottom_radius = 0.042
	handle_mesh.height = 0.9
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.81, 0.0)
	handle.material_override = wood
	root.add_child(handle)
	for child in root.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
