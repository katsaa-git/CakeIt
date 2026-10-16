@tool
class_name RoseBuilder
extends DecorationBuilder
## A sugar rose: a tight bud wrapped by rings of cupped petals that open out
## and roll back at their edges. Petals are thin sheets with two sides.

## Overall radius of the open rose, in game units.
@export_range(0.03, 0.4) var size: float = 0.15

## [petals, ring radius, petal width, petal height, outward tilt] per ring,
## in units of `size` (tilt in radians).
const RINGS: Array = [
	[3, 0.04, 0.7, 0.8, 0.0],
	[4, 0.17, 0.85, 0.8, 0.1],
	[5, 0.32, 0.95, 0.74, 0.24],
	[6, 0.48, 1.0, 0.66, 0.4],
	[7, 0.62, 1.05, 0.56, 0.6],
]

const U_STEPS: int = 7
const V_STEPS: int = 6


func build() -> MeshArrays:
	var out := MeshArrays.new()
	for r in range(RINGS.size()):
		var ring: Array = RINGS[r]
		var count: int = ring[0]
		# Inner petals a touch deeper in colour.
		var shade: float = lerpf(0.82, 1.0, float(r) / float(RINGS.size() - 1))
		var color := Color(shade, shade, shade, 1.0)
		for i in range(count):
			var a: float = TAU * float(i) / float(count) + float(r) * 0.7
			_add_petal(out, a, float(ring[1]) * size, float(ring[2]) * size, float(ring[3]) * size, float(ring[4]), color)
	return out


func _add_petal(out: MeshArrays, angle: float, ring_radius: float, width: float, height: float, tilt: float, color: Color) -> void:
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var across: Vector3 = Vector3.UP.cross(outward)
	var up: Vector3 = Vector3.UP * cos(tilt) + outward * sin(tilt)
	var out_dir: Vector3 = across.cross(up)
	var origin: Vector3 = outward * ring_radius
	var sheet := PackedVector3Array()
	for v in range(V_STEPS + 1):
		var fv: float = float(v) / float(V_STEPS)
		for u in range(U_STEPS + 1):
			var fu: float = float(u) / float(U_STEPS) * 2.0 - 1.0
			# Narrow at the base, broad and round at the top like a real petal.
			var half: float = width * 0.5 * (0.4 + 0.6 * sin(minf(fv * 1.6, 1.0) * PI * 0.5))
			var y: float = fv * height * (1.0 - 0.32 * fu * fu)
			# Cupped round the bud; the outer, more open petals roll their top
			# edge back outward.
			var z: float = -fu * fu * width * 0.38 + pow(fv, 3.0) * height * 0.4 * minf(tilt * 1.4, 1.0)
			sheet.append(origin + across * fu * half + up * y + out_dir * z)
	var thickness: float = size * 0.02
	for side in [1.0, -1.0]:
		var start: int = out.vertex_count()
		for k in range(sheet.size()):
			out.add_vertex(sheet[k] - out_dir * thickness * (0.5 - 0.5 * side), out_dir * side, color, Vector2.ZERO)
		for v in range(V_STEPS):
			for u in range(U_STEPS):
				var a: int = start + v * (U_STEPS + 1) + u
				var b: int = a + 1
				var c: int = a + U_STEPS + 1
				var d: int = c + 1
				if side > 0.0:
					out.add_triangle(a, c, b)
					out.add_triangle(b, c, d)
				else:
					out.add_triangle(a, b, c)
					out.add_triangle(b, d, c)
		smooth_normals(out, start)


func radius() -> float:
	return size
