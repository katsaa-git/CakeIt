class_name TierShape
extends RefCounted
## How to build one kind of tier (round today; square and heart later).
## Everything that depends on the tier's outline goes through here, so a new
## shape is one new subclass registered in `get_shape()`.

static var _shapes: Dictionary = {}


static func get_shape(shape_id: StringName) -> TierShape:
	if _shapes.is_empty():
		_shapes[&"round"] = RoundTierShape.new()
	return _shapes.get(shape_id, _shapes[&"round"])


## The visible tier mesh, in tier-local space (origin at the bottom centre).
func build_mesh(_tier: TierData) -> ArrayMesh:
	return null


## Collision shape matching the visible surface.
func build_collision(_tier: TierData) -> Shape3D:
	return null


## Point on the top outer edge at `angle` (radians), and the outward normal there.
func rim_point(_tier: TierData, _angle: float) -> Array:
	return [Vector3.ZERO, Vector3.UP]


## Point on the side at `angle` and height `y`, plus its outward normal.
func side_point(_tier: TierData, _angle: float, _y: float) -> Array:
	return [Vector3.ZERO, Vector3.RIGHT]


## Radius of the softened edges.
func edge_radius(tier: TierData) -> float:
	return minf(0.055, tier.height * 0.12)
