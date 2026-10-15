class_name CakeStack
extends Node3D
## The cake on its stand: a stack of tiers, each smaller than the one below.
## Piped strokes are children of this node too.
##
## Scale: 1 unit = 10 cm.

const TIER_RADII: Array[float] = [1.5, 1.1, 0.75]
const TIER_HEIGHT: float = 1.0

## Height of the stand's top surface, where the bottom tier sits.
var base_y: float = 0.0
var tier_material: Material


func tier_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is CakeTier:
			count += 1
	return count


func can_add_tier() -> bool:
	return tier_count() < TIER_RADII.size()


## Creates the next tier up (not yet attached, so adding it can be undone).
func create_tier() -> CakeTier:
	var index: int = tier_count()
	if index >= TIER_RADII.size():
		return null
	var tier := CakeTier.new()
	tier.setup(TIER_RADII[index], TIER_HEIGHT, tier_material)
	tier.position = Vector3(0.0, base_y + float(index) * TIER_HEIGHT, 0.0)
	return tier


func top_y() -> float:
	return base_y + float(tier_count()) * TIER_HEIGHT


func mid_y() -> float:
	return base_y + float(maxi(tier_count(), 1)) * TIER_HEIGHT * 0.5
