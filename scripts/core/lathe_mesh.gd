class_name LatheMesh
extends RefCounted
## Builds round meshes (plates, pedestals, cake tiers) by spinning a 2D profile
## around the vertical (Y) axis.
##
## A profile is a list of (radius, height) points plus one outward-facing normal
## per point, ordered from the bottom centre, out and up the side, and back to
## the top centre. Normals are given explicitly so flat faces stay crisp while
## rounded edges shade smoothly.


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
	points.append(Vector2(0.0, height))
	normals.append(Vector2(0.0, 1.0))
	return {"points": points, "normals": normals}


## Spins the profile into a mesh with the given number of segments around.
static func build(points: PackedVector2Array, normals: PackedVector2Array, segments: int = 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = points.size()
	for i in range(count - 1):
		var v0: float = float(i) / float(count - 1)
		var v1: float = float(i + 1) / float(count - 1)
		for j in range(segments):
			var a0: float = TAU * float(j) / float(segments)
			var a1: float = TAU * float(j + 1) / float(segments)
			var u0: float = float(j) / float(segments)
			var u1: float = float(j + 1) / float(segments)
			# a = (i, j), b = (i, j + 1), c = (i + 1, j), d = (i + 1, j + 1)
			_add(st, points[i], normals[i], a0, Vector2(u0, v0))
			_add(st, points[i], normals[i], a1, Vector2(u1, v0))
			_add(st, points[i + 1], normals[i + 1], a0, Vector2(u0, v1))
			_add(st, points[i], normals[i], a1, Vector2(u1, v0))
			_add(st, points[i + 1], normals[i + 1], a1, Vector2(u1, v1))
			_add(st, points[i + 1], normals[i + 1], a0, Vector2(u0, v1))
	return st.commit()


static func _add(st: SurfaceTool, p: Vector2, n: Vector2, angle: float, uv: Vector2) -> void:
	var c: float = cos(angle)
	var s: float = sin(angle)
	st.set_normal(Vector3(n.x * c, n.y, n.x * s))
	st.set_uv(uv)
	st.add_vertex(Vector3(p.x * c, p.y, p.x * s))
