class_name LatheMesh
extends RefCounted
## Builds round meshes (plates, pedestals, cake tiers, jars) by spinning a 2D
## profile around the vertical (Y) axis.
##
## A profile is a list of (radius, height) points plus one outward-facing normal
## per point, ordered from the bottom centre, out and up the side, and back to
## the top centre. Normals are given explicitly so flat faces stay crisp while
## rounded edges shade smoothly. Repeat a point with a different normal to get
## a hard edge.


## Profile of a cylinder with softly rounded top and bottom edges.
## Returns {"points": PackedVector2Array, "normals": PackedVector2Array}.
static func rounded_cylinder_profile(radius: float, height: float, edge_radius: float, arc_steps: int = 6) -> Dictionary:
	var e: float = minf(edge_radius, minf(radius, height * 0.5))
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	points.append(Vector2(0.0, 0.0))
	normals.append(Vector2(0.0, -1.0))
	# Bottom corner: arc centre (radius - e, e), from facing down to facing out.
	for i in range(arc_steps + 1):
		var a: float = -PI * 0.5 + (PI * 0.5) * float(i) / float(arc_steps)
		var n := Vector2(cos(a), sin(a))
		points.append(Vector2(radius - e, e) + n * e)
		normals.append(n)
	# Top corner: arc centre (radius - e, height - e), from facing out to facing up.
	for i in range(arc_steps + 1):
		var a: float = (PI * 0.5) * float(i) / float(arc_steps)
		var n := Vector2(cos(a), sin(a))
		points.append(Vector2(radius - e, height - e) + n * e)
		normals.append(n)
	# An extra ring on the top so lighting across it stays smooth.
	points.append(Vector2((radius - e) * 0.5, height))
	normals.append(Vector2(0.0, 1.0))
	points.append(Vector2(0.0, height))
	normals.append(Vector2(0.0, 1.0))
	return {"points": points, "normals": normals}


## Profile from a list of (radius, height) points, with normals worked out
## from the neighbouring points (smooth everywhere).
static func smooth_profile(points: PackedVector2Array) -> Dictionary:
	var normals := PackedVector2Array()
	var count: int = points.size()
	for i in range(count):
		var prev: Vector2 = points[maxi(i - 1, 0)]
		var next: Vector2 = points[mini(i + 1, count - 1)]
		var d: Vector2 = next - prev
		# Walking up the outside, the outward normal is the direction turned clockwise.
		var n := Vector2(d.y, -d.x).normalized()
		if i == 0 and points[0].x < 0.0001:
			n = Vector2(0.0, -1.0)
		elif i == count - 1 and points[count - 1].x < 0.0001:
			n = Vector2(0.0, 1.0)
		normals.append(n)
	return {"points": points, "normals": normals}


## Spins the profile into a mesh. `radial_wave` (optional) takes an angle and
## returns a radius multiplier, for scalloped edges; it only applies to
## profile points at or after `wave_from`.
static func build(points: PackedVector2Array, normals: PackedVector2Array, segments: int = 48,
		radial_wave: Callable = Callable(), wave_from: int = 0, material: Material = null) -> ArrayMesh:
	return build_arrays(points, normals, segments, radial_wave, wave_from).to_mesh(material)


static func build_arrays(points: PackedVector2Array, normals: PackedVector2Array, segments: int = 48,
		radial_wave: Callable = Callable(), wave_from: int = 0, color: Color = Color.WHITE) -> MeshArrays:
	var out := MeshArrays.new()
	var count: int = points.size()
	var stride: int = segments + 1
	var cos_table := PackedFloat32Array()
	var sin_table := PackedFloat32Array()
	var wave_table := PackedFloat32Array()
	var wave_slope := PackedFloat32Array()
	for j in range(stride):
		var a: float = TAU * float(j) / float(segments)
		cos_table.append(cos(a))
		sin_table.append(sin(a))
		if radial_wave.is_valid():
			var da: float = 0.001
			wave_table.append(float(radial_wave.call(a)))
			wave_slope.append((float(radial_wave.call(a + da)) - float(radial_wave.call(a - da))) / (2.0 * da))
		else:
			wave_table.append(1.0)
			wave_slope.append(0.0)
	for i in range(count):
		var p: Vector2 = points[i]
		var n: Vector2 = normals[i]
		var v: float = float(i) / float(maxi(count - 1, 1))
		var waved: bool = radial_wave.is_valid() and i >= wave_from
		for j in range(stride):
			var c: float = cos_table[j]
			var s: float = sin_table[j]
			var k: float = wave_table[j] if waved else 1.0
			var normal := Vector3(n.x * c, n.y, n.x * s)
			if waved and wave_slope[j] != 0.0:
				# Tilt the normal sideways across the scallops.
				var tangential := Vector3(-s, 0.0, c)
				normal -= tangential * (wave_slope[j] / maxf(k, 0.0001)) * n.x
			out.add_vertex(Vector3(p.x * k * c, p.y, p.x * k * s), normal.normalized(), color, Vector2(float(j) / float(segments), v))
	for i in range(count - 1):
		for j in range(segments):
			var a: int = i * stride + j
			var b: int = a + 1
			var c: int = a + stride
			var d: int = c + 1
			out.add_triangle(a, b, c)
			out.add_triangle(b, d, c)
	return out
