class_name TierMaterials
extends RefCounted
## The materials one tier's piping and decorations are drawn with, so each
## tier can show its own lustre dust. They are copies of the shared
## materials (same shader, so no extra cost per draw) that also carry this
## tier's dust mask and size. The stand's plate uses the shared materials
## (it has no dust).

var buttercream: ShaderMaterial
var mask_texture: ImageTexture
var has_dust: bool = false

var _board: bool = false
var _decorations: Dictionary = {}
var _extra: Array[ShaderMaterial] = []
## radius, height, bottom height, dust on/off (see shimmer.gdshaderinc)
var _frame := Vector4(1.0, 1.0, 0.0, 0.0)


func _init(board: bool = false) -> void:
	_board = board
	if board:
		buttercream = Materials.buttercream()
		return
	buttercream = Materials.buttercream().duplicate() as ShaderMaterial
	mask_texture = ImageTexture.create_from_image(Image.create_empty(ShimmerMask.WIDTH, ShimmerMask.HEIGHT, false, Image.FORMAT_RGBA8))
	_apply(buttercream)


## The material for a decoration on this tier.
func decoration(definition: DecorationDefinition) -> Material:
	if _board:
		return definition.material()
	var material: ShaderMaterial = _decorations.get(definition.id)
	if material == null:
		material = definition.material().duplicate() as ShaderMaterial
		_apply(material)
		_decorations[definition.id] = material
	return material


## Also keep `material` (the tier's own frosting) up to date with the dust.
func register(material: ShaderMaterial) -> void:
	_extra.append(material)
	_apply(material)


## The tier's size and height on the stack changed.
func set_frame(radius: float, height: float, base_y: float) -> void:
	var frame := Vector4(radius, height, base_y, _frame.w)
	if frame == _frame:
		return
	_frame = frame
	_apply_all()


## New dust (or none). `rect` is the part that changed (empty = all).
func set_dust(mask: ShimmerMask, _rect: Rect2i = Rect2i()) -> void:
	if _board:
		return
	var any: bool = mask != null and not mask.is_empty()
	if any:
		mask_texture.update(mask.image)
	var on: float = 1.0 if any else 0.0
	if on != _frame.w:
		_frame.w = on
		_apply_all()
	has_dust = any


func _apply_all() -> void:
	_apply(buttercream)
	for material: ShaderMaterial in _decorations.values():
		_apply(material)
	for material in _extra:
		_apply(material)


func _apply(material: ShaderMaterial) -> void:
	if _board:
		return
	material.set_shader_parameter("shimmer_mask", mask_texture)
	material.set_shader_parameter("shimmer_tier", _frame)
