@tool
class_name DecorationBuilder
extends Resource
## Base class that makes the geometry for one kind of decoration.
##
## Conventions for `build()`: one piece at size 1, in game units, with its
## origin where it touches the surface, +Y standing away from the surface
## and +Z as the shape's "top" (where a heart's lobes point). Vertex colour
## RGB is the base colour and alpha is how much the piece's own colour tints
## it (1 = takes the picked colour, 0 = keeps this colour, like a daisy's
## yellow middle).

## Tintable white, the usual base.
const TINTABLE := Color(1.0, 1.0, 1.0, 1.0)


## Override: one piece at size 1.
func build() -> MeshArrays:
	return MeshArrays.new()


## Override: rough radius of one piece at size 1 (spacing, previews).
func radius() -> float:
	return 0.05


## Override: where a candle flame sits (zero = no flame).
func flame_offset() -> Vector3:
	return Vector3.ZERO


## Override: true when every placed piece is built on its own (drips follow
## the tier's edge; signs carry their own words).
func is_unique() -> bool:
	return false


## Override: true when the player types words for it (signs, plaques, letters).
func uses_text() -> bool:
	return false


## Override for unique builders: the finished geometry for one placed piece,
## with its colour already baked in, in the frame `piece_transform` gives.
func build_unique(_decoration: DecorationData, _tier: TierData) -> MeshArrays:
	return MeshArrays.new()


## Override for unique builders whose geometry is built in the tier's own
## frame (drips, ribbons): where the built piece sits on its tier.
func piece_transform(decoration: DecorationData) -> Transform3D:
	return decoration.transform


## Override for unique builders: extra nodes (a sign's words) for one piece,
## in the piece's own frame.
func add_extras(_node: Node3D, _decoration: DecorationData) -> void:
	pass


## Override for builders that keep their own placement data (ribbons): the
## piece moved onto a resized tier. The default (null) lets ItemRemap move
## it along the surface like any other piece.
func remap_unique(_decoration: DecorationData, _old_tier: TierData, _new_tier: TierData) -> DecorationData:
	return null


# --- Helpers for builders ------------------------------------------------------

## A UV sphere (optionally squashed) of `rings` x `segments`.
static func add_sphere(out: MeshArrays, center: Vector3, radius_value: float, color: Color, rings: int = 8, segments: int = 12, squash := Vector3.ONE) -> void:
	var start: int = out.vertex_count()
	for i in range(rings + 1):
		var phi: float = PI * float(i) / float(rings)
		for j in range(segments + 1):
			var theta: float = TAU * float(j) / float(segments)
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p: Vector3 = n * radius_value * squash
			out.add_vertex(center + p, (n / squash).normalized(), color, Vector2(float(j) / float(segments), float(i) / float(rings)))
	for i in range(rings):
		for j in range(segments):
			var a: int = start + i * (segments + 1) + j
			var b: int = a + 1
			var c: int = a + segments + 1
			var d: int = c + 1
			# Rings run top to bottom, so this order faces outward.
			out.add_triangle(a, c, b)
			out.add_triangle(b, c, d)


## A squashed sphere turned and placed by `xform` (ears, wings, leaves).
static func add_blob(out: MeshArrays, xform: Transform3D, radius_value: float, color: Color, squash := Vector3.ONE, rings: int = 7, segments: int = 12) -> void:
	var piece := MeshArrays.new()
	add_sphere(piece, Vector3.ZERO, radius_value, color, rings, segments, squash)
	add_transformed(out, piece, xform)


## A round shape spun from a (radius, height) outline, bottom to top, placed
## by `xform`.
static func add_lathe(out: MeshArrays, outline: PackedVector2Array, color: Color, segments: int = 24, xform := Transform3D.IDENTITY) -> void:
	var profile: Dictionary = LatheMesh.smooth_profile(outline)
	var piece: MeshArrays = LatheMesh.build_arrays(profile["points"], profile["normals"], segments, Callable(), 0, color)
	add_transformed(out, piece, xform)


## A round tube along `points` with radius `radii` (one per point), closed
## at both ends: stems, wicks, antennae.
static func add_tube(out: MeshArrays, points: PackedVector3Array, radii: PackedFloat32Array, color: Color, sides: int = 8) -> void:
	var shape := ProfileShape.circle(sides)
	var ups := PackedVector3Array()
	for i in range(points.size()):
		var along: Vector3 = points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		ups.append(TubeBuilder.any_perpendicular(along.normalized() if along.length_squared() > 1e-12 else Vector3.UP))
	TubeBuilder.sweep(out, shape, TubeBuilder.shaded_colors(shape, color, 0.0), points, ups, radii, PackedFloat32Array(), true, true)


## Recomputes smooth normals from the faces (for hand-built shapes).
static func smooth_normals(out: MeshArrays, from_vertex: int = 0) -> void:
	var sums := PackedVector3Array()
	sums.resize(out.verts.size())
	for i in range(0, out.indices.size(), 3):
		var a: int = out.indices[i]
		var b: int = out.indices[i + 1]
		var c: int = out.indices[i + 2]
		if a < from_vertex:
			continue
		var face: Vector3 = (out.verts[c] - out.verts[a]).cross(out.verts[b] - out.verts[a])
		sums[a] += face
		sums[b] += face
		sums[c] += face
	for i in range(from_vertex, sums.size()):
		out.normals[i] = sums[i].normalized() if sums[i].length_squared() > 0.0 else Vector3.UP


## A copy of `source` moved by `xform`, with its tintable parts coloured by
## `tint` and baked (alpha 0), for previews and one-off pieces.
static func baked(source: MeshArrays, xform: Transform3D, tint: Color) -> MeshArrays:
	var out: MeshArrays = source.duplicate_arrays()
	var normal_basis: Basis = xform.basis.inverse().transposed()
	for i in range(out.verts.size()):
		out.verts[i] = xform * out.verts[i]
		out.normals[i] = (normal_basis * out.normals[i]).normalized()
		var c: Color = out.colors[i]
		var tinted := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b)
		var mixed: Color = Color(c.r, c.g, c.b).lerp(tinted, c.a)
		mixed.a = 0.0
		out.colors[i] = mixed
	return out


## Appends `source` moved by `xform` (colours unchanged).
static func add_transformed(out: MeshArrays, source: MeshArrays, xform: Transform3D) -> void:
	var piece: MeshArrays = source.duplicate_arrays()
	var normal_basis: Basis = xform.basis.inverse().transposed()
	for i in range(piece.verts.size()):
		piece.verts[i] = xform * piece.verts[i]
		piece.normals[i] = (normal_basis * piece.normals[i]).normalized()
	out.append(piece)


## A flat shape with soft edges: `outline` is a closed loop of (x, top)
## points laid in the XZ plane (top = +Z) and raised `thickness` along +Y,
## with a rounded top edge. Any simple outline works (crescent moons too):
## the edge is inset along its normals and the top is triangulated.
## `bottom` adds the underside too (for shapes seen from behind).
static func extrude(outline: PackedVector2Array, thickness: float, color: Color, bottom: bool = false) -> MeshArrays:
	var out := MeshArrays.new()
	var count: int = outline.size()
	var area: float = 0.0
	for k in range(count):
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % count]
		area += a.x * b.y - b.x * a.y
	var turn: float = 1.0 if area > 0.0 else -1.0
	# Inward direction at each outline point (across both of its edges).
	var inward := PackedVector2Array()
	inward.resize(count)
	for k in range(count):
		var prev: Vector2 = outline[(k - 1 + count) % count]
		var next: Vector2 = outline[(k + 1) % count]
		var t: Vector2 = (next - prev).normalized()
		inward[k] = Vector2(-t.y, t.x) * turn
	var bevel: float = thickness * 0.38
	# [height fraction, inset as a fraction of the bevel]
	var rings: Array = [[0.0, 0.0], [0.6, 0.0], [0.88, 0.3], [1.0, 1.0]]
	if bottom:
		rings = [[0.0, 1.0], [0.12, 0.3], [0.4, 0.0], [0.6, 0.0], [0.88, 0.3], [1.0, 1.0]]
	for ring: Array in rings:
		for k in range(count + 1):
			var p: Vector2 = outline[k % count] + inward[k % count] * bevel * float(ring[1])
			out.add_vertex(Vector3(p.x, float(ring[0]) * thickness, p.y), Vector3.UP, color, Vector2(float(k) / float(count), float(ring[0])))
	for i in range(rings.size() - 1):
		for k in range(count):
			var a: int = i * (count + 1) + k
			var b: int = a + 1
			var c: int = a + count + 1
			var d: int = c + 1
			if turn > 0.0:
				out.add_triangle(a, b, c)
				out.add_triangle(b, d, c)
			else:
				out.add_triangle(a, c, b)
				out.add_triangle(b, c, d)
	smooth_normals(out)
	# The flat top (and bottom) get their own vertices so they stay flat.
	var face := PackedVector2Array()
	for k in range(count):
		face.append(outline[k] + inward[k] * bevel)
	# Triangulate the outline itself (always a clean polygon) and use those
	# triangles on the inset points; insetting can fold sharp tips (a heart's
	# cusp) over themselves, which triangulation would refuse.
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if triangles.is_empty():
		triangles = Geometry2D.triangulate_polygon(face)
	if triangles.is_empty():
		# Last resort: a fan from the first point.
		for k in range(1, count - 1):
			triangles.append_array(PackedInt32Array([0, k, k + 1]))
	var top: int = out.vertex_count()
	for k in range(count):
		out.add_vertex(Vector3(face[k].x, thickness, face[k].y), Vector3.UP, color, Vector2(float(k) / float(count), 1.0))
	for i in range(0, triangles.size(), 3):
		_add_face(out, top + triangles[i], top + triangles[i + 1], top + triangles[i + 2], Vector3.UP)
	if bottom:
		var under: int = out.vertex_count()
		for k in range(count):
			out.add_vertex(Vector3(face[k].x, 0.0, face[k].y), Vector3.DOWN, color, Vector2(float(k) / float(count), 0.0))
		for i in range(0, triangles.size(), 3):
			_add_face(out, under + triangles[i], under + triangles[i + 1], under + triangles[i + 2], Vector3.DOWN)
	return out


## Adds a triangle wound so it faces `facing`.
static func _add_face(out: MeshArrays, a: int, b: int, c: int, facing: Vector3) -> void:
	var normal: Vector3 = (out.verts[c] - out.verts[a]).cross(out.verts[b] - out.verts[a])
	if normal.dot(facing) >= 0.0:
		out.add_triangle(a, b, c)
	else:
		out.add_triangle(a, c, b)


## Bends a flat piece (lying in its XZ plane, +Y out of the surface) round a
## cylinder of `cylinder_radius` about its local Z axis, so wide pieces on
## the side of a tier (words, plaques) hug the curve instead of floating.
static func wrap_round(piece: MeshArrays, cylinder_radius: float) -> void:
	if cylinder_radius <= 0.0:
		return
	for i in range(piece.verts.size()):
		var v: Vector3 = piece.verts[i]
		var angle: float = v.x / cylinder_radius
		var r: float = cylinder_radius + v.y
		piece.verts[i] = Vector3(sin(angle) * r, cos(angle) * r - cylinder_radius, v.z)
		var n: Vector3 = piece.normals[i]
		piece.normals[i] = Vector3(n.x * cos(angle) + n.y * sin(angle), -n.x * sin(angle) + n.y * cos(angle), n.z).normalized()


## The radius (in the piece's own units) to bend a flat piece by when it
## sits on the side of a tier with its top pointing up; 0 on top, where
## nothing needs bending.
static func side_curve(decoration: DecorationData, tier: TierData) -> float:
	if tier == null:
		return 0.0
	var basis: Basis = decoration.transform.basis.orthonormalized()
	if absf(basis.y.y) > 0.5 or absf(basis.z.y) < 0.6:
		return 0.0
	var scale: float = maxf(absf(decoration.transform.basis.get_scale().x), 0.001)
	return tier.radius / scale
