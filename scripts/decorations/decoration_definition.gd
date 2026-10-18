@tool
class_name DecorationDefinition
extends Resource
## One kind of decoration (sprinkles, a cherry, a candle...), described as
## data: one .tres per decoration in data/decorations/. The `builder` makes
## its mesh; everything about how it is placed and how it looks is here.

enum Placement {
	## One per click.
	SINGLE,
	## Evenly spaced along a drag (a click places one).
	LINE,
	## Sprayed around the cursor while the button is held.
	SCATTER,
	## Dragged along a tier's top edge (ganache drips).
	RIM,
	## Dragged round the side of a tier at one height (ribbons, lace trim).
	BAND,
}

enum ColorMode {
	## The colour picked in the palette (or a random one of the picked mix).
	PICKED,
	## Always the first of `colors`.
	FIXED,
	## A random one of `colors` for every piece (rainbow sprinkles), or of
	## the colour mix picked in the palette.
	MIX,
}

enum Align {
	## Sits on the surface, standing out along its normal.
	SURFACE,
	## Always stands straight up (candles, toppers).
	UPRIGHT,
}

enum Facing {
	## A random turn for every piece.
	RANDOM,
	## The shape's top points up the screen (or, upright, its front faces the camera).
	VIEWER,
}

## Shelf tabs, in order, with their names.
const CATEGORIES: Array = [
	[&"sprinkles", "Sprinkles"],
	[&"sweets", "Pearls"],
	[&"chocolate", "Chocolate"],
	[&"fondant", "Fondant"],
	[&"flowers", "Flowers"],
	[&"fruit", "Fruit"],
	[&"treats", "Treats"],
	[&"ribbons", "Ribbons"],
	[&"party", "Candles & toppers"],
]

const SHADER: Shader = preload("res://art/shaders/decoration.gdshader")

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: StringName = &"sprinkles"
## Position in its category (lower comes first).
@export var sort_order: int = 0
## Free-form tags for future scoring, e.g. "chocolate", "floral".
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Placement")
@export var placement: Placement = Placement.SINGLE
@export var align: Align = Align.SURFACE
@export var facing: Facing = Facing.RANDOM
## Only on top of a tier (or the stand), never on the sides.
@export var top_only: bool = false
## LINE: distance between pieces, in piece radii.
@export_range(0.5, 6.0) var spacing: float = 2.2
## SCATTER: radius of the spray, in game units.
@export_range(0.02, 1.0) var brush_radius: float = 0.18
## SCATTER: pieces per second while held.
@export_range(1.0, 400.0) var rate: float = 60.0
## How deep a piece sinks into the surface, in piece radii.
@export_range(0.0, 1.0) var sink: float = 0.1
## Random tilt, in degrees.
@export_range(0.0, 90.0) var max_tilt: float = 0.0
## Random size variation (0.1 = up to 10% bigger or smaller).
@export_range(0.0, 0.6) var size_jitter: float = 0.08

@export_group("Look")
@export var builder: DecorationBuilder
## Other shapes mixed in (a sprinkle medley of rods, stars and pearls): each
## piece is one of `builder` or these, chosen by its random seed.
@export var variants: Array[DecorationBuilder] = []
## Optional hand-made model (.glb) shown instead of the built mesh.
@export var scene_override: PackedScene
## Optional shader instead of the usual decoration shader (lace).
@export var shader_override: Shader
@export var color_mode: ColorMode = ColorMode.PICKED
@export var colors: PackedColorArray = PackedColorArray()
@export_range(0.0, 1.0) var roughness: float = 0.45
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var specular: float = 0.5
@export_range(0.0, 1.0) var clearcoat: float = 0.0
@export_range(0.0, 1.0) var subsurface: float = 0.0
## Pearly, rainbow-tinted sheen at grazing angles.
@export_range(0.0, 1.0) var pearl: float = 0.0
## Soft velvet-like glow at grazing angles (satin ribbon, fuzzy fruit).
@export_range(0.0, 1.0) var sheen: float = 0.0
@export var casts_shadow: bool = true

@export_group("Sizes")
@export var size_names: PackedStringArray = PackedStringArray(["Small", "Medium", "Large"])
## Multipliers of the built size.
@export var size_presets: PackedFloat32Array = PackedFloat32Array([0.75, 1.0, 1.35])

var _meshes: Dictionary = {}
var _arrays: Dictionary = {}
var _material: ShaderMaterial


static func category_name(category_id: StringName) -> String:
	for entry: Array in CATEGORIES:
		if entry[0] == category_id:
			return entry[1]
	return String(category_id).capitalize()


## How many different shapes this decoration mixes (1 for most).
func variant_count() -> int:
	return 1 + variants.size()


## Which shape a piece with this seed gets (stable, so it saves for free).
func variant_for(seed_value: int) -> int:
	if variants.is_empty():
		return 0
	return absi(hash(seed_value * 31 + 7)) % variant_count()


func builder_for(variant: int) -> DecorationBuilder:
	if variant <= 0 or variant > variants.size():
		return builder
	return variants[variant - 1]


## The shared mesh for one piece at size 1 (built once per shape).
func mesh(variant: int = 0) -> ArrayMesh:
	if not _meshes.has(variant):
		_meshes[variant] = arrays(variant).to_mesh()
	return _meshes[variant]


## The raw geometry for one piece at size 1, for baking previews.
func arrays(variant: int = 0) -> MeshArrays:
	if not _arrays.has(variant):
		var shape: DecorationBuilder = builder_for(variant)
		_arrays[variant] = shape.build() if shape != null else MeshArrays.new()
	return _arrays[variant]


func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = shader_override if shader_override != null else SHADER
		_material.set_shader_parameter("roughness", roughness)
		_material.set_shader_parameter("metallic", metallic)
		_material.set_shader_parameter("specular_amount", specular)
		_material.set_shader_parameter("clearcoat", clearcoat)
		_material.set_shader_parameter("sss", subsurface)
		_material.set_shader_parameter("pearl", pearl)
		_material.set_shader_parameter("sheen", sheen)
	return _material


## True when pieces are built one by one (drips, ribbons, signs, letters).
func is_unique() -> bool:
	return scene_override != null or (builder != null and builder.is_unique())


## True when the player types words for it (topper signs, plaques, letters).
func uses_text() -> bool:
	return builder != null and builder.uses_text()


## A little arrangement for the shelf card's picture: one piece, a string of
## three, a small pile for sprays, or a drip or ribbon on a mini cake. Pieces
## that take the picked colour are white (the card tints them).
func preview_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := MeshArrays.new()
	var r: float = radius()
	if placement == Placement.RIM or placement == Placement.BAND:
		var tier := TierData.new()
		tier.radius = 0.45
		tier.height = 0.32
		var profile: Dictionary = LatheMesh.rounded_cylinder_profile(tier.radius, tier.height, 0.03, 4)
		out.append(LatheMesh.build_arrays(profile["points"], profile["normals"], 64, Callable(), 0, Color(1.0, 0.96, 0.9, 0.0)))
		var piece := DecorationData.new()
		piece.color = Color(0.36, 0.22, 0.15) if placement == Placement.RIM and uses_palette() else pick_color(Color.WHITE, rng)
		piece.rng_seed = 3
		if placement == Placement.RIM:
			piece.path = PackedFloat32Array([PI * 0.5 - 1.4, PI * 0.5 + 1.4])
		else:
			piece.path = PackedFloat32Array([PI * 0.5 - 0.1, PI * 0.5 - 0.1 + TAU])
			piece.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), Vector3(0.0, tier.height * 0.3, 0.0))
		out.append(builder.build_unique(piece, tier))
	elif is_unique():
		out = DecorationBuilder.baked(arrays(), Transform3D.IDENTITY, Color.WHITE)
	else:
		var places: Array[Transform3D] = []
		match placement:
			Placement.SCATTER:
				for i in range(18):
					var a: float = rng.randf() * TAU
					var d: float = sqrt(rng.randf()) * r * 3.2
					places.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, 0.0, sin(a) * d)))
			Placement.LINE:
				for i in range(3):
					places.append(Transform3D(Basis.IDENTITY, Vector3((float(i) - 1.0) * r * spacing, 0.0, 0.0)))
			_:
				places.append(Transform3D(Basis(Vector3.UP, 0.4), Vector3.ZERO))
		for i in range(places.size()):
			var tint: Color = Color.WHITE if uses_palette() else pick_color(Color.WHITE, rng)
			var variant: int = i % variant_count()
			out.append(DecorationBuilder.baked(arrays(variant), places[i], tint))
	return out.to_mesh(material())


## Rough radius of one piece at size 1, in game units.
func radius() -> float:
	return builder.radius() if builder != null else 0.05


func preset_size(index: int) -> float:
	if size_presets.is_empty():
		return 1.0
	return size_presets[clampi(index, 0, size_presets.size() - 1)]


func preset_name(index: int) -> String:
	return size_names[index] if index >= 0 and index < size_names.size() else "Custom"


## The colour for a new piece, given the colour (or colour mix) picked in
## the palette.
func pick_color(picked: Color, rng: RandomNumberGenerator, mix: PackedColorArray = PackedColorArray()) -> Color:
	match color_mode:
		ColorMode.FIXED:
			return colors[0] if not colors.is_empty() else Color.WHITE
		ColorMode.MIX:
			if not mix.is_empty():
				return mix[rng.randi() % mix.size()]
			return colors[rng.randi() % colors.size()] if not colors.is_empty() else picked
	if not mix.is_empty():
		return mix[rng.randi() % mix.size()]
	return picked


## True when pieces take the colour picked in the palette.
func uses_palette() -> bool:
	return color_mode == ColorMode.PICKED


## True when a colour mix picked in the palette changes this decoration.
func takes_mix() -> bool:
	return color_mode != ColorMode.FIXED


## Problems with this definition, for the content check in the tests.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("missing id")
	if display_name.is_empty():
		problems.append("%s: missing display_name" % id)
	if description.is_empty():
		problems.append("%s: missing description (the shelf tooltip)" % id)
	if builder == null and scene_override == null:
		problems.append("%s: needs a builder or a scene" % id)
	for variant in variants:
		if variant == null:
			problems.append("%s: an empty variant" % id)
	var known: bool = false
	for entry: Array in CATEGORIES:
		known = known or entry[0] == category
	if not known:
		problems.append("%s: unknown category %s" % [id, category])
	if color_mode != ColorMode.PICKED and colors.is_empty():
		problems.append("%s: fixed or mixed colours need a colour list" % id)
	if size_presets.size() != 3 or size_names.size() != 3:
		problems.append("%s: needs exactly 3 sizes with names" % id)
	if (placement == Placement.RIM or placement == Placement.BAND) and (builder == null or not builder.is_unique()):
		problems.append("%s: rim and band decorations need a builder that builds per decoration" % id)
	if not variants.is_empty() and is_unique():
		problems.append("%s: pieces built one by one cannot mix shapes" % id)
	return problems
