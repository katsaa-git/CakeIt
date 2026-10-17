class_name CakeModel
extends RefCounted
## The whole cake as plain data: tiers (bottom to top), piped strokes and
## placed decorations. This is the gameplay side; meshes live in CakeView,
## which listens to the signals below. A future scoring system can read the
## tier list, the strokes (with tip ids and sizes) and the decorations (with
## their definitions' tags) straight from here.
##
## Never change these arrays directly from tools: go through a CakeCommand so
## the change can be undone.
##
## Coordinates: the cake frame has its origin at the centre of the stand's
## top surface. Each tier's local frame has its origin at the centre of that
## tier's bottom face. Items on the stand itself use BOARD_ID.

signal tiers_changed
signal tier_coat_changed(tier: TierData, animate: bool)
## A tier's lustre dust changed (in `rect` of its mask; empty = all of it).
signal tier_shimmer_changed(tier: TierData, rect: Rect2i)
signal stroke_added(stroke: StrokeData)
signal stroke_removed(stroke: StrokeData)
signal decoration_added(decoration: DecorationData)
signal decoration_removed(decoration: DecorationData)
## Everything was replaced (load or restore). Views should rebuild from scratch.
signal reset

const BOARD_ID: int = 0
const MAX_TIERS: int = 4

var tiers: Array[TierData] = []
var strokes: Array[StrokeData] = []
var decorations: Array[DecorationData] = []

var _next_id: int = 1


func new_id() -> int:
	var id: int = _next_id
	_next_id += 1
	return id


# --- Tiers -------------------------------------------------------------------

func tier_by_id(tier_id: int) -> TierData:
	for tier in tiers:
		if tier.id == tier_id:
			return tier
	return null


func tier_index(tier_id: int) -> int:
	for i in range(tiers.size()):
		if tiers[i].id == tier_id:
			return i
	return -1


## Height of the bottom of a tier in the cake frame (the board is at 0).
func tier_base_y(tier_id: int) -> float:
	var y: float = 0.0
	for tier in tiers:
		if tier.id == tier_id:
			return y
		y += tier.height
	return 0.0


func total_height() -> float:
	var y: float = 0.0
	for tier in tiers:
		y += tier.height
	return y


func can_add_tier() -> bool:
	return tiers.size() < MAX_TIERS


func insert_tier(index: int, tier: TierData) -> void:
	_bump_id(tier.id)
	tiers.insert(clampi(index, 0, tiers.size()), tier)
	tiers_changed.emit()


func remove_tier(tier_id: int) -> int:
	var index: int = tier_index(tier_id)
	if index >= 0:
		tiers.remove_at(index)
		tiers_changed.emit()
	return index


## Swaps in new size data for a tier (same id). Items are remapped by the
## command beforehand.
func replace_tier(tier: TierData) -> void:
	var index: int = tier_index(tier.id)
	if index < 0:
		return
	tiers[index] = tier
	tiers_changed.emit()


func set_coat(tier_id: int, color: Color, coated: bool, smoothness: float, animate: bool, shine: float = 0.0) -> void:
	var tier: TierData = tier_by_id(tier_id)
	if tier == null:
		return
	tier.coat_color = color
	tier.coated = coated
	tier.smoothness = smoothness
	tier.coat_shine = shine
	tier_coat_changed.emit(tier, animate)


## Puts a piece of a tier's dust mask back (`part` covers `rect`), or
## replaces the whole mask when `rect` is empty (`whole` may be null).
func set_shimmer(tier_id: int, rect: Rect2i, part: Image, whole: ShimmerMask = null) -> void:
	var tier: TierData = tier_by_id(tier_id)
	if tier == null:
		return
	if rect.has_area():
		tier.ensure_shimmer().put_region(rect, part)
	else:
		tier.shimmer = whole.duplicate_mask() if whole != null else null
	tier_shimmer_changed.emit(tier, rect)


# --- Strokes and decorations ------------------------------------------------

func add_stroke(stroke: StrokeData) -> void:
	_bump_id(stroke.id)
	# Keep creation order (by id) so undo and redo always give the same list.
	strokes.insert(_insert_index(strokes, stroke.id), stroke)
	stroke_added.emit(stroke)


func remove_stroke(stroke_id: int) -> StrokeData:
	for i in range(strokes.size()):
		if strokes[i].id == stroke_id:
			var stroke: StrokeData = strokes[i]
			strokes.remove_at(i)
			stroke_removed.emit(stroke)
			return stroke
	return null


func add_decoration(decoration: DecorationData) -> void:
	_bump_id(decoration.id)
	decorations.insert(_insert_index(decorations, decoration.id), decoration)
	decoration_added.emit(decoration)


func remove_decoration(decoration_id: int) -> DecorationData:
	for i in range(decorations.size()):
		if decorations[i].id == decoration_id:
			var decoration: DecorationData = decorations[i]
			decorations.remove_at(i)
			decoration_removed.emit(decoration)
			return decoration
	return null


func strokes_on(tier_id: int) -> Array[StrokeData]:
	var out: Array[StrokeData] = []
	for stroke in strokes:
		if stroke.tier_id == tier_id:
			out.append(stroke)
	return out


func decorations_on(tier_id: int) -> Array[DecorationData]:
	var out: Array[DecorationData] = []
	for decoration in decorations:
		if decoration.tier_id == tier_id:
			out.append(decoration)
	return out


func item_count() -> int:
	return strokes.size() + decorations.size()


# --- Whole-cake operations ----------------------------------------------------

## A fresh cake: one coated tier, nothing on it.
func make_default() -> void:
	tiers.clear()
	strokes.clear()
	decorations.clear()
	_next_id = 1
	var tier := TierData.new()
	tier.id = new_id()
	tier.radius = 1.3
	tier.height = 1.05
	tiers.append(tier)
	reset.emit()


## Replaces everything at once (used by load, clear and their undo).
func replace_all(new_tiers: Array[TierData], new_strokes: Array[StrokeData], new_decorations: Array[DecorationData]) -> void:
	tiers = new_tiers
	strokes = new_strokes
	decorations = new_decorations
	for tier in tiers:
		_bump_id(tier.id)
	for stroke in strokes:
		_bump_id(stroke.id)
	for decoration in decorations:
		_bump_id(decoration.id)
	reset.emit()


func _bump_id(id: int) -> void:
	if id >= _next_id:
		_next_id = id + 1


## Where an item with this id goes to keep the list sorted by id.
static func _insert_index(list: Array, id: int) -> int:
	var low: int = 0
	var high: int = list.size()
	while low < high:
		var middle: int = (low + high) / 2
		if int(list[middle].get("id")) < id:
			low = middle + 1
		else:
			high = middle
	return low
