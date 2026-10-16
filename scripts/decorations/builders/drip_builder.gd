@tool
class_name DripBuilder
extends DecorationBuilder
## Ganache drip: a glossy pool along a tier's top edge that rolls over the
## rim and runs down the side in drips of different lengths, each ending in
## a rounder drop. Built per decoration from the tier's size and the rim
## angles the player dragged across (`DecorationData.path`: start and end,
## radians, unwrapped), so it always fits the tier, even after resizing.

## How far in from the edge the pool on top reaches, in game units.
@export_range(0.05, 1.0) var pool_width: float = 0.24
@export_range(0.01, 0.1) var thickness: float = 0.03
## Distance between drips along the edge, in game units.
@export_range(0.05, 0.5) var drip_spacing: float = 0.15
@export_range(0.05, 1.0) var drip_min: float = 0.12
@export_range(0.05, 1.5) var drip_max: float = 0.45
@export_range(0.01, 0.15) var drip_width: float = 0.05


func is_unique() -> bool:
	return true


func radius() -> float:
	return 0.1


## The start and end angle covered by a path (end > start).
static func span(path: PackedFloat32Array) -> Vector2:
	if path.is_empty():
		return Vector2(0.0, 0.0)
	var start: float = path[0]
	var end: float = path[path.size() - 1]
	if end < start:
		var swap: float = start
		start = end
		end = swap
	return Vector2(start, minf(end, start + TAU))


func build_unique(decoration: DecorationData, tier: TierData) -> MeshArrays:
	var out := MeshArrays.new()
	if tier == null:
		return out
	var color := Color(decoration.color.r, decoration.color.g, decoration.color.b, 0.0)
	var range_angles: Vector2 = span(decoration.path)
	var full: bool = range_angles.y - range_angles.x >= TAU - 0.001
	_build_pool(out, tier, range_angles, color, full)
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration.rng_seed
	var arc: float = (range_angles.y - range_angles.x) * tier.radius
	var count: int = maxi(int(arc / drip_spacing), 1)
	for k in range(count):
		var t: float = (float(k) + 0.5) / float(count) if not full else float(k) / float(count)
		var angle: float = range_angles.x + (range_angles.y - range_angles.x) * t + rng.randf_range(-0.3, 0.3) * drip_spacing / tier.radius
		var length: float = rng.randf_range(drip_min, drip_max)
		# Every few drips a short one, like real ganache.
		if rng.randf() < 0.3:
			length *= 0.45
		length = minf(length, tier.height * 0.8)
		_build_drip(out, tier, angle, length, drip_width * rng.randf_range(0.8, 1.2), color)
	return out


func _build_pool(out: MeshArrays, tier: TierData, angles: Vector2, color: Color, full: bool) -> void:
	var r: float = tier.radius
	var h: float = tier.height
	var th: float = thickness
	# Poured all the way round, the ganache covers the whole top; a partial
	# drip only spreads a band in from the edge.
	var reach: float = r if full else minf(pool_width, r)
	# Walking up the side, over the rim and in across the top (like a lathe
	# profile, so the outside faces out).
	var points := PackedVector2Array([
		Vector2(r + 0.002, h - 0.07), Vector2(r + th * 0.55, h - 0.045), Vector2(r + th * 0.75, h - 0.015),
		Vector2(r + th * 0.55, h + th * 0.45), Vector2(r - 0.02, h + th), Vector2(r - reach * 0.5, h + th * 0.75),
		Vector2(r - reach * 0.85, h + th * 0.6), Vector2(r - reach, h + th * (0.55 if full else 0.05)),
	])
	var profile: Dictionary = LatheMesh.smooth_profile(points)
	var normals: PackedVector2Array = profile["normals"]
	var segments: int = maxi(int((angles.y - angles.x) * r / 0.025), 4)
	var stride: int = segments + 1
	for i in range(points.size()):
		for j in range(stride):
			var a: float = lerpf(angles.x, angles.y, float(j) / float(segments))
			var c: float = cos(a)
			var s: float = sin(a)
			out.add_vertex(Vector3(points[i].x * c, points[i].y, points[i].x * s), Vector3(normals[i].x * c, normals[i].y, normals[i].x * s).normalized(), color, Vector2(float(j) / float(segments), float(i)))
	for i in range(points.size() - 1):
		for j in range(segments):
			var a: int = i * stride + j
			out.add_triangle(a, a + 1, a + stride)
			out.add_triangle(a + 1, a + stride + 1, a + stride)


func _build_drip(out: MeshArrays, tier: TierData, angle: float, length: float, width: float, color: Color) -> void:
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var profile := ProfileShape.circle(10, 0.6)
	var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, color, 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var rings: int = 12
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var s: float = width * 0.5 * (0.8 + 0.4 * smoothstep(0.55, 0.9, t))
		if t > 0.9:
			s *= cos((t - 0.9) / 0.1 * PI * 0.5)
		s = maxf(s, width * 0.02)
		centers.append(outward * (tier.radius + s * 0.25) + Vector3(0.0, tier.height - 0.03 - length * t, 0.0))
		ups.append(outward)
		scales.append(s)
	TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)
