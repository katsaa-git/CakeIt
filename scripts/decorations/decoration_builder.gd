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


## Override for unique builders: the finished geometry for one placed piece,
## in the tier's frame, with its colour already baked in.
func build_unique(_decoration: DecorationData, _tier: TierData) -> MeshArrays:
	return MeshArrays.new()


## Override for unique builders: extra nodes (a sign's words) for one piece.
func add_extras(_node: Node3D, _decoration: DecorationData) -> void:
	pass


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
## points around the origin, laid in the XZ plane (top = +Z) and raised
## `thickness` along +Y, with a slightly rounded top edge. `bottom` adds the
## underside too (for shapes seen from behind).
static func extrude(outline: PackedVector2Array, thickness: float, color: Color, bottom: bool = false) -> MeshArrays:
	var out := MeshArrays.new()
	var rings: Array = [[0.0, 1.0], [0.6, 1.0], [0.88, 0.975], [1.0, 0.93]]
	if bottom:
		rings = [[0.0, 0.93], [0.12, 0.975], [0.4, 1.0], [0.6, 1.0], [0.88, 0.975], [1.0, 0.93]]
	var count: int = outline.size()
	for ring: Array in rings:
		for k in range(count + 1):
			var p: Vector2 = outline[k % count] * float(ring[1])
			out.add_vertex(Vector3(p.x, float(ring[0]) * thickness, p.y), Vector3.UP, color, Vector2(float(k) / float(count), float(ring[0])))
	for i in range(rings.size() - 1):
		for k in range(count):
			var a: int = i * (count + 1) + k
			var b: int = a + 1
			var c: int = a + count + 1
			var d: int = c + 1
			out.add_triangle(a, b, c)
			out.add_triangle(b, d, c)
	var top_ring: int = (rings.size() - 1) * (count + 1)
	var top: int = out.vertex_count()
	out.add_vertex(Vector3(0.0, thickness, 0.0), Vector3.UP, color, Vector2(0.5, 1.0))
	for k in range(count):
		out.add_triangle(top, top_ring + k, top_ring + k + 1)
	if bottom:
		var under: int = out.vertex_count()
		out.add_vertex(Vector3.ZERO, Vector3.DOWN, color, Vector2(0.5, 0.0))
		for k in range(count):
			out.add_triangle(under, k + 1, k)
	smooth_normals(out)
	# The flat faces stay flat.
	out.normals[top] = Vector3.UP
	if bottom:
		out.normals[out.vertex_count() - 1] = Vector3.DOWN
	return out
