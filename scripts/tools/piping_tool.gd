class_name PipingTool
extends DecoratingTool
## Pipes frosting where the mouse is, on tiers, the stand and other piping.
##
## Feel:
##  - each stroke starts with a soft "pop" of pressure (a little overshoot);
##  - moving fast thins the line slightly, holding still grows a blob;
##  - the path is lightly filtered so hand jitter never shows;
##  - sliding off the cake or jumping to another tier ends the stroke and
##    starts a new one, so nothing ever stretches across thin air.
## Works while the turntable spins: hold the mouse still on the side and the
## line wraps around the cake.

signal stroke_started(world_position: Vector3, world_normal: Vector3, color: Color)
signal stroke_finished(stroke: StrokeData)
## 0..1 how much frosting is flowing right now (for sound and the bag).
signal flow_changed(amount: float)

## How fast the start-of-stroke pressure settles (per second) and wobbles.
const POP_DECAY: float = 13.0
const POP_FREQUENCY: float = 15.0
const POP_START: float = 0.6
## Cursor filtering time constant (seconds).
const FILTER_TIME: float = 0.018
## Minimum distance between samples, in tip radii.
const MIN_STEP: float = 0.15
## Jumps bigger than this (in tip radii, or 0.4 units) start a new stroke.
const MAX_JUMP: float = 6.0

var bag: PipingBag
var preview: CursorPreview

var _builder: StrokeBuilder
var _live: LiveStroke
var _tier_id: int = 0
var _tier_base: float = 0.0
var _press_time: float = 0.0
var _filtered := Vector3.ZERO
var _last_sample := Vector3.ZERO
var _last_normal := Vector3.UP
var _speed: float = 0.0
var _dwell_time: float = 0.0
var _dwell_extra: float = 0.0
var _button_held: bool = false
var _flow: float = 0.0
var _lean := Vector3.ZERO
var _last_hit_world := Vector3.ZERO


func _init() -> void:
	tool_id = &"pipe"


func setup(new_context: EditorContext) -> void:
	super.setup(new_context)
	bag = PipingBag.new()
	add_child(bag)
	preview = CursorPreview.new()
	add_child(preview)
	context.tip_changed.connect(func(_tip: TipDefinition) -> void: _refresh_looks())
	context.size_changed.connect(func(_size: float, _index: int) -> void: _refresh_looks())
	context.color_changed.connect(func(_color: Color) -> void: _refresh_looks())


func activate() -> void:
	_refresh_looks()


func deactivate() -> void:
	release()
	bag.set_shown(false)
	preview.visible = false


func is_busy() -> bool:
	return _builder != null


func hides_cursor() -> bool:
	return preview.visible


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	_button_held = true
	if hit == null:
		return false
	_begin(hit)
	return true


func release() -> void:
	_button_held = false
	_finish()


func update(delta: float, hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	var camera_position: Vector3 = context.camera.global_position
	if _builder != null:
		_continue(delta, hit)
	elif _button_held and hit != null:
		# Came back onto the cake with the button still down.
		_begin(hit)

	if hit != null:
		# Lean the bag back against the direction of travel, like a real hand.
		var lean_goal := Vector3.ZERO
		if _builder != null:
			lean_goal = ((hit.world_position - _last_hit_world) / maxf(delta, 0.001)).limit_length(1.5) * 0.4
		_last_hit_world = hit.world_position
		_lean = _lean.lerp(lean_goal, 1.0 - exp(-6.0 * delta))
		bag.aim(hit.world_position, hit.world_normal, camera_position, context.size, _lean)
		bag.set_shown(true)
		var forward: Vector3 = context.camera.global_basis.y
		preview.show_at(hit.world_position, hit.world_normal, forward)
		preview.set_ghost_visible(_builder == null)
	else:
		bag.set_shown(_builder != null)
		preview.visible = false

	var flow_goal: float = 0.0
	if _builder != null:
		flow_goal = clampf(0.35 + _speed / (context.size * 30.0), 0.0, 1.0)
	_flow = lerpf(_flow, flow_goal, 1.0 - exp(-10.0 * delta))
	bag.set_flow(_flow)
	flow_changed.emit(_flow)


func _refresh_looks() -> void:
	if context.tip == null:
		return
	bag.set_tip(context.tip)
	bag.set_color(context.color)
	preview.configure(context.tip, context.size, context.color)


func _begin(hit: CakePicker.Hit) -> void:
	_tier_id = hit.tier_id
	_tier_base = context.model.tier_base_y(_tier_id)
	var view: TierView = context.view.view_for(_tier_id)
	if view == null:
		return
	_builder = StrokeBuilder.new(context.tip, context.size, context.color, randi())
	# For a single-click stamp, face the shell or leaf toward the camera's right.
	var right: Vector3 = context.camera.global_basis.x
	_builder.fallback_forward = context.picker.spin_root.global_basis.inverse() * right
	_live = LiveStroke.new()
	_live.setup(_builder, Materials.buttercream())
	view.add_child(_live)
	_press_time = 0.0
	_speed = 0.0
	_dwell_time = 0.0
	_dwell_extra = 0.0
	_filtered = hit.local_position
	_last_sample = _filtered
	_last_normal = hit.cake_normal
	_builder.add_sample(_filtered, hit.cake_normal, _pressure())
	_live.refresh()
	bag.set_squeeze(1.0)
	bag.pulse(1.0)
	stroke_started.emit(hit.world_position, hit.world_normal, context.color)


func _continue(delta: float, hit: CakePicker.Hit) -> void:
	_press_time += delta
	if hit == null:
		# Off the cake: keep the blob growing in place but add no path.
		_update_dwell(delta, true)
		_builder.set_open_pressure(_pressure())
		_live.refresh()
		return
	var point: Vector3 = hit.cake_position - Vector3(0.0, _tier_base, 0.0)
	var jump_limit: float = maxf(context.size * MAX_JUMP, 0.4)
	if point.distance_to(_last_sample) > jump_limit:
		_finish()
		_begin(hit)
		return
	var previous: Vector3 = _filtered
	_filtered = _filtered.lerp(point, 1.0 - exp(-delta / FILTER_TIME))
	var moved: float = _filtered.distance_to(previous)
	_speed = lerpf(_speed, moved / maxf(delta, 0.0001), 1.0 - exp(-delta / 0.08))
	_update_dwell(delta, moved / maxf(delta, 0.0001) < context.size * 1.5)
	_last_normal = _last_normal.slerp(hit.cake_normal, 1.0 - exp(-delta / 0.03)).normalized()
	if _filtered.distance_to(_last_sample) >= context.size * MIN_STEP:
		_builder.add_sample(_filtered, _last_normal, _pressure())
		_last_sample = _filtered
	else:
		_builder.set_open_pressure(_pressure())
	_live.refresh()


func _update_dwell(delta: float, still: bool) -> void:
	if still:
		_dwell_time += delta
		var growth: float = context.tip.dwell_growth if context.tip != null else 0.0
		_dwell_extra = maxf(_dwell_extra, growth * (1.0 - exp(-maxf(_dwell_time - 0.12, 0.0) / 0.9)))
	else:
		_dwell_time = 0.0
		_dwell_extra *= exp(-delta / 0.12)


## Thickness multiplier right now.
func _pressure() -> float:
	var pop: float = 1.0 + (POP_START - 1.0) * exp(-_press_time * POP_DECAY) * cos(_press_time * POP_FREQUENCY)
	var thinning: float = 0.0
	if context.tip != null:
		var relative_speed: float = _speed / maxf(context.size * 25.0, 0.001)
		thinning = context.tip.speed_thinning * smoothstep(0.3, 2.0, relative_speed)
	return pop * (1.0 - thinning) * (1.0 + _dwell_extra)


func _finish() -> void:
	if _builder == null:
		return
	var builder: StrokeBuilder = _builder
	var live: LiveStroke = _live
	_builder = null
	_live = null
	bag.set_squeeze(0.0)
	bag.pulse(-0.6)
	builder.finish()
	if builder.pieces.is_empty():
		live.free()
		return
	var stroke := StrokeData.new()
	stroke.id = context.model.new_id()
	stroke.tier_id = _tier_id
	stroke.tip_id = context.tip.id
	stroke.size_index = context.size_index
	stroke.radius = builder.radius
	stroke.color = builder.color
	stroke.rng_seed = builder.rng_seed
	stroke.forward = builder.fallback_forward
	builder.export_samples(stroke)
	# The batch adopts the live stroke node itself, so nothing is rebuilt and
	# nothing pops when the button is released.
	context.view.offer_prebuilt(stroke.id, builder, live)
	context.commands.run(AddStrokeCommand.new(stroke))
	stroke_finished.emit(stroke)
