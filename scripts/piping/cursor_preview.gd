class_name CursorPreview
extends Node3D
## Shows exactly where and how big the next piping will land: an outline of
## the tip's opening lying on the surface, plus a faint ghost of what a
## single click would make (a dot, a star kiss, a flower...).

const OUTLINE_WIDTH: float = 0.012

var _outline := MeshInstance3D.new()
var _ghost := MeshInstance3D.new()
var _outline_material := StandardMaterial3D.new()
var _ghost_material := StandardMaterial3D.new()
var _key: String = ""


func _ready() -> void:
	name = "CursorPreview"
	top_level = true
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	_outline_material.render_priority = 1
	_outline_material.no_depth_test = false
	_outline.material_override = _outline_material
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)

	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.vertex_color_use_as_albedo = true
	_ghost_material.vertex_color_is_srgb = true
	_ghost_material.albedo_color = Color(1.0, 1.0, 1.0, 0.32)
	_ghost_material.roughness = 0.5
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	visible = false


## Rebuilds the preview shapes when the tip, size or colour changes.
func configure(tip: TipDefinition, size: float, color: Color, stripe: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var key: String = "%s:%.4f:%s:%s" % [tip.id, size, color.to_html(), stripe.to_html()]
	if key == _key:
		return
	_key = key
	_outline.mesh = _build_outline(tip, size)
	var builder := StrokeBuilder.new(tip, size, color, 1, stripe)
	builder.fallback_forward = Vector3.FORWARD
	builder.add_sample(Vector3.ZERO, Vector3.UP, 1.0)
	builder.finish()
	var ghost := MeshArrays.new()
	for piece in builder.pieces:
		ghost.append(piece)
	_ghost.mesh = ghost.to_mesh()
	# Outline in a slightly deeper shade of the colour so it reads on light frosting.
	var outline_color: Color = color.darkened(0.25)
	outline_color.a = 0.85
	_outline_material.albedo_color = outline_color


## Places the preview on the surface (world space).
func show_at(world_position: Vector3, world_normal: Vector3, forward_hint: Vector3) -> void:
	visible = true
	var y: Vector3 = world_normal.normalized()
	var z: Vector3 = forward_hint - y * forward_hint.dot(y)
	if z.length_squared() < 0.0001:
		z = TubeBuilder.any_perpendicular(y)
	z = z.normalized()
	var x: Vector3 = y.cross(z)
	global_transform = Transform3D(Basis(x, y, z), world_position + y * 0.003)


func set_ghost_visible(shown: bool) -> void:
	_ghost.visible = shown


# A thin loop matching the tip's opening, lying flat on the surface.
func _build_outline(tip: TipDefinition, size: float) -> ArrayMesh:
	var shape: ProfileShape = tip.shape()
	var out := MeshArrays.new()
	var count: int = shape.points.size()
	# Lay the profile flat: profile x across, profile y forward along the surface.
	var outer_scale: float = size * 1.0
	for j in range(count):
		var p: Vector2 = shape.points[j]
		var n: Vector2 = shape.normals[j]
		var inner: Vector2 = p * outer_scale - n * OUTLINE_WIDTH * 0.5
		var outer: Vector2 = p * outer_scale + n * OUTLINE_WIDTH * 0.5
		out.add_vertex(Vector3(inner.x, 0.0, inner.y), Vector3.UP, Color.WHITE, Vector2.ZERO)
		out.add_vertex(Vector3(outer.x, 0.0, outer.y), Vector3.UP, Color.WHITE, Vector2.ZERO)
	for j in range(count):
		var a: int = j * 2
		var b: int = ((j + 1) % count) * 2
		out.add_triangle(a, a + 1, b)
		out.add_triangle(b, a + 1, b + 1)
		# Second side so it shows from any angle.
		out.add_triangle(a, b, a + 1)
		out.add_triangle(b, b + 1, a + 1)
	return out.to_mesh()
