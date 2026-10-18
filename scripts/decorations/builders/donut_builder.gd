@tool
class_name DonutBuilder
extends DecorationBuilder
## A mini donut: a golden ring of dough with a glossy glaze over its top in
## the picked colour, dripping a little at the edge, and a scatter of tiny
## rainbow sprinkles.

## Outer width, in game units (0.36 = 3.6 cm).
@export_range(0.1, 0.8) var size: float = 0.36
@export var dough: Color = Color(0.84, 0.58, 0.32)
@export var sprinkles: bool = true

const AROUND: int = 40
const TUBE: int = 16


func radius() -> float:
	return size * 0.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var ring: float = size * 0.32
	var tube: float = size * 0.17
	_torus(out, ring, tube, -PI, PI, Color(dough.r, dough.g, dough.b, 0.0), 0.0, 0.0)
	# The glaze covers the top of the tube and a wavy bit of its sides.
	_torus(out, ring, tube, -0.3, PI + 0.3, TINTABLE, 0.35, size * 0.008)
	if sprinkles:
		var colours: Array[Color] = [Color(0.96, 0.52, 0.64), Color(0.52, 0.76, 0.95), Color(0.99, 0.86, 0.4), Color(0.6, 0.85, 0.62), Color(1.0, 1.0, 1.0)]
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		for k in range(18):
			var u: float = rng.randf() * TAU
			var v: float = rng.randf_range(0.5, PI - 0.5)
			var radial := Vector3(cos(u), 0.0, sin(u))
			var n: Vector3 = radial * cos(v) + Vector3.UP * sin(v)
			var p: Vector3 = radial * ring + n * (tube + size * 0.016) + Vector3(0.0, tube, 0.0)
			var along: Vector3 = n.cross(Vector3(cos(rng.randf() * TAU), 0.3, sin(rng.randf() * TAU))).normalized()
			var c: Color = colours[k % colours.size()]
			add_tube(out, PackedVector3Array([p - along * size * 0.022, p + along * size * 0.022]), PackedFloat32Array([size * 0.009, size * 0.009]), Color(c.r, c.g, c.b, 0.0), 5)
	return out


## Part of a torus lying flat (its bottom on the cake), from `v0` to `v1`
## round the tube (0 outside, PI/2 on top, PI inside). `wave` makes the
## lower edges wavy like a dripping glaze; `lift` pushes it outward.
func _torus(out: MeshArrays, ring: float, tube: float, v0: float, v1: float, color: Color, wave: float, lift: float) -> void:
	var start: int = out.vertex_count()
	for i in range(AROUND + 1):
		var u: float = TAU * float(i) / float(AROUND)
		var drip: float = wave * (0.5 + 0.5 * sin(u * 7.0)) * (0.6 + 0.4 * sin(u * 3.0 + 1.0))
		var radial := Vector3(cos(u), 0.0, sin(u))
		for j in range(TUBE + 1):
			var f: float = float(j) / float(TUBE)
			var v: float = lerpf(v0 - drip, v1 + drip, f)
			var n: Vector3 = radial * cos(v) + Vector3.UP * sin(v)
			out.add_vertex(radial * ring + n * (tube + lift) + Vector3(0.0, tube, 0.0), n, color, Vector2(float(i) / float(AROUND), f))
	for i in range(AROUND):
		for j in range(TUBE):
			var a: int = start + i * (TUBE + 1) + j
			var b: int = a + TUBE + 1
			out.add_triangle(a, b, a + 1)
			out.add_triangle(a + 1, b, b + 1)
