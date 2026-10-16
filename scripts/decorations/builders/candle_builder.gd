@tool
class_name CandleBuilder
extends DecorationBuilder
## A birthday candle: a slim wax stick with spiral stripes in the picked
## colour, a wick, and a flame (drawn by the decoration layer).

@export_range(0.01, 0.1) var candle_radius: float = 0.028
@export_range(0.1, 1.0) var height: float = 0.5
## Number of spiral stripes.
@export_range(0, 6) var stripes: int = 2
## How many turns the stripes make from bottom to top.
@export_range(0.0, 4.0) var turns: float = 1.6

const SEGMENTS: int = 32
const RINGS: int = 24


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var wax := Color(1.0, 0.98, 0.94, 0.0)
	for i in range(RINGS + 1):
		var y: float = height * float(i) / float(RINGS)
		for j in range(SEGMENTS + 1):
			var a: float = TAU * float(j) / float(SEGMENTS)
			var n := Vector3(cos(a), 0.0, sin(a))
			var stripe: float = fposmod(a / TAU * float(stripes) + y / height * turns, 1.0)
			var color: Color = TINTABLE if stripes > 0 and stripe < 0.42 else wax
			out.add_vertex(n * candle_radius + Vector3(0.0, y, 0.0), n, color, Vector2(float(j) / float(SEGMENTS), y / height))
	for i in range(RINGS):
		for j in range(SEGMENTS):
			var a: int = i * (SEGMENTS + 1) + j
			out.add_triangle(a, a + 1, a + SEGMENTS + 1)
			out.add_triangle(a + 1, a + SEGMENTS + 2, a + SEGMENTS + 1)
	# A slightly domed top.
	var cap_profile: Dictionary = LatheMesh.smooth_profile(PackedVector2Array([Vector2(candle_radius, height), Vector2(candle_radius * 0.7, height + 0.006), Vector2(0.0, height + 0.008)]))
	out.append(LatheMesh.build_arrays(cap_profile["points"], cap_profile["normals"], SEGMENTS, Callable(), 0, wax))
	var wick: Dictionary = LatheMesh.rounded_cylinder_profile(0.004, 0.045, 0.002, 2)
	var wick_arrays: MeshArrays = LatheMesh.build_arrays(wick["points"], wick["normals"], 8, Callable(), 0, Color(0.22, 0.17, 0.13, 0.0))
	add_transformed(out, wick_arrays, Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.0)))
	return out


func radius() -> float:
	return candle_radius * 1.5


func flame_offset() -> Vector3:
	return Vector3(0.0, height + 0.085, 0.0)
