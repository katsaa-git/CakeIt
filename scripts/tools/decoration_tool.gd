class_name DecorationTool
extends DecoratingTool
## Places decorations on the cake (and on the stand's plate):
##   SINGLE   click for one (a cherry, a rose, a candle, a sign);
##   LINE     click for one, drag for an evenly spaced string (pearls);
##   SCATTER  hold and move to spray them round the cursor (sprinkles);
##   RIM      drag along a tier's top edge to pour a drip over it (ganache).
##   BAND     drag round the side of a tier to wrap a ribbon there; a click
##            wraps it all the way round (snapping to the base or top edge).
## A soft ghost shows what will land where before clicking. Everything placed
## in one press is a single undo step; while the button is held, pieces show
## in a temporary layer and become real on release.

## After each press that placed something: where, and how many pieces.
signal placed(world_position: Vector3, count: int)

const GHOST_ALPHA: float = 0.45

var _ghost := MeshInstance3D.new()
var _ghost_material := StandardMaterial3D.new()
var _ghost_definition: DecorationDefinition
var _brush := MeshInstance3D.new()
var _rng := RandomNumberGenerator.new()

var _pressing: bool = false
var _pending: Array[DecorationData] = []
var _preview_layers: Dictionary = {}
var _spray: float = 0.0
var _last_placed := Vector3.ZERO
var _last_world := Vector3.ZERO
var _warned: bool = false

# Rim (drip) state: the tier, and the unwrapped angles swept so far.
var _rim_tier: int = 0
var _rim_last: float = 0.0
var _rim_min: float = 0.0
var _rim_max: float = 0.0
var _rim_decoration: DecorationData
var _rim_band: bool = false
## Height (tier-local) of the plane the drag follows off the tier.
var _rim_y: float = 0.0


func _init() -> void:
	tool_id = &"decorate"


func setup(new_context: EditorContext) -> void:
	super.setup(new_context)
	_rng.randomize()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.no_depth_test = false
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)
	_brush.mesh = _ring_mesh()
	var brush_material := StandardMaterial3D.new()
	brush_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brush_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	brush_material.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
	brush_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_brush.material_override = brush_material
	_brush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brush.top_level = true
	_brush.visible = false
	add_child(_brush)
	context.decoration_changed.connect(func(_d: Resource) -> void: _refresh_ghost())
	context.color_changed.connect(func(_c: Color) -> void: _refresh_ghost())


func activate() -> void:
	if context.decoration == null and not Content.decorations().is_empty():
		context.set_decoration(Content.decorations()[0])
	_refresh_ghost()


func deactivate() -> void:
	release()
	_ghost.visible = false
	_brush.visible = false


func is_busy() -> bool:
	return _pressing


func definition() -> DecorationDefinition:
	return context.decoration as DecorationDefinition


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	var def: DecorationDefinition = definition()
	if def == null or hit == null:
		return false
	_pressing = true
	_pending.clear()
	_warned = false
	_last_world = hit.world_position
	match def.placement:
		DecorationDefinition.Placement.SINGLE, DecorationDefinition.Placement.LINE:
			_place(def, hit.tier_id, hit.local_position, hit.cake_normal)
			_last_placed = hit.cake_position
		DecorationDefinition.Placement.SCATTER:
			# A little burst straight away, so a single click leaves something.
			_spray = 4.0
			_spray_some(def, hit)
		DecorationDefinition.Placement.RIM, DecorationDefinition.Placement.BAND:
			_begin_rim(def, hit)
	return true


func release() -> void:
	if not _pressing:
		return
	_pressing = false
	var def: DecorationDefinition = definition()
	if _rim_decoration != null:
		_finish_rim()
	for layer: DecorationLayer in _preview_layers.values():
		if is_instance_valid(layer):
			layer.free()
	_preview_layers.clear()
	if _pending.is_empty():
		return
	var batch: Array[DecorationData] = _pending.duplicate()
	_pending.clear()
	context.commands.run(AddDecorationsCommand.new(batch, def.display_name if def != null else "Decoration"))
	context.view.flush_decorations()
	placed.emit(_last_world, batch.size())


func update(delta: float, hit: CakePicker.Hit, screen_position: Vector2) -> void:
	var def: DecorationDefinition = definition()
	if def == null:
		return
	if hit != null:
		_last_world = hit.world_position
	_show_cursor(def, hit)
	if not _pressing:
		return
	match def.placement:
		DecorationDefinition.Placement.LINE:
			if hit != null:
				var step: float = def.spacing * def.radius() * _size_scale(def)
				if hit.cake_position.distance_to(_last_placed) >= step:
					_place(def, hit.tier_id, hit.local_position, hit.cake_normal)
					_last_placed = hit.cake_position
		DecorationDefinition.Placement.SCATTER:
			if hit != null:
				_spray += def.rate * delta
				_spray_some(def, hit)
		DecorationDefinition.Placement.RIM, DecorationDefinition.Placement.BAND:
			_update_rim(hit, screen_position)


# --- Making pieces ------------------------------------------------------------

func _size_scale(def: DecorationDefinition) -> float:
	return def.preset_size(context.decoration_size_index)


## How a piece sits: standing out along the surface (or straight up), turned
## at random or toward the viewer. `jitter` adds the random turn and tilt.
func _placement_basis(def: DecorationDefinition, normal: Vector3, jitter: bool) -> Basis:
	var up: Vector3 = Vector3.UP if def.align == DecorationDefinition.Align.UPRIGHT else normal.normalized()
	var camera_basis: Basis = context.picker.spin_root.global_basis.inverse() * context.camera.global_basis
	var forward: Vector3
	if def.facing == DecorationDefinition.Facing.VIEWER:
		forward = camera_basis.z if def.align == DecorationDefinition.Align.UPRIGHT else camera_basis.y
	else:
		forward = camera_basis.y
		if jitter:
			forward = forward.rotated(up, _rng.randf() * TAU)
	forward -= up * forward.dot(up)
	if forward.length_squared() < 1e-6:
		forward = TubeBuilder.any_perpendicular(up)
	forward = forward.normalized()
	var basis := Basis(up.cross(forward).normalized(), up, forward)
	if jitter and def.max_tilt > 0.0:
		var axis: Vector3 = forward.rotated(up, _rng.randf() * TAU)
		basis = Basis(axis, deg_to_rad(_rng.randf() * def.max_tilt)) * basis
	var scale: float = _size_scale(def)
	if jitter:
		scale *= 1.0 + _rng.randf_range(-def.size_jitter, def.size_jitter)
	return basis.scaled(Vector3.ONE * scale)


func _allowed(def: DecorationDefinition, normal: Vector3) -> bool:
	return not def.top_only or normal.y > 0.6


func _place(def: DecorationDefinition, tier_id: int, local_position: Vector3, normal: Vector3) -> void:
	if not _allowed(def, normal):
		if not _warned:
			_warned = true
			context.toast("%s goes on top of a tier" % def.display_name)
		return
	var basis: Basis = _placement_basis(def, normal, true)
	var decoration := DecorationData.new()
	decoration.id = context.model.new_id()
	decoration.def_id = def.id
	decoration.tier_id = tier_id
	var sink: float = def.sink * def.radius() * basis.get_scale().y
	decoration.transform = Transform3D(basis, local_position - normal.normalized() * sink)
	decoration.color = _piece_color(def)
	decoration.shine = _piece_shine(def)
	decoration.rng_seed = _rng.randi()
	if def.uses_text():
		decoration.text = context.decoration_text
	_pending.append(decoration)
	_preview_layer(tier_id).add(decoration)


## Sprays whole pieces while there is spray to spend: each lands where a ray
## straight down onto the surface finds it, so sprinkles fall onto piping,
## over the rim and onto the stand naturally.
func _spray_some(def: DecorationDefinition, hit: CakePicker.Hit) -> void:
	var n: Vector3 = hit.cake_normal
	var t1: Vector3 = TubeBuilder.any_perpendicular(n)
	var t2: Vector3 = n.cross(t1)
	var reach: float = def.brush_radius * _size_scale(def)
	while _spray >= 1.0:
		_spray -= 1.0
		var r: float = reach * sqrt(_rng.randf())
		var a: float = _rng.randf() * TAU
		var p: Vector3 = hit.cake_position + (t1 * cos(a) + t2 * sin(a)) * r
		var landing: CakePicker.Hit = context.picker.pick_ray(p + n * 0.3, -n)
		if landing != null:
			_place(def, landing.tier_id, landing.local_position, landing.cake_normal)


func _preview_layer(tier_id: int) -> DecorationLayer:
	var layer: DecorationLayer = _preview_layers.get(tier_id)
	if layer == null or not is_instance_valid(layer):
		layer = DecorationLayer.new()
		layer.setup(tier_id, context.model, context.view.view_for(tier_id).materials)
		var view: TierView = context.view.view_for(tier_id)
		view.add_child(layer)
		layer.name = "PlacingPreview"
		_preview_layers[tier_id] = layer
	return layer


# --- Drips along the rim, ribbons round the side ---------------------------------

## Starts a drag round a tier: along its top edge for a drip (RIM), or round
## its side at the pressed height for a ribbon (BAND).
func _begin_rim(def: DecorationDefinition, hit: CakePicker.Hit) -> void:
	var band: bool = def.placement == DecorationDefinition.Placement.BAND
	if hit.tier_id == CakeModel.BOARD_ID or (band and hit.cake_normal.y > 0.6):
		context.toast("Drag round the side of a tier to wrap it" if band else "Drag along the top edge of a tier to pour a drip")
		return
	var tier: TierData = context.model.tier_by_id(hit.tier_id)
	_rim_band = band
	_rim_tier = hit.tier_id
	_rim_last = atan2(hit.local_position.z, hit.local_position.x)
	_rim_min = _rim_last
	_rim_max = _rim_last
	_rim_y = tier.height
	_rim_decoration = DecorationData.new()
	_rim_decoration.id = context.model.new_id()
	_rim_decoration.def_id = def.id
	_rim_decoration.tier_id = _rim_tier
	_rim_decoration.color = _piece_color(def)
	_rim_decoration.shine = _piece_shine(def)
	_rim_decoration.rng_seed = _rng.randi()
	if band:
		_rim_y = band_height(def, tier, hit.local_position.y)
		_rim_decoration.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _size_scale(def)), Vector3(0.0, _rim_y, 0.0))
	_show_rim()


## Where a ribbon pressed at height `y` goes: snapped down onto the base or
## up to the top edge when close, otherwise right there.
func band_height(def: DecorationDefinition, tier: TierData, y: float) -> float:
	var half: float = def.radius() * _size_scale(def)
	if y < half * 2.4:
		return half
	if y > tier.height - half * 2.0:
		return tier.height - half
	return y


func _update_rim(hit: CakePicker.Hit, screen_position: Vector2) -> void:
	if _rim_decoration == null:
		return
	var tier: TierData = context.model.tier_by_id(_rim_tier)
	if tier == null:
		return
	var local: Variant = null
	if hit != null and hit.tier_id == _rim_tier:
		local = hit.local_position
	else:
		# Off the tier: follow the cursor round on the plane of the top (or of
		# the ribbon).
		var base: float = context.model.tier_base_y(_rim_tier)
		var point: Variant = context.picker.plane_point(screen_position, base + _rim_y)
		if point != null:
			local = (point as Vector3) - Vector3(0.0, base, 0.0)
	if local == null:
		return
	var angle: float = atan2((local as Vector3).z, (local as Vector3).x)
	_rim_last += wrapf(angle - _rim_last, -PI, PI)
	var grew: bool = _rim_last < _rim_min - 0.02 or _rim_last > _rim_max + 0.02
	_rim_min = minf(_rim_min, _rim_last)
	_rim_max = maxf(_rim_max, _rim_last)
	if grew:
		_show_rim()


func _show_rim() -> void:
	var layer: DecorationLayer = _preview_layer(_rim_tier)
	layer.remove(_rim_decoration)
	var start: float = _rim_min
	var end: float = minf(_rim_max, _rim_min + TAU)
	if _rim_band:
		# A click (or a tiny drag) wraps the ribbon all the way round, starting
		# (and tying its bow) where it was pressed.
		if end - start < 0.3:
			start = _rim_last
			end = start + TAU
	elif end - start < 0.5:
		# A click (or a tiny drag) still pours a short drip.
		var middle: float = (start + end) * 0.5
		start = middle - 0.3
		end = middle + 0.3
	_rim_decoration.path = PackedFloat32Array([start, end])
	layer.add(_rim_decoration)
	layer.flush()


func _finish_rim() -> void:
	_pending.append(_rim_decoration)
	_rim_decoration = null


## The colour for a new piece: the picked colour, a random one of the picked
## mix, or the decoration's own.
func _piece_color(def: DecorationDefinition) -> Color:
	return def.pick_color(context.color, _rng, context.mix if def.takes_mix() else PackedColorArray())


## Pieces in the picked colour take its finish (gold, pearl...).
func _piece_shine(def: DecorationDefinition) -> float:
	return context.shine if def.uses_palette() and context.mix.is_empty() else 0.0


# --- Cursor --------------------------------------------------------------------

func _refresh_ghost() -> void:
	var def: DecorationDefinition = definition()
	_ghost_definition = def
	if def == null or def.placement == DecorationDefinition.Placement.SCATTER or def.placement == DecorationDefinition.Placement.RIM or def.placement == DecorationDefinition.Placement.BAND:
		_ghost.mesh = null
		return
	_ghost.mesh = def.mesh()
	var color: Color = def.pick_color(context.color, RandomNumberGenerator.new())
	color.a = GHOST_ALPHA
	_ghost_material.albedo_color = color


func _show_cursor(def: DecorationDefinition, hit: CakePicker.Hit) -> void:
	if hit == null:
		_ghost.visible = false
		_brush.visible = false
		return
	var spin: Basis = context.picker.spin_root.global_basis
	var scatter: bool = def.placement == DecorationDefinition.Placement.SCATTER
	var rim: bool = def.placement == DecorationDefinition.Placement.RIM or def.placement == DecorationDefinition.Placement.BAND
	if scatter or rim:
		# A ring on the surface: the spray area, or where the drip will pour.
		_ghost.visible = false
		_brush.visible = true
		var radius: float = def.brush_radius * _size_scale(def) if scatter else 0.06
		var up: Vector3 = hit.world_normal
		var forward: Vector3 = TubeBuilder.any_perpendicular(up)
		_brush.global_transform = Transform3D(Basis(up.cross(forward), up, forward).scaled(Vector3.ONE * radius), hit.world_position + up * 0.004)
		return
	_brush.visible = false
	if _pressing and def.placement == DecorationDefinition.Placement.SINGLE:
		_ghost.visible = false
		return
	if _ghost_definition != def:
		_refresh_ghost()
	var allowed: bool = _allowed(def, hit.cake_normal)
	_ghost.visible = _ghost.mesh != null
	var basis: Basis = spin * _placement_basis(def, hit.cake_normal, false)
	var sink: float = def.sink * def.radius() * _size_scale(def)
	_ghost.global_transform = Transform3D(basis, hit.world_position - hit.world_normal * sink)
	var color: Color = _ghost_material.albedo_color
	color.a = GHOST_ALPHA if allowed else GHOST_ALPHA * 0.35
	_ghost_material.albedo_color = color


## A thin flat ring of radius 1 in the XZ plane (the spray and drip cursor).
static func _ring_mesh() -> ArrayMesh:
	var out := MeshArrays.new()
	var count: int = 48
	for k in range(count + 1):
		var a: float = TAU * float(k) / float(count)
		var d := Vector3(cos(a), 0.0, sin(a))
		out.add_vertex(d * 0.94, Vector3.UP, Color.WHITE, Vector2.ZERO)
		out.add_vertex(d * 1.0, Vector3.UP, Color.WHITE, Vector2.ZERO)
	for k in range(count):
		var i: int = k * 2
		out.add_triangle(i, i + 2, i + 1)
		out.add_triangle(i + 1, i + 2, i + 3)
	return out.to_mesh()


# --- Scripted placement (showcase scenes, tests) -------------------------------

## Places one piece right away, as its own undo step, exactly as a click would.
func place_one(def: DecorationDefinition, tier_id: int, local_position: Vector3, normal: Vector3) -> void:
	context.set_decoration(def)
	_pressing = true
	_pending.clear()
	_place(def, tier_id, local_position, normal)
	release()


## Pours a drip over a tier's edge from one angle to another (radians).
func pour_drip(def: DecorationDefinition, tier_id: int, start: float, end: float) -> void:
	context.set_decoration(def)
	var decoration := DecorationData.new()
	decoration.id = context.model.new_id()
	decoration.def_id = def.id
	decoration.tier_id = tier_id
	decoration.color = _piece_color(def)
	decoration.shine = _piece_shine(def)
	decoration.rng_seed = _rng.randi()
	decoration.path = PackedFloat32Array([start, end])
	context.commands.run(AddDecorationsCommand.new([decoration] as Array[DecorationData], def.display_name))
	context.view.flush_decorations()


## Wraps a ribbon round a tier at height `y` (snapped like a press there)
## from one angle to another; `end - start` of TAU or more goes all round.
func wrap_ribbon(def: DecorationDefinition, tier_id: int, y: float, start: float, end: float) -> void:
	context.set_decoration(def)
	var tier: TierData = context.model.tier_by_id(tier_id)
	var decoration := DecorationData.new()
	decoration.id = context.model.new_id()
	decoration.def_id = def.id
	decoration.tier_id = tier_id
	decoration.color = _piece_color(def)
	decoration.shine = _piece_shine(def)
	decoration.rng_seed = _rng.randi()
	decoration.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _size_scale(def)), Vector3(0.0, band_height(def, tier, y), 0.0))
	decoration.path = PackedFloat32Array([start, minf(end, start + TAU)])
	context.commands.run(AddDecorationsCommand.new([decoration] as Array[DecorationData], def.display_name))
	context.view.flush_decorations()
