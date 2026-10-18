@tool
class_name SliceBuilder
extends DecorationBuilder
## A thin round slice of fruit lying flat: citrus (orange, lemon, lime) with
## juicy segments, white pith and a rind, or kiwi with its pale core, ring
## of black seeds and fuzzy brown edge. All its colours are its own.

enum Style { CITRUS, KIWI }

@export var style: Style = Style.CITRUS
## Radius of the slice, in game units (0.26 = a 5 cm wide slice).
@export_range(0.05, 0.5) var size: float = 0.26
@export_range(0.01, 0.1) var thickness: float = 0.035
## Citrus segments.
@export_range(6, 14) var segments: int = 10
@export var flesh: Color = Color(1.0, 0.6, 0.16)
@export var rind: Color = Color(0.98, 0.5, 0.08)
@export var pith: Color = Color(1.0, 0.95, 0.84)

const RINGS: Array = [0.0, 0.06, 0.12, 0.3, 0.5, 0.7, 0.83, 0.87, 0.92, 0.96, 1.0]


func radius() -> float:
	return size


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var edge := Color(rind.r, rind.g, rind.b, 0.0)
	if style == Style.KIWI:
		edge = Color(0.5, 0.38, 0.22, 0.0)
	# Underside and rind: a short, soft-edged drum (its top is built below).
	var e: float = thickness * 0.35
	var drum := PackedVector2Array([Vector2(0.0, 0.0), Vector2(size - e, 0.0), Vector2(size - e * 0.3, e * 0.3), Vector2(size, e), Vector2(size, thickness - e), Vector2(size - e * 0.3, thickness - e * 0.3), Vector2(size - e, thickness)])
	add_lathe(out, drum, edge, 48)
	_top(out)
	if style == Style.KIWI:
		_seeds(out)
	return out


## The cut top: rings out from the middle, several points per segment so
## the thin membranes between segments show as pale lines.
func _top(out: MeshArrays) -> void:
	var angles := PackedFloat32Array()
	var membrane := PackedByteArray()
	var count: int = segments if style == Style.CITRUS else 12
	for s in range(count):
		var base: float = TAU * float(s) / float(count)
		var width: float = TAU / float(count)
		for f in [0.0, 0.07, 0.3, 0.5, 0.7, 0.93]:
			angles.append(base + width * float(f))
			membrane.append(1 if f == 0.0 else 0)
	var columns: int = angles.size()
	var start: int = out.vertex_count()
	for r: float in RINGS:
		for j in range(columns + 1):
			var a: float = angles[j % columns]
			var on_membrane: bool = membrane[j % columns] == 1
			var color: Color = _color(r, on_membrane, a)
			var lift: float = 0.0
			if style == Style.CITRUS and r > 0.1 and r < 0.84 and not on_membrane:
				# Each segment's flesh swells a little, glossy with juice.
				lift = thickness * 0.12 * sin((r - 0.1) / 0.74 * PI)
			var reach: float = r * (size - thickness * 0.35)
			var p := Vector3(cos(a) * reach, thickness + lift, sin(a) * reach)
			out.add_vertex(p, Vector3.UP, color, Vector2(float(j) / float(columns), r))
	for i in range(RINGS.size() - 1):
		for j in range(columns):
			var a: int = start + i * (columns + 1) + j
			var b: int = a + columns + 1
			out.add_triangle(a, b, a + 1)
			out.add_triangle(a + 1, b, b + 1)
	smooth_normals(out, start)


func _color(r: float, on_membrane: bool, angle: float) -> Color:
	var c: Color
	if style == Style.KIWI:
		var green := Color(0.47, 0.72, 0.2)
		var core := Color(0.95, 0.93, 0.76)
		c = core.lerp(green, smoothstep(0.2, 0.42, r))
		# Pale rays out from the core.
		if r > 0.3 and r < 0.9:
			c = c.lerp(core, 0.18 * (0.5 + 0.5 * cos(angle * 24.0)))
		c = c.lerp(Color(0.6, 0.62, 0.22), smoothstep(0.9, 0.97, r))
		if r >= 0.99:
			c = Color(0.5, 0.38, 0.22)
	else:
		if r < 0.08:
			c = pith
		elif r < 0.84:
			c = flesh.lerp(flesh.lightened(0.18), smoothstep(0.5, 0.82, r))
			if on_membrane:
				c = c.lerp(pith, 0.7)
		elif r < 0.9:
			c = pith
		else:
			c = rind
	return Color(c.r, c.g, c.b, 0.0)


## Tiny black seeds in a ring round the kiwi's core.
func _seeds(out: MeshArrays) -> void:
	var seed_color := Color(0.08, 0.06, 0.05, 0.0)
	var count: int = 34
	for k in range(count):
		var a: float = TAU * float(k) / float(count) + 0.11 * sin(float(k) * 3.7)
		var r: float = size * (0.34 + 0.05 * sin(float(k) * 2.3))
		var outward := Vector3(cos(a), 0.0, sin(a))
		var basis := Basis(Vector3.UP.cross(outward), Vector3.UP, outward)
		add_blob(out, Transform3D(basis, outward * r + Vector3(0.0, thickness * 1.02, 0.0)), 1.0, seed_color, Vector3(size * 0.012, size * 0.006, size * 0.024), 3, 6)
