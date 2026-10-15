class_name CakeView
extends Node3D
## Shows a CakeModel: one TierView per tier plus one for the stand's plate.
## It only ever reacts to the model's signals, so undo, redo, loading and
## tools all go through the same path.
##
## Stroke meshes come from three places, cheapest first:
##  1. the piping tool hands over the builder it already used while piping;
##  2. a small cache of recently removed strokes (so redo is instant);
##  3. otherwise the stroke is rebuilt from its data, a few per frame.

signal stroke_removed_visual(tier_view: TierView, pieces: Array[MeshArrays])
signal tier_added_visual(tier_view: TierView)
## Emitted once all queued strokes are built (after loading a cake).
signal build_queue_empty

const BUILD_BUDGET_USEC: int = 5000
const REMOVED_CACHE_SIZE: int = 48

var model: CakeModel
var collision_root: Node3D
var board_radius: float = 2.0

var _views: Dictionary = {}
var _board: TierView
var _build_queue: Array[StrokeData] = []
var _prebuilt: Dictionary = {}
var _removed_cache: Dictionary = {}
var _removed_order: Array[int] = []
var _was_building: bool = false
# The stroke currently being rebuilt from data, possibly across several frames.
var _job_stroke: StrokeData
var _job_builder: StrokeBuilder
var _job_index: int = 0


func setup(cake_model: CakeModel, new_collision_root: Node3D, plate_radius: float) -> void:
	model = cake_model
	collision_root = new_collision_root
	board_radius = plate_radius
	name = "CakeView"
	model.reset.connect(_on_reset)
	model.tiers_changed.connect(_on_tiers_changed)
	model.tier_coat_changed.connect(_on_coat_changed)
	model.stroke_added.connect(_on_stroke_added)
	model.stroke_removed.connect(_on_stroke_removed)
	_board = TierView.new()
	_board.setup(CakeModel.BOARD_ID, collision_root, true, board_radius)
	add_child(_board)
	_on_reset()


func view_for(tier_id: int) -> TierView:
	if tier_id == CakeModel.BOARD_ID:
		return _board
	return _views.get(tier_id)


func tier_views() -> Array[TierView]:
	var out: Array[TierView] = []
	for tier in model.tiers:
		var view: TierView = _views.get(tier.id)
		if view != null:
			out.append(view)
	return out


## The piping tool calls this just before adding its stroke, so the stroke
## appears with the exact geometry (and the very meshes) the player watched
## being piped. `display` is the node showing it; the batch adopts it.
func offer_prebuilt(stroke_id: int, builder: StrokeBuilder, display: Node3D = null) -> void:
	_prebuilt[stroke_id] = [builder, display]


func is_building() -> bool:
	return not _build_queue.is_empty()


## Builds every queued stroke now (tests and benchmarks).
func flush() -> void:
	while not _build_queue.is_empty():
		_build_step(1 << 30)
	for view in _all_views():
		view.strokes.flush()


func stats() -> Dictionary:
	var chunks: int = 0
	var strokes: int = 0
	var pending: int = 0
	for view in _all_views():
		chunks += view.strokes.chunk_count()
		strokes += view.strokes.stroke_count()
		pending += view.strokes.pending_count()
	return {"chunks": chunks, "strokes": strokes, "pending_merge": pending, "queued_builds": _build_queue.size()}


func _all_views() -> Array[TierView]:
	var out: Array[TierView] = [_board]
	out.append_array(tier_views())
	return out


func _process(_delta: float) -> void:
	if _build_queue.is_empty():
		if _was_building:
			_was_building = false
			build_queue_empty.emit()
		return
	_was_building = true
	_build_step(BUILD_BUDGET_USEC)


## Builds queued strokes for up to `budget_usec`. A long stroke can be paused
## halfway and continued next frame, so loading never causes a spike.
func _build_step(budget_usec: int) -> void:
	var started: int = Time.get_ticks_usec()
	while not _build_queue.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var stroke: StrokeData = _build_queue[0]
		if _job_builder == null or _job_stroke != stroke:
			_job_stroke = stroke
			_job_builder = StrokeBuilder.new(Content.tip(stroke.tip_id), stroke.radius, stroke.color, stroke.rng_seed)
			_job_index = 0
		var count: int = stroke.points.size()
		while _job_index < count and Time.get_ticks_usec() - started < budget_usec:
			var end: int = mini(_job_index + 16, count)
			for i in range(_job_index, end):
				_job_builder.add_sample(stroke.points[i], stroke.normals[i], stroke.pressures[i])
			_job_index = end
		if _job_index < count:
			return
		_job_builder.finish()
		_build_queue.pop_front()
		var view: TierView = view_for(stroke.tier_id)
		if view != null:
			view.strokes.add(stroke.id, _job_builder.pieces, _job_builder.collision_faces)
		_job_builder = null
		_job_stroke = null


# --- Model signals -------------------------------------------------------------------

func _on_reset() -> void:
	for view: TierView in _views.values():
		view.collision_frame.queue_free()
		view.queue_free()
	_views.clear()
	_board.strokes.clear_all()
	_build_queue.clear()
	_job_builder = null
	_job_stroke = null
	_prebuilt.clear()
	_sync_tiers(false)
	for stroke in model.strokes:
		_build_queue.append(stroke)


func _on_tiers_changed() -> void:
	_sync_tiers(true)


func _sync_tiers(animate: bool) -> void:
	var alive: Dictionary = {}
	var y: float = 0.0
	for tier in model.tiers:
		alive[tier.id] = true
		var view: TierView = _views.get(tier.id)
		var is_new: bool = view == null
		if is_new:
			view = TierView.new()
			view.setup(tier.id, collision_root)
			add_child(view)
			_views[tier.id] = view
		view.sync(tier, y, animate and not is_new)
		if is_new and animate:
			view.play_drop_in()
			tier_added_visual.emit(view)
		y += tier.height
	for id: int in _views.keys():
		if not alive.has(id):
			var view: TierView = _views[id]
			_views.erase(id)
			view.play_remove_and_free()


func _on_coat_changed(tier: TierData, animate: bool) -> void:
	var view: TierView = _views.get(tier.id)
	if view != null:
		view.apply_coat(tier, animate)


func _on_stroke_added(stroke: StrokeData) -> void:
	var view: TierView = view_for(stroke.tier_id)
	if view == null:
		return
	var offered: Array = _prebuilt.get(stroke.id, [])
	if not offered.is_empty():
		_prebuilt.erase(stroke.id)
		var builder: StrokeBuilder = offered[0]
		view.strokes.add(stroke.id, builder.pieces, builder.collision_faces, offered[1])
		return
	var cached: Array = _removed_cache.get(stroke.id, [])
	if not cached.is_empty() and cached[2] == stroke:
		_removed_cache.erase(stroke.id)
		_removed_order.erase(stroke.id)
		view.strokes.add(stroke.id, cached[0], cached[1])
		return
	_build_queue.append(stroke)


func _on_stroke_removed(stroke: StrokeData) -> void:
	_build_queue.erase(stroke)
	var view: TierView = view_for(stroke.tier_id)
	if view == null:
		return
	var removed: Array = view.strokes.remove(stroke.id)
	if removed.is_empty():
		return
	var body_pieces: Array[MeshArrays] = removed[0]
	# Keep the geometry for a quick redo.
	_removed_cache[stroke.id] = [body_pieces, removed[1], stroke]
	_removed_order.append(stroke.id)
	while _removed_order.size() > REMOVED_CACHE_SIZE:
		_removed_cache.erase(_removed_order.pop_front())
	stroke_removed_visual.emit(view, body_pieces)
