@tool
class_name TopperBuilder
extends DecorationBuilder
## A cake topper: a little scalloped plaque in the picked colour on two
## wooden sticks, with words on it (`DecorationData.text`).

@export_range(0.1, 1.2) var width: float = 0.56
@export_range(0.05, 0.6) var height: float = 0.24
## How high the plaque's bottom edge stands above the cake.
@export_range(0.05, 0.8) var lift: float = 0.28
@export var stick_color: Color = Color(0.8, 0.64, 0.45)
@export var text_color: Color = Color(0.4, 0.26, 0.2)
@export var default_text: String = "Happy Birthday!"

const THICKNESS: float = 0.02


func is_unique() -> bool:
	return true


func radius() -> float:
	return width * 0.5


## The plaque and sticks in the picked colour (also used for previews).
func build() -> MeshArrays:
	var out := MeshArrays.new()
	var outline := PackedVector2Array()
	var count: int = 96
	for k in range(count):
		var a: float = TAU * float(k) / float(count)
		var c: float = cos(a)
		var s: float = sin(a)
		var p := Vector2(signf(c) * pow(absf(c), 0.35), signf(s) * pow(absf(s), 0.35))
		# A gently scalloped edge.
		p *= 1.0 - 0.035 * (0.5 + 0.5 * cos(a * 18.0))
		outline.append(Vector2(p.x * width * 0.5, p.y * height * 0.5))
	var plaque: MeshArrays = extrude(outline, THICKNESS, TINTABLE, true)
	# Stand it up: the outline's top becomes up, its face looks toward +Z.
	var stand := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
	add_transformed(out, plaque, Transform3D(stand, Vector3(0.0, lift + height * 0.5, -THICKNESS * 0.5)))
	var stick: Dictionary = LatheMesh.rounded_cylinder_profile(0.007, lift + height * 0.4 + 0.12, 0.003, 2)
	var stick_arrays: MeshArrays = LatheMesh.build_arrays(stick["points"], stick["normals"], 8, Callable(), 0, Color(stick_color.r, stick_color.g, stick_color.b, 0.0))
	for x in [-width * 0.28, width * 0.28]:
		add_transformed(out, stick_arrays, Transform3D(Basis.IDENTITY, Vector3(x, -0.12, -THICKNESS * 1.1)))
	return out


func build_unique(decoration: DecorationData, _tier: TierData) -> MeshArrays:
	return baked(build(), Transform3D.IDENTITY, decoration.color)


func add_extras(node: Node3D, decoration: DecorationData) -> void:
	var label := Label3D.new()
	label.name = "Words"
	label.text = decoration.text if not decoration.text.is_empty() else default_text
	label.font = UiTheme.font(true)
	label.font_size = 64
	label.pixel_size = 0.0011
	label.outline_size = 0
	label.modulate = text_color
	label.double_sided = false
	label.shaded = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = width * 0.86 / label.pixel_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, lift + height * 0.5, THICKNESS * 0.5 + 0.002)
	# Long words get smaller so they still fit on two lines.
	var widest: float = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
	if widest > width * 0.86 * 2.0:
		label.font_size = int(float(label.font_size) * width * 0.86 * 2.0 / widest)
	node.add_child(label)
