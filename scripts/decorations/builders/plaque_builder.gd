@tool
class_name PlaqueBuilder
extends DecorationBuilder
## A fondant plaque: a smooth oval with a softly scalloped edge, laid flat on
## the cake with the player's words on it (DecorationData.text). On the side
## of a tier it bends round the cake.

@export_range(0.2, 1.5) var width: float = 0.8
@export_range(0.1, 1.0) var height: float = 0.48
@export_range(0.005, 0.06) var thickness: float = 0.024
@export var text_color: Color = Color(0.4, 0.26, 0.2)
@export var default_text: String = "Congratulations"


func is_unique() -> bool:
	return true


func uses_text() -> bool:
	return true


func radius() -> float:
	return width * 0.5


func build() -> MeshArrays:
	var outline := PackedVector2Array()
	var count: int = 120
	for k in range(count):
		var a: float = TAU * float(k) / float(count)
		var c: float = cos(a)
		var s: float = sin(a)
		var p := Vector2(signf(c) * pow(absf(c), 0.7), signf(s) * pow(absf(s), 0.7))
		# A gently scalloped edge.
		p *= 1.0 - 0.03 * (0.5 + 0.5 * cos(a * 22.0))
		outline.append(Vector2(p.x * width * 0.5, p.y * height * 0.5))
	return extrude(outline, thickness, TINTABLE)


func build_unique(decoration: DecorationData, tier: TierData) -> MeshArrays:
	var piece: MeshArrays = build()
	wrap_round(piece, side_curve(decoration, tier))
	return baked(piece, Transform3D.IDENTITY, decoration.color)


func add_extras(node: Node3D, decoration: DecorationData) -> void:
	var label := Label3D.new()
	label.name = "Words"
	label.text = decoration.text if not decoration.text.strip_edges().is_empty() else default_text
	label.font = UiTheme.font(true)
	label.font_size = 64
	label.pixel_size = 0.0011
	label.outline_size = 0
	label.modulate = text_color
	label.double_sided = false
	label.shaded = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = width * 0.8 / label.pixel_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Lying on the plaque, reading the right way up the screen.
	label.transform = Transform3D(Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0)), Vector3(0.0, thickness + 0.003, 0.0))
	var widest: float = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
	if widest > width * 0.8 * 2.0:
		label.font_size = int(float(label.font_size) * width * 0.8 * 2.0 / widest)
	node.add_child(label)
