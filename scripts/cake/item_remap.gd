class_name ItemRemap
extends RefCounted
## Moves piping and decorations when their tier changes size, so they stay
## stuck to the frosting instead of floating or sinking.
##
## Points on the top move with the top (and spread with the radius); points on
## the side keep their distance from the surface and scale with the height.
## The surface normal decides how "top" or "side" a point is, so items on the
## rounded edge blend smoothly between the two.


static func remap_point(p: Vector3, normal: Vector3, old_tier: TierData, new_tier: TierData) -> Vector3:
	var radial := Vector2(p.x, p.z)
	var dist: float = radial.length()
	var dir: Vector2 = radial / dist if dist > 0.0001 else Vector2.ZERO
	var radius_ratio: float = new_tier.radius / maxf(old_tier.radius, 0.001)
	var height_ratio: float = new_tier.height / maxf(old_tier.height, 0.001)

	var top_radial: Vector2 = radial * radius_ratio
	var top := Vector3(top_radial.x, p.y + new_tier.height - old_tier.height, top_radial.y)

	var side_radial: Vector2 = dir * maxf(dist + new_tier.radius - old_tier.radius, 0.0)
	var side := Vector3(side_radial.x, p.y * height_ratio, side_radial.y)

	var top_weight: float = smoothstep(0.3, 0.8, normal.y)
	return side.lerp(top, top_weight)


static func remap_stroke(stroke: StrokeData, old_tier: TierData, new_tier: TierData) -> StrokeData:
	var copy: StrokeData = stroke.duplicate_data()
	for i in range(copy.points.size()):
		copy.points[i] = remap_point(copy.points[i], copy.normals[i], old_tier, new_tier)
	return copy


static func remap_decoration(decoration: DecorationData, old_tier: TierData, new_tier: TierData) -> DecorationData:
	var copy: DecorationData = decoration.duplicate_data()
	# Path decorations (drips) are stored as rim angles, so they adapt by themselves.
	if copy.path.is_empty():
		var normal: Vector3 = copy.transform.basis.y.normalized()
		copy.transform.origin = remap_point(copy.transform.origin, normal, old_tier, new_tier)
	return copy
