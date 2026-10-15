class_name SpatulaTool
extends DecoratingTool
## A bench scraper for smoothing the coat. Hold it against a tier and either
## drag it around or let the turntable spin the cake under it: the spatula
## marks fade until the coat is glass smooth. Works best (and feels best)
## with the turntable spinning, like the real thing.

signal smoothing(world_position: Vector3, amount: float)
signal fully_smooth(world_position: Vector3)

## Smoothness gained per unit of surface that passes under the blade.
const SMOOTH_PER_UNIT: float = 0.065

var _blade: Node3D
var _tier_id: int = 0
var _start_smoothness: float = 0.0
var _smoothness: float = 0.0
var _last_point := Vector3.ZERO
var _pressing: bool = false
var _celebrated: bool = false
var _target := Transform3D.IDENTITY
var _shown: bool = false


func _init() -> void:
	tool_id = &"spatula"


func setup(new_context: EditorContext) -> void:
	super.setup(new_context)
	_blade = _build_scraper()
	add_child(_blade)
	_blade.visible = false


func deactivate() -> void:
	release()
	_shown = false
	_blade.visible = false


func is_busy() -> bool:
	return _pressing


func hides_cursor() -> bool:
	return _shown


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	if hit == null or hit.tier_id == CakeModel.BOARD_ID:
		return false
	var tier: TierData = context.model.tier_by_id(hit.tier_id)
	if tier == null:
		return false
	if not tier.coated:
		context.toast("Give this tier a smooth coat first, then scrape it")
		return true
	_pressing = true
	_tier_id = tier.id
	_start_smoothness = tier.smoothness
	_smoothness = tier.smoothness
	_celebrated = _smoothness >= 0.99
	_last_point = hit.cake_position
	return true


func release() -> void:
	if not _pressing:
		return
	_pressing = false
	var tier: TierData = context.model.tier_by_id(_tier_id)
	if tier != null and _smoothness > _start_smoothness + 0.001:
		context.commands.run(TierCommands.CoatTier.new(context.model, tier.id, tier.coat_color, tier.coated, _smoothness, false))


func update(delta: float, hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	_shown = hit != null and hit.tier_id != CakeModel.BOARD_ID
	if _shown:
		_target = _blade_transform(hit)
		if not _blade.visible:
			_blade.global_transform = _target
		_blade.visible = true
	else:
		_blade.visible = _pressing
	if _blade.visible:
		var press_depth: float = 0.02 if _pressing else 0.0
		var goal: Transform3D = _target.translated(-_target.basis.x.normalized() * press_depth)
		_blade.global_transform = _blade.global_transform.interpolate_with(goal, 1.0 - exp(-24.0 * delta))

	if not _pressing or hit == null or hit.tier_id != _tier_id:
		return
	# Surface passing under the blade: from dragging or from the turntable.
	var travelled: float = hit.cake_position.distance_to(_last_point)
	_last_point = hit.cake_position
	if travelled > 0.5:
		return
	_smoothness = minf(_smoothness + travelled * SMOOTH_PER_UNIT, 1.0)
	var view: TierView = context.view.view_for(_tier_id)
	if view != null and view.material != null:
		view.material.set_shader_parameter("smoothness", _smoothness)
		view.material.set_shader_parameter("prev_smoothness", _smoothness)
	if travelled > 0.0:
		smoothing.emit(hit.world_position, travelled / maxf(delta, 0.001))
	if _smoothness >= 0.999 and not _celebrated:
		_celebrated = true
		context.toast("Silky smooth!")
		fully_smooth.emit(hit.world_position)


# Blade edge on the surface, standing out along the normal, upright on the
# side of the cake (flat-ish on the top), angled a little like a real scrape.
func _blade_transform(hit: CakePicker.Hit) -> Transform3D:
	var n: Vector3 = hit.world_normal
	var up: Vector3 = Vector3.UP - n * n.dot(Vector3.UP)
	if up.length_squared() < 0.05:
		up = context.camera.global_basis.y - n * n.dot(context.camera.global_basis.y)
	up = up.normalized()
	var x: Vector3 = n.rotated(up, 0.45)
	var z: Vector3 = x.cross(up).normalized()
	return Transform3D(Basis(x, up, z), hit.world_position)


func _build_scraper() -> Node3D:
	var root := Node3D.new()
	root.name = "Scraper"
	root.top_level = true
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.9, 0.9, 0.92)
	steel.metallic = 0.85
	steel.roughness = 0.28
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.55, 0.85, 0.012)
	blade.mesh = blade_mesh
	blade.material_override = steel
	blade.position = Vector3(0.275, 0.0, 0.0)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(blade)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.72, 0.52, 0.34)
	wood.roughness = 0.55
	var handle := MeshInstance3D.new()
	var handle_mesh := CapsuleMesh.new()
	handle_mesh.radius = 0.05
	handle_mesh.height = 0.95
	handle.mesh = handle_mesh
	handle.material_override = wood
	handle.position = Vector3(0.58, 0.0, 0.0)
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(handle)
	return root
