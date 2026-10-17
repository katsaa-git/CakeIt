class_name TierCommands
extends RefCounted
## Undoable tier changes: add, remove, resize, coat, plus "clear all".
## Kept together because they are small and closely related.


class AddTier extends CakeCommand:
	var tier: TierData
	var index: int

	func _init(new_tier: TierData, at_index: int) -> void:
		tier = new_tier
		index = at_index
		label = "Add tier"

	func execute(model: CakeModel) -> void:
		model.insert_tier(index, tier)

	func revert(model: CakeModel) -> void:
		model.remove_tier(tier.id)


class RemoveTier extends CakeCommand:
	var tier: TierData
	var index: int = -1
	var strokes: Array[StrokeData] = []
	var decorations: Array[DecorationData] = []

	func _init(model: CakeModel, tier_id: int) -> void:
		tier = model.tier_by_id(tier_id)
		strokes = model.strokes_on(tier_id)
		decorations = model.decorations_on(tier_id)
		label = "Remove tier"

	func execute(model: CakeModel) -> void:
		for stroke in strokes:
			model.remove_stroke(stroke.id)
		for decoration in decorations:
			model.remove_decoration(decoration.id)
		index = model.remove_tier(tier.id)

	func revert(model: CakeModel) -> void:
		model.insert_tier(index, tier)
		for stroke in strokes:
			model.add_stroke(stroke)
		for decoration in decorations:
			model.add_decoration(decoration)


## Changes a tier's radius and/or height. Items on the tier are moved so they
## stay on its surface; the originals are kept so undo is exact.
class ResizeTier extends CakeCommand:
	var old_tier: TierData
	var new_tier: TierData
	var old_strokes: Array[StrokeData] = []
	var new_strokes: Array[StrokeData] = []
	var old_decorations: Array[DecorationData] = []
	var new_decorations: Array[DecorationData] = []

	func _init(model: CakeModel, tier_id: int, radius: float, height: float) -> void:
		old_tier = model.tier_by_id(tier_id)
		new_tier = old_tier.duplicate_data()
		new_tier.radius = radius
		new_tier.height = height
		old_strokes = model.strokes_on(tier_id)
		old_decorations = model.decorations_on(tier_id)
		for stroke in old_strokes:
			new_strokes.append(ItemRemap.remap_stroke(stroke, old_tier, new_tier))
		for decoration in old_decorations:
			new_decorations.append(ItemRemap.remap_decoration(decoration, old_tier, new_tier))
		label = "Resize tier"

	func execute(model: CakeModel) -> void:
		_swap(model, old_strokes, old_decorations, new_tier, new_strokes, new_decorations)

	func revert(model: CakeModel) -> void:
		_swap(model, new_strokes, new_decorations, old_tier, old_strokes, old_decorations)

	func _swap(model: CakeModel, out_strokes: Array[StrokeData], out_decorations: Array[DecorationData],
			tier: TierData, in_strokes: Array[StrokeData], in_decorations: Array[DecorationData]) -> void:
		for stroke in out_strokes:
			model.remove_stroke(stroke.id)
		for decoration in out_decorations:
			model.remove_decoration(decoration.id)
		model.replace_tier(tier)
		for stroke in in_strokes:
			model.add_stroke(stroke)
		for decoration in in_decorations:
			model.add_decoration(decoration)


class CoatTier extends CakeCommand:
	var tier_id: int
	var old_color: Color
	var old_coated: bool
	var old_smoothness: float
	var old_shine: float
	var new_color: Color
	var new_coated: bool
	var new_smoothness: float
	var new_shine: float
	var animate: bool = true

	func _init(model: CakeModel, id: int, color: Color, coated: bool, smoothness: float, with_animation: bool = true, shine: float = -1.0) -> void:
		animate = with_animation
		tier_id = id
		var tier: TierData = model.tier_by_id(id)
		old_color = tier.coat_color
		old_coated = tier.coated
		old_smoothness = tier.smoothness
		old_shine = tier.coat_shine
		new_color = color
		new_coated = coated
		new_smoothness = smoothness
		# A negative shine keeps the coat's finish (smoothing does not change it).
		new_shine = shine if shine >= 0.0 else tier.coat_shine
		label = "Frosting coat" if with_animation else "Smoothing"

	func execute(model: CakeModel) -> void:
		model.set_coat(tier_id, new_color, new_coated, new_smoothness, animate, new_shine)

	func revert(model: CakeModel) -> void:
		model.set_coat(tier_id, old_color, old_coated, old_smoothness, animate, old_shine)


## One press of the dust brush on one tier: the changed part of its dust
## mask, before and after.
class PaintShimmer extends CakeCommand:
	var tier_id: int
	var rect: Rect2i
	var before: Image
	var after: Image

	func _init(id: int, changed: Rect2i, old_part: Image, new_part: Image, erasing: bool = false) -> void:
		tier_id = id
		rect = changed
		before = old_part
		after = new_part
		label = "Brushing off dust" if erasing else "Lustre dust"

	func execute(model: CakeModel) -> void:
		model.set_shimmer(tier_id, rect, after)

	func revert(model: CakeModel) -> void:
		model.set_shimmer(tier_id, rect, before)


## Removes all piping, decorations and lustre dust but keeps the tiers and
## their coats.
class ClearAll extends CakeCommand:
	var strokes: Array[StrokeData] = []
	var decorations: Array[DecorationData] = []
	## tier id -> its dust mask before clearing
	var dust: Dictionary = {}

	func _init(model: CakeModel) -> void:
		strokes = model.strokes.duplicate()
		decorations = model.decorations.duplicate()
		for tier in model.tiers:
			if tier.has_shimmer():
				dust[tier.id] = tier.shimmer.duplicate_mask()
		label = "Clear all"

	func execute(model: CakeModel) -> void:
		for tier in model.tiers:
			tier.shimmer = null
		model.replace_all(model.tiers, [] as Array[StrokeData], [] as Array[DecorationData])

	func revert(model: CakeModel) -> void:
		for tier in model.tiers:
			var mask: ShimmerMask = dust.get(tier.id)
			tier.shimmer = mask.duplicate_mask() if mask != null else null
		model.replace_all(model.tiers, strokes.duplicate(), decorations.duplicate())
