@tool
class_name RopeProfile
extends TipProfile
## A rope tip: the outline of a few round strands pressed together, with
## sharp creases between them. With the tip's `twist_rate` the strands
## spiral round each other along the line, like a twisted rope.

## Number of strands.
@export_range(2, 6) var strands: int = 3
## How far each strand's centre sits from the middle, as a fraction of the
## radius (bigger makes deeper creases).
@export_range(0.1, 0.7) var strand_offset: float = 0.42
## Below 1 the rope settles slightly flatter against the cake.
@export_range(0.5, 1.2) var squash: float = 0.95


func make_loop(count: int) -> PackedVector2Array:
	var strand_radius: float = 1.0 - strand_offset
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		var u := Vector2(cos(a), sin(a))
		# Distance to the outline along this direction: the farthest point of
		# any strand circle the ray passes through.
		var reach: float = 0.0
		for k in range(strands):
			var phi: float = TAU * float(k) / float(strands) + PI * 0.5
			var c := Vector2(cos(phi), sin(phi)) * strand_offset
			var b: float = u.dot(c)
			var disc: float = strand_radius * strand_radius - (c.length_squared() - b * b)
			if disc >= 0.0:
				reach = maxf(reach, b + sqrt(disc))
		loop.append(Vector2(u.x * reach, u.y * reach * squash))
	return loop
