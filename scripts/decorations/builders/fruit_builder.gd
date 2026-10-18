@tool
class_name FruitBuilder
extends DecorationBuilder
## Fresh fruit for the top of a cake:
##   STRAWBERRY       a whole berry standing on its green hull, with seeds;
##   STRAWBERRY_HALF  a halved berry lying cut side up (red rim, pale core);
##   FIG_HALF         a halved fig, purple skin round a pink, seedy middle;
##   GRAPES           a small bunch lying on its side, with a stem.
## The skin (or each grape) takes the piece's colour; cut faces, seeds,
## hulls and stems keep their own.

enum Kind { STRAWBERRY, STRAWBERRY_HALF, FIG_HALF, GRAPES }

@export var kind: Kind = Kind.STRAWBERRY
## Length of the fruit (or of the bunch), in game units (0.3 = 3 cm).
@export_range(0.05, 0.8) var size: float = 0.3

const LEAF_GREEN := Color(0.33, 0.55, 0.24, 0.0)
const SEED_GOLD := Color(0.96, 0.82, 0.42, 0.0)

## Strawberry outline: (radius, height) from the hull to the tip, as
## fractions of the length.
const BERRY: Array = [[0.0, 0.0], [0.3, 0.03], [0.41, 0.15], [0.43, 0.3], [0.4, 0.48], [0.32, 0.66], [0.2, 0.84], [0.08, 0.96], [0.0, 1.0]]
## Fig outline: round at the bottom, drawn up into a neck.
const FIG: Array = [[0.0, 0.0], [0.3, 0.05], [0.42, 0.22], [0.43, 0.42], [0.35, 0.6], [0.22, 0.76], [0.12, 0.9], [0.06, 1.0], [0.0, 1.02]]


func build() -> MeshArrays:
	var out := MeshArrays.new()
	match kind:
		Kind.STRAWBERRY:
			_whole_strawberry(out)
		Kind.STRAWBERRY_HALF:
			_half(out, BERRY, Callable(self, "_berry_face"))
			_hull(out, Vector3(0.0, size * 0.36, -size * 0.43), Vector3.FORWARD, 5, 0.6)
		Kind.FIG_HALF:
			_half(out, FIG, Callable(self, "_fig_face"))
			add_tube(out, PackedVector3Array([Vector3(0.0, size * 0.3, size * 0.5), Vector3(0.0, size * 0.33, size * 0.58), Vector3(0.0, size * 0.38, size * 0.62)]), PackedFloat32Array([size * 0.03, size * 0.025, size * 0.022]), Color(0.42, 0.36, 0.22, 0.0), 6)
		Kind.GRAPES:
			_grapes(out)
	return out


func radius() -> float:
	return size * 0.45


static func _outline_radius(outline: Array, t: float) -> float:
	for i in range(1, outline.size()):
		var a: Array = outline[i - 1]
		var b: Array = outline[i]
		if t <= float(b[1]):
			var f: float = (t - float(a[1])) / maxf(float(b[1]) - float(a[1]), 0.0001)
			return lerpf(float(a[0]), float(b[0]), clampf(f, 0.0, 1.0))
	return 0.0


func _whole_strawberry(out: MeshArrays) -> void:
	var points := PackedVector2Array()
	for p: Array in BERRY:
		points.append(Vector2(float(p[0]), float(p[1])) * size)
	# A berry is never perfectly round: it is a little wider one way.
	add_lathe(out, points, TINTABLE, 28, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.92)), Vector3(0.0, size * 0.02, 0.0)))
	# Seeds in little rows round the berry.
	var count: int = 46
	for k in range(count):
		var t: float = lerpf(0.12, 0.9, float(k) / float(count - 1))
		var r: float = _outline_radius(BERRY, t) * size
		var a: float = float(k) * 2.39996
		var n := Vector3(cos(a), 0.25, sin(a) * 0.92).normalized()
		var spot := Vector3(cos(a) * r, t * size + size * 0.02, sin(a) * r * 0.92)
		var turn := Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
		add_blob(out, Transform3D(turn, spot - n * size * 0.004), 1.0, SEED_GOLD, Vector3(size * 0.016, size * 0.009, size * 0.009), 3, 5)
	_hull(out, Vector3(0.0, size * 0.03, 0.0), Vector3.DOWN, 7, 1.0)


## Green sepals spreading from `center` (pointing out and toward `toward`).
func _hull(out: MeshArrays, center: Vector3, toward: Vector3, count: int, spread: float) -> void:
	for k in range(count):
		var a: float = TAU * float(k) / float(count) + 0.3
		var outward := Vector3(cos(a), 0.0, sin(a))
		var direction: Vector3 = (outward * spread + toward * 0.35).normalized()
		var basis := Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
		add_blob(out, Transform3D(basis, center + direction * size * 0.09), 1.0, LEAF_GREEN, Vector3(size * 0.045, size * 0.012, size * 0.1), 4, 8)
	add_sphere(out, center, size * 0.05, LEAF_GREEN, 5, 8, Vector3(1.0, 0.6, 1.0))


## A fruit cut lengthways, lying on its rounded back with the cut face up.
## `outline` is the fruit's (radius, length) profile; `face` colours the cut
## face from (across 0..1, along 0..1).
func _half(out: MeshArrays, outline: Array, face: Callable) -> void:
	var rows: int = 14
	var around: int = 10
	var top: float = 0.42 * size
	var start: int = out.vertex_count()
	# The skin: half a lathe round the long axis (Z), below the cut.
	for i in range(rows + 1):
		var t: float = float(i) / float(rows)
		var r: float = _outline_radius(outline, t) * size
		for j in range(around + 1):
			var phi: float = PI + PI * float(j) / float(around)
			var n := Vector3(cos(phi), sin(phi), 0.0)
			out.add_vertex(Vector3(cos(phi) * r, top + sin(phi) * r * 0.92, (t - 0.45) * size), n, TINTABLE, Vector2(t, float(j) / float(around)))
	for i in range(rows):
		for j in range(around):
			var a: int = start + i * (around + 1) + j
			var b: int = a + around + 1
			out.add_triangle(a, b, a + 1)
			out.add_triangle(a + 1, b, b + 1)
	smooth_normals(out, start)
	# The cut face, a grid across the fruit, coloured by the cut pattern.
	var across: int = 10
	var face_start: int = out.vertex_count()
	for i in range(rows + 1):
		var t: float = float(i) / float(rows)
		var r: float = _outline_radius(outline, t) * size
		for j in range(across + 1):
			var s: float = float(j) / float(across) * 2.0 - 1.0
			var color: Color = face.call(absf(s), t, r)
			out.add_vertex(Vector3(s * r, top, (t - 0.45) * size), Vector3.UP, color, Vector2(t, float(j) / float(across)))
	for i in range(rows):
		for j in range(across):
			var a: int = face_start + i * (across + 1) + j
			var b: int = a + across + 1
			out.add_triangle(a, a + 1, b)
			out.add_triangle(a + 1, b + 1, b)


## Strawberry cut face: a red rim, paler flesh, a white core down the middle.
func _berry_face(across: float, along: float, _r: float) -> Color:
	var red := Color(0.86, 0.16, 0.2)
	var flesh := Color(0.98, 0.62, 0.62)
	var core := Color(1.0, 0.9, 0.86)
	var c: Color = flesh.lerp(red, smoothstep(0.55, 0.95, across))
	var core_amount: float = (1.0 - smoothstep(0.1, 0.32, across)) * smoothstep(0.05, 0.25, along) * (1.0 - smoothstep(0.75, 0.95, along))
	c = c.lerp(core, core_amount * 0.85)
	# Faint streaks running out from the core.
	c = c.lerp(core, 0.15 * (0.5 + 0.5 * sin(along * 40.0)) * (1.0 - across))
	return Color(c.r, c.g, c.b, 0.0)


## Fig cut face: a cream rim round deep pink flesh, freckled with seeds.
func _fig_face(across: float, along: float, _r: float) -> Color:
	var rim := Color(0.97, 0.92, 0.8)
	var flesh := Color(0.86, 0.36, 0.4)
	var heart := Color(0.66, 0.16, 0.24)
	var c: Color = heart.lerp(flesh, smoothstep(0.1, 0.6, across)).lerp(rim, smoothstep(0.7, 0.88, across))
	var speckle: float = 0.5 + 0.5 * sin(across * 71.0 + along * 97.0) * sin(along * 59.0 - across * 43.0)
	if across < 0.7 and speckle > 0.8:
		c = c.lerp(Color(0.98, 0.86, 0.55), 0.6)
	return Color(c.r, c.g, c.b, 0.0)


## A small bunch lying on the cake: grapes in a tapering heap, a stem at the
## top end.
func _grapes(out: MeshArrays) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var grape: float = size * 0.16
	var rows: Array = [4, 4, 3, 2, 1]
	for layer in range(2):
		for row in range(rows.size()):
			var count: int = rows[row] - layer
			if count <= 0:
				continue
			for k in range(count):
				var x: float = (float(k) - float(count - 1) * 0.5) * grape * 1.75
				var z: float = (float(row) - 1.6) * grape * 1.6
				var y: float = grape * 0.9 + float(layer) * grape * 1.15
				var shade: float = rng.randf_range(0.82, 1.0)
				var r: float = grape * rng.randf_range(0.92, 1.08)
				var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
				add_blob(out, Transform3D(basis, Vector3(x + rng.randf_range(-0.2, 0.2) * grape, y, z)), r, Color(shade, shade, shade, 1.0), Vector3(1.0, 1.0, 1.12), 7, 12)
	var stem := Color(0.46, 0.38, 0.24, 0.0)
	add_tube(out, PackedVector3Array([Vector3(0.0, grape * 1.8, grape * 2.4), Vector3(0.0, grape * 2.1, grape * 3.4), Vector3(grape * 0.4, grape * 2.3, grape * 4.1)]), PackedFloat32Array([grape * 0.16, grape * 0.13, grape * 0.11]), stem, 6)
