@tool
class_name RibbonBuilder
extends DecorationBuilder
## A ribbon wrapped round the side of a tier at one height: smooth satin
## (optionally finished with a bow where the drag began) or sugar lace with
## a scalloped lower edge. Built per piece to fit its tier:
##   DecorationData.path              start and end angle round the tier (radians)
##   DecorationData.transform.origin  y = the height of the ribbon's middle
##   DecorationData.transform.basis   scale = the chosen size
## A ribbon at the base stays at the base when the tier is resized, one at
## the top edge stays at the top, and one in between keeps its place.

enum Style { SATIN, LACE }

@export var style: Style = Style.SATIN
## Width of the ribbon, in game units (0.2 = 2 cm).
@export_range(0.03, 0.6) var width: float = 0.2
@export_range(0.003, 0.04) var thickness: float = 0.01
## A bow where the ribbon starts.
@export var bow: bool = false
## Lace: depth of the scallops along the lower edge, as a fraction of the width.
@export_range(0.0, 0.6) var scallop: float = 0.24
## Lace: length of one scallop, in game units.
@export_range(0.05, 0.6) var scallop_length: float = 0.16


func is_unique() -> bool:
	return true


func radius() -> float:
	return width * 0.5


## The ribbon is built in its tier's frame.
func piece_transform(_decoration: DecorationData) -> Transform3D:
	return Transform3D.IDENTITY


## How far the ribbon reaches above and below its middle line, at `size`.
func half_height(size: float) -> float:
	return width * size * 0.5


## A short straight piece, for previews.
func build() -> MeshArrays:
	var decoration := DecorationData.new()
	decoration.path = PackedFloat32Array([PI * 0.5 - 0.6, PI * 0.5 + 0.6])
	decoration.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, width, 0.0))
	decoration.color = Color.WHITE
	var tier := TierData.new()
	tier.radius = 2.0
	tier.height = width * 2.0
	return build_unique(decoration, tier)


func build_unique(decoration: DecorationData, tier: TierData) -> MeshArrays:
	var out := MeshArrays.new()
	if tier == null:
		return out
	var size: float = maxf(decoration.transform.basis.get_scale().y, 0.05)
	var w: float = width * size
	var y: float = decoration.transform.origin.y
	var angles: Vector2 = DripBuilder.span(decoration.path)
	var full: bool = angles.y - angles.x >= TAU - 0.001
	if full:
		# A full wrap overlaps itself a little where it starts (under the bow).
		angles.y = angles.x + TAU + 0.05
	var color := Color(decoration.color.r, decoration.color.g, decoration.color.b, 0.0)
	var r: float = tier.radius + thickness * 0.5 + 0.003
	if style == Style.LACE:
		_build_lace(out, angles, r, y, w, color)
	else:
		_build_satin(out, angles, r, y, w, color)
	if bow:
		var a: float = angles.x
		var outward := Vector3(cos(a), 0.0, sin(a))
		var basis := Basis(outward.cross(Vector3.UP).normalized(), outward, Vector3.UP)
		var knot: MeshArrays = BowBuilder.make(w * 2.6, w * 0.85, thickness, color)
		add_transformed(out, knot, Transform3D(basis, outward * (r + thickness * 0.5) + Vector3(0.0, y - w * 0.15, 0.0)))
	return out


func _build_satin(out: MeshArrays, angles: Vector2, r: float, y: float, w: float, color: Color) -> void:
	var profile: ProfileShape = BowBuilder.band_profile(thickness / (w * 0.5), 18)
	var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, color, 0.0)
	var segments: int = maxi(int((angles.y - angles.x) * r / 0.03), 6)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for i in range(segments + 1):
		var a: float = lerpf(angles.x, angles.y, float(i) / float(segments))
		var outward := Vector3(cos(a), 0.0, sin(a))
		centers.append(outward * r + Vector3(0.0, y, 0.0))
		ups.append(outward)
		scales.append(w * 0.5)
	TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)


## Sugar lace: a thin sheet hugging the side, scalloped along its lower edge.
## The holes are cut by the lace shader from the texture coordinates
## (u = distance along in scallops, v = 0 at the top edge, 1 at the bottom).
func _build_lace(out: MeshArrays, angles: Vector2, r: float, y: float, w: float, color: Color) -> void:
	var length: float = (angles.y - angles.x) * r
	var count: int = maxi(int(round(length / scallop_length)), 1)
	var per_scallop: int = 8
	var columns: int = count * per_scallop
	var rows: int = 6
	var depth: float = scallop * w
	var start: int = out.vertex_count()
	for i in range(columns + 1):
		var t: float = float(i) / float(columns)
		var a: float = lerpf(angles.x, angles.y, t)
		var outward := Vector3(cos(a), 0.0, sin(a))
		var phase: float = fmod(t * float(count), 1.0)
		var dip: float = depth * pow(sin(phase * PI), 0.7)
		var top: float = y + w * 0.5
		var bottom: float = y - w * 0.5 - dip
		for k in range(rows + 1):
			var v: float = float(k) / float(rows)
			var h: float = lerpf(top, bottom, v)
			# The top edge curls in to meet the cake.
			var lift: float = thickness * (1.0 - 0.6 * pow(1.0 - v, 6.0))
			out.add_vertex(outward * (r - thickness * 0.5 + lift) + Vector3(0.0, h, 0.0), outward, color, Vector2(t * float(count), v))
	for i in range(columns):
		for k in range(rows):
			var a: int = start + i * (rows + 1) + k
			var b: int = a + rows + 1
			out.add_triangle(a, a + 1, b)
			out.add_triangle(b, a + 1, b + 1)


func remap_unique(decoration: DecorationData, old_tier: TierData, new_tier: TierData) -> DecorationData:
	var copy: DecorationData = decoration.duplicate_data()
	var y: float = copy.transform.origin.y
	var reach: float = half_height(copy.transform.basis.get_scale().y) * 1.6
	if y <= reach:
		pass
	elif y >= old_tier.height - reach:
		y = new_tier.height - (old_tier.height - y)
	else:
		y *= new_tier.height / maxf(old_tier.height, 0.001)
	copy.transform.origin.y = y
	return copy
