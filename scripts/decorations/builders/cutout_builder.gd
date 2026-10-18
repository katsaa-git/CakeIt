@tool
class_name CutoutBuilder
extends DecorationBuilder
## A fondant cut-out pressed onto the cake: a soft-edged heart, star,
## blossom, butterfly (wings folded up a little, with a body and antennae),
## crescent moon, puffy cloud or leaf (with pressed veins). Tiny ones make
## heart and star sprinkles.

enum Shape { HEART, STAR, BLOSSOM, BUTTERFLY, MOON, CLOUD, LEAF }

@export var shape: Shape = Shape.HEART
## Half the width, in game units.
@export_range(0.01, 0.4) var size: float = 0.11
@export_range(0.003, 0.06) var thickness: float = 0.022
## How far the two halves fold up from the middle (butterfly wings), as a
## slope (0 = flat).
@export_range(0.0, 1.5) var fold: float = 0.0


func build() -> MeshArrays:
	var out: MeshArrays = extrude(outline(), thickness, TINTABLE)
	if fold > 0.0:
		_fold(out)
	match shape:
		Shape.BUTTERFLY:
			_add_body(out)
		Shape.LEAF:
			_add_veins(out)
	return out


## The shape's outline (x across, y = top).
func outline() -> PackedVector2Array:
	var loop := PackedVector2Array()
	var count: int = 72
	match shape:
		Shape.MOON:
			return _moon()
		Shape.LEAF:
			for k in range(count):
				# Up the right side from the stem to the tip, then down the left.
				var t: float = float(k) / float(count) * 2.0
				var y: float = -1.0 + 2.0 * (t if t <= 1.0 else 2.0 - t)
				var half: float = 0.4 * pow(maxf(1.0 - y * y, 0.0), 0.75) * (1.0 + 0.12 * y)
				loop.append(Vector2(half if t <= 1.0 else -half, y) * size)
			return TipProfile.counter_clockwise(loop)
	for k in range(count):
		var a: float = TAU * float(k) / float(count)
		var p: Vector2
		match shape:
			Shape.HEART:
				# The classic heart curve, centred and scaled to fit.
				var t: float = -a
				p = Vector2(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) / 17.0
				p.y += 0.12
			Shape.STAR:
				var r: float = 0.52 + 0.48 * pow(0.5 + 0.5 * cos(5.0 * (a - PI * 0.5)), 1.6)
				p = Vector2(cos(a), sin(a)) * r
			Shape.BLOSSOM:
				var r: float = 0.6 + 0.4 * pow(absf(cos(2.5 * (a - PI * 0.5))), 0.55)
				p = Vector2(cos(a), sin(a)) * r
			Shape.BUTTERFLY:
				p = Vector2(cos(a), sin(a)) * _reach(a, [
					[Vector2(0.44, 0.24), Vector2(0.5, 0.36), 0.45], [Vector2(-0.44, 0.24), Vector2(0.5, 0.36), -0.45],
					[Vector2(0.3, -0.33), Vector2(0.31, 0.25), -0.5], [Vector2(-0.3, -0.33), Vector2(0.31, 0.25), 0.5],
					[Vector2(0.0, 0.0), Vector2(0.08, 0.42), 0.0]])
			Shape.CLOUD:
				p = Vector2(cos(a), sin(a)) * _reach(a, [
					[Vector2(-0.56, -0.12), Vector2(0.38, 0.38), 0.0], [Vector2(-0.2, 0.14), Vector2(0.47, 0.47), 0.0],
					[Vector2(0.26, 0.2), Vector2(0.43, 0.43), 0.0], [Vector2(0.62, -0.08), Vector2(0.34, 0.34), 0.0],
					[Vector2(0.03, -0.22), Vector2(0.86, 0.26), 0.0]])
		loop.append(p * size)
	return loop


## How far a ray from the middle reaches through a union of ellipses
## [centre, radii, turn], for shapes built from rounded blobs.
static func _reach(angle: float, blobs: Array) -> float:
	var reach: float = 0.0
	for blob: Array in blobs:
		var center: Vector2 = blob[0]
		var radii: Vector2 = blob[1]
		var u: Vector2 = Vector2(cos(angle), sin(angle)).rotated(-float(blob[2]))
		var c: Vector2 = center.rotated(-float(blob[2]))
		# Solve |(t * u - c) / radii| = 1 for the far t.
		var du := Vector2(u.x / radii.x, u.y / radii.y)
		var dc := Vector2(c.x / radii.x, c.y / radii.y)
		var a: float = du.dot(du)
		var b: float = -2.0 * du.dot(dc)
		var k: float = dc.dot(dc) - 1.0
		var disc: float = b * b - 4.0 * a * k
		if disc >= 0.0:
			reach = maxf(reach, (-b + sqrt(disc)) / (2.0 * a))
	return reach


## A crescent: the outer circle's arc, then back along a smaller circle
## offset to the right, so the horns point right.
func _moon() -> PackedVector2Array:
	var d: float = 0.42
	var inner: float = 0.84
	var xi: float = (d * d + 1.0 - inner * inner) / (2.0 * d)
	var yi: float = sqrt(maxf(1.0 - xi * xi, 0.0))
	var loop := PackedVector2Array()
	var a0: float = atan2(yi, xi)
	var steps: int = 40
	for k in range(steps + 1):
		var a: float = lerpf(a0, TAU - a0, float(k) / float(steps))
		loop.append(Vector2(cos(a), sin(a)))
	var b0: float = atan2(-yi, xi - d)
	var b1: float = atan2(yi, xi - d) - TAU
	for k in range(1, steps):
		var b: float = lerpf(b0, b1, float(k) / float(steps))
		loop.append(Vector2(d + cos(b) * inner, sin(b) * inner))
	var turned := PackedVector2Array()
	for p in loop:
		# Tilt it a little, like a real crescent cutter, and centre it.
		turned.append((p - Vector2(-0.25, 0.0)).rotated(0.35) * size)
	return TipProfile.counter_clockwise(turned)


## Folds each half up about the middle line (the butterfly's body).
func _fold(out: MeshArrays) -> void:
	var angle: float = atan(fold)
	for i in range(out.verts.size()):
		var v: Vector3 = out.verts[i]
		var basis := Basis(Vector3.BACK, angle * signf(v.x))
		out.verts[i] = basis * v
		out.normals[i] = (basis * out.normals[i]).normalized()


func _add_body(out: MeshArrays) -> void:
	var body := Color(0.72, 0.72, 0.72, 1.0)
	add_blob(out, Transform3D(Basis.IDENTITY, Vector3(0.0, thickness * 1.3, -size * 0.02)), 1.0, body, Vector3(size * 0.09, size * 0.09, size * 0.42), 6, 10)
	add_sphere(out, Vector3(0.0, thickness * 1.4, size * 0.44), size * 0.1, body, 6, 10)
	for side in [-1.0, 1.0]:
		var tip := Vector3(side * size * 0.24, thickness * 2.4, size * 0.82)
		add_tube(out, PackedVector3Array([Vector3(side * size * 0.03, thickness * 1.6, size * 0.5), Vector3(side * size * 0.12, thickness * 2.2, size * 0.68), tip]), PackedFloat32Array([size * 0.018, size * 0.016, size * 0.014]), body, 6)
		add_sphere(out, tip, size * 0.04, body, 4, 6)


## Pressed veins: a raised middle rib and a few side ribs, a shade deeper.
func _add_veins(out: MeshArrays) -> void:
	var vein := Color(0.86, 0.86, 0.86, 1.0)
	var y: float = thickness * 1.02
	var rib := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in range(6):
		var t: float = float(k) / 5.0
		rib.append(Vector3(0.0, y, lerpf(-0.95, 0.85, t) * size))
		radii.append(size * lerpf(0.035, 0.012, t))
	add_tube(out, rib, radii, vein, 5)
	for k in range(3):
		var z: float = lerpf(-0.45, 0.4, float(k) / 2.0) * size
		for side in [-1.0, 1.0]:
			add_tube(out, PackedVector3Array([Vector3(0.0, y, z), Vector3(side * size * 0.2, y, z + size * 0.22)]), PackedFloat32Array([size * 0.018, size * 0.01]), vein, 5)


func radius() -> float:
	return size
