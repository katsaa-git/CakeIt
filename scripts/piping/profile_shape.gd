class_name ProfileShape
extends RefCounted
## A tip cross-section ready for meshing: a closed loop of 2D points (in units
## of the tip radius) with normals and a shading value per point.
##
## Axes: x runs across the stroke, y points away from the cake surface. Points
## go counter-clockwise. The origin is the centre line of the stroke.

var points := PackedVector2Array()
var normals := PackedVector2Array()
## 0 on exposed ridges, up to 1 deep in grooves. Darkens grooves a little,
## like soft ambient occlusion baked into the frosting.
var shade := PackedFloat32Array()
## Per-point sideways offset used by ruffled tips (zero for most tips).
var wave := PackedVector2Array()
## Fraction of the way around the loop, for texture coordinates.
var around := PackedFloat32Array()
## A low-detail copy of the loop, used for collision shapes.
var coarse := PackedVector2Array()


func size() -> int:
	return points.size()


static func from_points(loop: PackedVector2Array, wave_offsets: PackedVector2Array = PackedVector2Array(), coarse_count: int = 8) -> ProfileShape:
	var shape := ProfileShape.new()
	var count: int = loop.size()
	shape.points = loop
	shape.normals.resize(count)
	shape.shade.resize(count)
	shape.around.resize(count)
	shape.wave = wave_offsets if wave_offsets.size() == count else PackedVector2Array()

	for j in range(count):
		var prev: Vector2 = loop[(j - 1 + count) % count]
		var next: Vector2 = loop[(j + 1) % count]
		var tangent: Vector2 = next - prev
		var n := Vector2(tangent.y, -tangent.x)
		shape.normals[j] = n.normalized() if n.length_squared() > 0.0 else Vector2.UP
		shape.around[j] = float(j) / float(count)

	# Concavity: how far a point sits inside the line between its neighbours.
	var reach: int = maxi(count / 16, 1)
	for j in range(count):
		var a: Vector2 = loop[(j - reach + count) % count]
		var b: Vector2 = loop[(j + reach) % count]
		var depth: float = (loop[j] - (a + b) * 0.5).dot(shape.normals[j])
		shape.shade[j] = clampf(-depth / 0.12, 0.0, 1.0)

	var step: float = float(count) / float(coarse_count)
	for k in range(coarse_count):
		shape.coarse.append(loop[int(float(k) * step) % count])
	return shape


## A plain circle, used by stamps and dots when no tip profile is given.
static func circle(sides: int, squash: float = 1.0) -> ProfileShape:
	var loop := PackedVector2Array()
	for j in range(sides):
		var a: float = TAU * float(j) / float(sides)
		loop.append(Vector2(cos(a), sin(a) * squash))
	return from_points(loop)
