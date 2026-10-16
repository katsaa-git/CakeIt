class_name Content
extends RefCounted
## Finds and caches all content Resources in data/: piping tips, decorations,
## tier presets and colour palettes. New content is picked up automatically
## just by dropping a .tres file into the right folder.

const TIPS_DIR: String = "res://data/tips/"
const DECORATIONS_DIR: String = "res://data/decorations/"
const TIER_PRESETS_DIR: String = "res://data/tiers/"
const PALETTES_DIR: String = "res://data/palettes/"

static var _tips: Array[TipDefinition] = []
static var _tips_by_id: Dictionary = {}
static var _decorations: Array[Resource] = []
static var _decorations_by_id: Dictionary = {}
static var _tier_presets: Array[Resource] = []
static var _palettes: Dictionary = {}


static func tips() -> Array[TipDefinition]:
	if _tips.is_empty():
		for res in _load_all(TIPS_DIR):
			if res is TipDefinition:
				_tips.append(res)
		_tips.sort_custom(func(a: TipDefinition, b: TipDefinition) -> bool: return a.sort_order < b.sort_order)
		for tip in _tips:
			_tips_by_id[tip.id] = tip
	return _tips


static func tip(id: StringName) -> TipDefinition:
	tips()
	var found: TipDefinition = _tips_by_id.get(id)
	if found == null and not _tips.is_empty():
		push_warning("Unknown tip '%s', using '%s' instead" % [id, _tips[0].id])
		return _tips[0]
	return found


## Decoration definitions, sorted by category (shelf tab order) then order.
static func decorations() -> Array[Resource]:
	if _decorations.is_empty():
		for res in _load_all(DECORATIONS_DIR):
			if res.has_method("validate") and "category" in res:
				_decorations.append(res)
		_decorations.sort_custom(func(a: Resource, b: Resource) -> bool:
			var rank_a: int = _category_rank(a.get("category"))
			var rank_b: int = _category_rank(b.get("category"))
			if rank_a != rank_b:
				return rank_a < rank_b
			return a.get("sort_order") < b.get("sort_order"))
		for deco in _decorations:
			_decorations_by_id[deco.get("id")] = deco
	return _decorations


static func _category_rank(category: StringName) -> int:
	for i in range(DecorationDefinition.CATEGORIES.size()):
		if DecorationDefinition.CATEGORIES[i][0] == category:
			return i
	return DecorationDefinition.CATEGORIES.size()


static func decoration(id: StringName) -> Resource:
	decorations()
	return _decorations_by_id.get(id)


static func tier_presets() -> Array[Resource]:
	if _tier_presets.is_empty():
		_tier_presets = _load_all(TIER_PRESETS_DIR)
		_tier_presets.sort_custom(func(a: Resource, b: Resource) -> bool: return a.get("sort_order") < b.get("sort_order"))
	return _tier_presets


static func palette(id: StringName) -> Resource:
	if _palettes.is_empty():
		for res in _load_all(PALETTES_DIR):
			_palettes[res.get("id")] = res
	return _palettes.get(id)


## Forgets everything loaded (used by tests and before quitting).
static func clear_cache() -> void:
	_tips.clear()
	_tips_by_id.clear()
	_decorations.clear()
	_decorations_by_id.clear()
	_tier_presets.clear()
	_palettes.clear()


## Loads every .tres in a folder (works in exported builds too).
static func _load_all(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files: PackedStringArray = ResourceLoader.list_directory(dir)
	var sorted: Array = Array(files)
	sorted.sort()
	for file: String in sorted:
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res: Resource = load(dir + file)
		if res != null:
			out.append(res)
		else:
			push_warning("Could not load content file " + dir + file)
	return out
