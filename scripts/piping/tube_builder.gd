class_name TubeBuilder
extends RefCounted
## Low-level helpers that sweep a ProfileShape along a path into MeshArrays.
## Shared by piped lines, stamps, drips and some decorations.
##
## Frame convention for a ring: `tangent` points along the path, `up` away
## from the surface, and side = up x tangent. Profile x maps to `side`,
## profile y maps to `up`. Triangles use Godot's clockwise front faces.


## Adds one ring of vertices. `scale` is the ring radius in game units and
## `dscale` is how fast that radius changes per unit of path, which tilts the
## normals so swelling and tapering parts shade correctly.
static func emit_ring(out: MeshArrays, shape: ProfileShape, colors: PackedColorArray,
		center: Vector3, side: Vector3, up: Vector3, tangent: Vector3,
		scale: float, dscale: float, twist: float, u: float,
		wave_amount: float = 0.0, wave_slope: float = 0.0) -> void:
	var count: int = shape.points.size()
	var c: float = cos(twist)
	var s: float = sin(twist)
	var has_wave: bool = wave_amount != 0.0 and not shape.wave.is_empty()
	var pts: PackedVector2Array = shape.points
	var nrm: PackedVector2Array = shape.normals
	var around: PackedFloat32Array = shape.around
	for j in range(count):
		var p: Vector2 = pts[j]
		var q := Vector2(p.x * c - p.y * s, p.x * s + p.y * c)
		var m: Vector2 = nrm[j]
		var n2 := Vector2(m.x * c - m.y * s, m.x * s + m.y * c)
		var offset: Vector2 = q * scale
		var along: float = -dscale * q.dot(n2)
		if has_wave:
			var w: Vector2 = shape.wave[j]
			var wr := Vector2(w.x * c - w.y * s, w.x * s + w.y * c)
			offset += wr * wave_amount
			along -= wave_slope * wr.dot(n2)
		out.verts.append(center + side * offset.x + up * offset.y)
		out.normals.append((side * n2.x + up * n2.y + tangent * along).normalized())
		out.colors.append(colors[j])
		out.uvs.append(Vector2(u, around[j]))


## Joins the last two rings added with quads.
static func bridge_last(out: MeshArrays, ring_size: int) -> void:
	var b0: int = out.verts.size() - ring_size
	var a0: int = b0 - ring_size
	if a0 < 0:
		return
	for j in range(ring_size):
		var j1: int = (j + 1) % ring_size
		var a: int = a0 + j
		var a1: int = a0 + j1
		var b: int = b0 + j
		var b1: int = b0 + j1
		out.indices.append(a)
		out.indices.append(b)
		out.indices.append(a1)
		out.indices.append(a1)
		out.indices.append(b)
		out.indices.append(b1)


## Adds a single "pole" vertex that closes the end of a tube. Returns its index.
static func add_pole_vertex(out: MeshArrays, position: Vector3, normal: Vector3, color: Color, u: float) -> int:
	out.add_vertex(position, normal, color, Vector2(u, 0.5))
	return out.verts.size() - 1


## Connects a pole to the ring starting at `ring0` with a fan of triangles.
## `at_start` is true when the pole caps the start of the tube (facing back).
static func fan(out: MeshArrays, pole: int, ring0: int, ring_size: int, at_start: bool) -> void:
	for j in range(ring_size):
		var a: int = ring0 + j
		var b: int = ring0 + (j + 1) % ring_size
		if at_start:
			out.add_triangle(pole, a, b)
		else:
			out.add_triangle(pole, b, a)


## Per-vertex colours for a stroke: the base colour, a little darker in grooves.
static func shaded_colors(shape: ProfileShape, color: Color, groove_darkening: float = 0.22) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(shape.points.size())
	for j in range(shape.points.size()):
		var k: float = 1.0 - shape.shade[j] * groove_darkening
		out[j] = Color(color.r * k, color.g * k, color.b * k, color.a)
	return out


## Sweeps a whole path at once. `centers`, `ups` and `scales` must be the same
## length (at least 2). Tangents and normal tilt are worked out from
## neighbouring points. Optional poles close either end.
static func sweep(out: MeshArrays, shape: ProfileShape, colors: PackedColorArray,
		centers: PackedVector3Array, ups: PackedVector3Array, scales: PackedFloat32Array,
		twists: PackedFloat32Array = PackedFloat32Array(), close_start: bool = false, close_end: bool = false,
		u_start: float = 0.0, u_scale: float = 1.0) -> void:
	var count: int = centers.size()
	if count < 2:
		return
	var ring_size: int = shape.points.size()
	var u: float = u_start
	var last_tangent := Vector3.ZERO
	var start_pole: int = -1
	for k in range(count):
		var k0: int = maxi(k - 1, 0)
		var k1: int = mini(k + 1, count - 1)
		var delta: Vector3 = centers[k1] - centers[k0]
		var tangent: Vector3 = delta.normalized() if delta.length_squared() > 1e-14 else last_tangent
		if tangent == Vector3.ZERO:
			tangent = any_perpendicular(ups[k])
		last_tangent = tangent
		var up: Vector3 = ups[k] - tangent * tangent.dot(ups[k])
		if up.length_squared() < 1e-10:
			up = any_perpendicular(tangent)
		up = up.normalized()
		var side: Vector3 = up.cross(tangent).normalized()
		var span: float = maxf(delta.dot(tangent), 1e-6)
		var dscale: float = clampf((scales[k1] - scales[k0]) / span, -25.0, 25.0)
		var twist: float = twists[k] if k < twists.size() else 0.0
		if k > 0:
			u += centers[k].distance_to(centers[k - 1]) * u_scale
		if k == 0 and close_start:
			start_pole = add_pole_vertex(out, centers[0] - tangent * scales[0] * 0.2, -tangent, colors[0], u_start)
		var ring0: int = out.verts.size()
		emit_ring(out, shape, colors, centers[k], side, up, tangent, scales[k], dscale, twist, u)
		if k > 0:
			bridge_last(out, ring_size)
		elif start_pole >= 0:
			fan(out, start_pole, ring0, ring_size, true)
	if close_end:
		var last_ring: int = out.verts.size() - ring_size
		var pole: int = add_pole_vertex(out, centers[count - 1] + last_tangent * scales[count - 1] * 0.2, last_tangent, colors[0], u)
		fan(out, pole, last_ring, ring_size, false)


static func any_perpendicular(v: Vector3) -> Vector3:
	var p: Vector3 = v.cross(Vector3.RIGHT)
	if p.length_squared() < 0.01:
		p = v.cross(Vector3.FORWARD)
	return p.normalized()


## Copies every triangle of `piece` into a flat triangle list for a
## ConcavePolygonShape3D.
static func triangles_for_collision(piece: MeshArrays, faces: PackedVector3Array) -> void:
	var idx: PackedInt32Array = piece.indices
	var verts: PackedVector3Array = piece.verts
	var start: int = faces.size()
	faces.resize(start + idx.size())
	for i in range(idx.size()):
		faces[start + i] = verts[idx[i]]
