@tool
class_name FigureBuilder
extends DecorationBuilder
## Little modelled sugar figures that sit on top of the cake, facing +Z:
##   BUNNY     a round, sitting bunny (in the picked colour) with long ears,
##             pink inner ears, a button nose and a fluffy tail;
##   BEE       a plump striped bee with glassy wings;
##   MUSHROOM  a toadstool with a cap in the picked colour and white spots.

enum Kind { BUNNY, BEE, MUSHROOM }

@export var kind: Kind = Kind.BUNNY
## Overall height, in game units (0.4 = 4 cm).
@export_range(0.1, 1.0) var size: float = 0.4

const EYE := Color(0.14, 0.1, 0.09, 0.0)
const PINK := Color(0.98, 0.7, 0.72, 0.0)


func radius() -> float:
	return size * 0.4


func build() -> MeshArrays:
	var out := MeshArrays.new()
	match kind:
		Kind.BUNNY:
			_bunny(out)
		Kind.BEE:
			_bee(out)
		Kind.MUSHROOM:
			_mushroom(out)
	return out


func _bunny(out: MeshArrays) -> void:
	var s: float = size
	# Body: a soft pear sitting on the cake.
	add_blob(out, Transform3D(Basis.IDENTITY, Vector3(0.0, s * 0.2, -s * 0.02)), 1.0, TINTABLE, Vector3(s * 0.24, s * 0.21, s * 0.22), 9, 16)
	# Head, a little forward.
	var head := Vector3(0.0, s * 0.47, s * 0.05)
	add_sphere(out, head, s * 0.155, TINTABLE, 9, 16, Vector3(1.05, 0.95, 1.0))
	# Ears: long and soft, leaning back a little, with pink insides.
	for side in [-1.0, 1.0]:
		var ear := Basis(Vector3.BACK, -side * 0.18) * Basis(Vector3.RIGHT, -0.22)
		var base: Vector3 = head + Vector3(side * s * 0.065, s * 0.11, -s * 0.02)
		add_blob(out, Transform3D(ear, base + ear * Vector3(0.0, s * 0.13, 0.0)), 1.0, TINTABLE, Vector3(s * 0.05, s * 0.15, s * 0.028), 7, 10)
		add_blob(out, Transform3D(ear, base + ear * Vector3(0.0, s * 0.13, s * 0.016)), 1.0, PINK, Vector3(s * 0.028, s * 0.11, s * 0.014), 6, 8)
		# Eyes, cheeks and front paws.
		add_sphere(out, head + Vector3(side * s * 0.055, s * 0.03, s * 0.13), s * 0.02, EYE, 5, 8)
		add_blob(out, Transform3D(Basis.IDENTITY, head + Vector3(side * s * 0.085, -s * 0.035, s * 0.115)), 1.0, Color(1.0, 0.82, 0.83, 0.0), Vector3(s * 0.03, s * 0.018, s * 0.012), 4, 8)
		add_blob(out, Transform3D(Basis.IDENTITY, Vector3(side * s * 0.09, s * 0.06, s * 0.17)), 1.0, TINTABLE, Vector3(s * 0.055, s * 0.045, s * 0.07), 6, 10)
	add_sphere(out, head + Vector3(0.0, -s * 0.01, s * 0.15), s * 0.018, PINK, 5, 8)
	add_sphere(out, Vector3(0.0, s * 0.17, -s * 0.23), s * 0.07, TINTABLE, 6, 10)


func _bee(out: MeshArrays) -> void:
	var s: float = size
	var yellow := Color(1.0, 0.8, 0.26, 0.0)
	var black := Color(0.16, 0.12, 0.1, 0.0)
	# Body along X (seen from the side), striped round its length.
	var body := MeshArrays.new()
	var length: float = s * 0.62
	var points := PackedVector2Array()
	for k in range(13):
		var t: float = float(k) / 12.0
		points.append(Vector2(sin(t * PI) * s * 0.2 * (1.0 - 0.15 * t), t * length))
	var profile: Dictionary = LatheMesh.smooth_profile(points)
	body = LatheMesh.build_arrays(profile["points"], profile["normals"], 20, Callable(), 0, yellow)
	for i in range(body.verts.size()):
		var t: float = body.verts[i].y / length
		if (t > 0.4 and t < 0.52) or (t > 0.64 and t < 0.76) or t > 0.88:
			body.colors[i] = black
	add_transformed(out, body, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(length * 0.5, s * 0.22, 0.0)))
	var head := Vector3(-length * 0.55, s * 0.24, 0.0)
	add_sphere(out, head, s * 0.15, black, 8, 12)
	for side in [-1.0, 1.0]:
		add_sphere(out, head + Vector3(-s * 0.05, s * 0.04, side * s * 0.1), s * 0.035, Color(1.0, 1.0, 1.0, 0.0), 5, 8)
		add_sphere(out, head + Vector3(-s * 0.075, s * 0.045, side * s * 0.12), s * 0.018, EYE, 4, 6)
		add_tube(out, PackedVector3Array([head + Vector3(0.0, s * 0.12, side * s * 0.05), head + Vector3(-s * 0.04, s * 0.24, side * s * 0.09)]), PackedFloat32Array([s * 0.012, s * 0.01]), black, 5)
		add_sphere(out, head + Vector3(-s * 0.04, s * 0.25, side * s * 0.09), s * 0.022, black, 4, 6)
		# Wings: thin, milky and upright, angled back.
		var wing := Basis(Vector3.UP, side * 0.35) * Basis(Vector3.RIGHT, side * 0.5)
		add_blob(out, Transform3D(wing, Vector3(length * 0.05, s * 0.48, side * s * 0.1)), 1.0, Color(0.92, 0.95, 1.0, 0.0), Vector3(s * 0.14, s * 0.19, s * 0.012), 6, 10)
	add_tube(out, PackedVector3Array([Vector3(length * 0.47, s * 0.22, 0.0), Vector3(length * 0.58, s * 0.21, 0.0)]), PackedFloat32Array([s * 0.02, s * 0.004]), black, 5)


func _mushroom(out: MeshArrays) -> void:
	var s: float = size
	var stem := Color(0.97, 0.94, 0.86, 0.0)
	add_lathe(out, PackedVector2Array([Vector2(0.0, 0.0), Vector2(s * 0.13, s * 0.01), Vector2(s * 0.14, s * 0.12), Vector2(s * 0.11, s * 0.3), Vector2(s * 0.1, s * 0.48)]), stem, 18)
	# Gills under the cap, then the cap itself.
	add_lathe(out, PackedVector2Array([Vector2(s * 0.1, s * 0.47), Vector2(s * 0.3, s * 0.44), Vector2(s * 0.42, s * 0.47)]), Color(0.93, 0.86, 0.74, 0.0), 24)
	var cap := PackedVector2Array()
	for k in range(10):
		var a: float = PI * 0.5 * float(k) / 9.0
		cap.append(Vector2(cos(a) * s * 0.42, s * 0.47 + sin(a) * s * 0.32))
	add_lathe(out, cap, TINTABLE, 28)
	# White spots scattered over the cap.
	var spots: Array = [[0.0, 1.45], [0.6, 0.85], [2.2, 0.8], [3.5, 0.9], [4.8, 0.75], [1.4, 0.45], [2.9, 0.42], [4.2, 0.4], [5.6, 0.45]]
	for spot: Array in spots:
		var a: float = float(spot[0])
		var e: float = float(spot[1])
		var n := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e))
		var p := Vector3(n.x * s * 0.42, s * 0.47 + n.y * s * 0.32, n.z * s * 0.42)
		var basis := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT)
		add_blob(out, Transform3D(basis, p), 1.0, Color(1.0, 0.99, 0.96, 0.0), Vector3(s * 0.045, s * 0.045, s * 0.012), 4, 8)
