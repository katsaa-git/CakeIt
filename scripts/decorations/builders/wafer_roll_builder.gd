@tool
class_name WaferRollBuilder
extends DecorationBuilder
## A rolled wafer stick (like a Pirouline), stood up in the top of the cake:
## golden wafer with chocolate spiralling round it, and the rolled layers
## showing at its open end.

## Length of the roll, in game units (0.7 = 7 cm).
@export_range(0.2, 1.5) var length: float = 0.7
@export_range(0.02, 0.15) var thickness: float = 0.05
@export var wafer: Color = Color(0.9, 0.72, 0.46)
@export var chocolate: Color = Color(0.36, 0.21, 0.13)
## Turns of the chocolate spiral along the roll.
@export_range(0.0, 12.0) var turns: float = 5.0

const SEGMENTS: int = 20
const RINGS: int = 40
## How far below its origin it starts (the decoration's `sink` pushes it in).
const SINK: float = 0.0


func radius() -> float:
	return thickness * 1.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var r: float = thickness * 0.5
	for i in range(RINGS + 1):
		var t: float = float(i) / float(RINGS)
		var y: float = -SINK + t * length
		for j in range(SEGMENTS + 1):
			var a: float = TAU * float(j) / float(SEGMENTS)
			var n := Vector3(cos(a), 0.0, sin(a))
			var stripe: float = fposmod(a / TAU + t * turns, 1.0)
			var c: Color = chocolate if stripe < 0.38 else wafer
			out.add_vertex(n * r + Vector3(0.0, y, 0.0), n, Color(c.r, c.g, c.b, 0.0), Vector2(float(j) / float(SEGMENTS), t))
	for i in range(RINGS):
		for j in range(SEGMENTS):
			var a: int = i * (SEGMENTS + 1) + j
			out.add_triangle(a, a + 1, a + SEGMENTS + 1)
			out.add_triangle(a + 1, a + SEGMENTS + 2, a + SEGMENTS + 1)
	# The open end: rings of rolled wafer, darker between the layers.
	var top: float = length - SINK
	var cap := PackedVector2Array([Vector2(r, top), Vector2(r * 0.66, top), Vector2(r * 0.4, top - 0.002), Vector2(0.0, top - 0.004)])
	var profile := {"points": cap, "normals": PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 1.0)])}
	var end_piece: MeshArrays = LatheMesh.build_arrays(profile["points"], profile["normals"], SEGMENTS, Callable(), 0, Color(wafer.r * 0.8, wafer.g * 0.75, wafer.b * 0.7, 0.0))
	out.append(end_piece)
	return out
