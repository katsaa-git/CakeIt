@tool
class_name LetterBuilder
extends DecorationBuilder
## Fondant letters and numbers: the player's words (DecorationData.text),
## cut out of thick fondant and laid side by side. On top of a tier they lie
## flat; on the side the word bends round the cake so every letter sits flush.

## Height of a capital letter, in game units (0.24 = 2.4 cm).
@export_range(0.05, 1.0) var letter_height: float = 0.24
@export_range(0.005, 0.08) var thickness: float = 0.026
@export var default_text: String = "LOVE"
## Longer words are cut short to this many letters.
@export_range(1, 24) var max_letters: int = 12

## Glyphs come out at this size and are then scaled to `letter_height`.
const FONT_SIZE: int = 64
const PIXEL: float = 0.004


func is_unique() -> bool:
	return true


func uses_text() -> bool:
	return true


func radius() -> float:
	return letter_height


func build() -> MeshArrays:
	return word(default_text, TINTABLE)


func build_unique(decoration: DecorationData, tier: TierData) -> MeshArrays:
	var text: String = decoration.text if not decoration.text.strip_edges().is_empty() else default_text
	var piece: MeshArrays = word(text, TINTABLE)
	wrap_round(piece, side_curve(decoration, tier))
	return baked(piece, Transform3D.IDENTITY, decoration.color)


## The word as one piece: lying in the XZ plane, reading along -X when seen
## from above with +Z up the screen (so it reads left to right), standing
## `thickness` out of the surface, centred on the origin.
func word(text: String, color: Color) -> MeshArrays:
	var out := MeshArrays.new()
	var clean: String = text.strip_edges().left(max_letters)
	if clean.is_empty():
		return out
	var mesh := TextMesh.new()
	mesh.text = clean
	mesh.font = UiTheme.font(true)
	mesh.font_size = FONT_SIZE
	mesh.pixel_size = PIXEL
	mesh.depth = thickness
	mesh.curve_step = 1.2
	var arrays: Array = mesh.get_mesh_arrays()
	if arrays.is_empty():
		return out
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.is_empty():
		return out
	var glyphs := MeshArrays.new()
	glyphs.verts = verts
	glyphs.normals = normals
	glyphs.colors.resize(verts.size())
	glyphs.colors.fill(color)
	glyphs.uvs.resize(verts.size())
	if indices.is_empty():
		for i in range(verts.size()):
			glyphs.indices.append(i)
	else:
		glyphs.indices = indices
	var box: AABB = glyphs.bounds()
	# A capital letter is about 70% of the font's line height.
	var scale: float = letter_height / maxf(float(FONT_SIZE) * PIXEL * 0.72, 0.001)
	# Text x -> -X, text up -> +Z, text front -> +Y (a proper turn, so faces
	# keep their winding).
	var lay := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0)).scaled(Vector3.ONE * scale)
	var middle: Vector3 = box.get_center()
	var offset := Vector3(middle.x, middle.y, box.position.z)
	add_transformed(out, glyphs, Transform3D(lay, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -offset))
	return out
