@tool
class_name TipDefinition
extends Resource
## One piping tip, described entirely as data (one .tres file per tip in
## data/tips/). Adding a new tip means adding a file, not changing code.
##
## Sizes are tip radii in game units (1 unit = 10 cm, so 0.07 = a 1.4 cm wide line).

enum Behavior {
	## A continuous line that follows the mouse.
	CONTINUOUS,
	## Repeated shapes (flowers, shells, tufts) placed along the drag.
	STAMP,
}

enum EndStyle {
	## A soft rounded end.
	ROUND,
	## A little pulled-up peak, like lifting the bag away.
	PEAK,
	## Tapers to a flat point (leaves).
	POINT,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Position in the tip shelf (lower comes first).
@export var sort_order: int = 0
## Free-form tags for future scoring and filtering, e.g. "border", "floral".
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Shape")
@export var profile: TipProfile
@export var behavior: Behavior = Behavior.CONTINUOUS
## Used when behavior is STAMP.
@export var stamp: StampShape
## Distance between stamps, in tip radii.
@export_range(0.3, 6.0) var stamp_spacing: float = 1.8
## How far the centre of the bead sits above the surface, in tip radii.
@export_range(-0.5, 1.5) var lift: float = 0.5
@export var end_style: EndStyle = EndStyle.ROUND
## Length of a PEAK or POINT end, in tip radii.
@export_range(0.5, 5.0) var end_length: float = 1.6
## Height of a single click (a dot, kiss or rosette), in tip radii.
@export_range(0.3, 3.0) var dollop_height: float = 1.0
## How much a single click twists as it rises (radians), like turning the bag.
@export_range(0.0, 6.0) var dollop_twist: float = 0.0

@export_group("Feel")
## Distance between mesh rings, in tip radii. Smaller is smoother but heavier.
@export_range(0.15, 1.0) var ring_spacing: float = 0.3
## How much faster strokes get thinner (0 = never).
@export_range(0.0, 0.5) var speed_thinning: float = 0.15
## Extra thickness gained by holding still (0 = none).
@export_range(0.0, 1.5) var dwell_growth: float = 0.7
## Ruffle: sideways wobble of the frilly edge, in tip radii.
@export_range(0.0, 1.0) var wave_amplitude: float = 0.0
## Ruffle: length of one wobble, in tip radii.
@export_range(0.5, 8.0) var wave_length: float = 2.0
## Rope-like twist along a line, radians per tip radius travelled.
@export_range(-2.0, 2.0) var twist_rate: float = 0.0

@export_group("Sizes")
@export var size_names: PackedStringArray = PackedStringArray(["Small", "Medium", "Large"])
@export var size_presets: PackedFloat32Array = PackedFloat32Array([0.04, 0.07, 0.11])
@export var min_size: float = 0.025
@export var max_size: float = 0.18

var _shape_cache: ProfileShape


## The cross-section, built once and shared by every stroke with this tip.
func shape() -> ProfileShape:
	if _shape_cache == null:
		if profile != null:
			_shape_cache = profile.build()
		else:
			_shape_cache = ProfileShape.circle(16, 0.9)
	return _shape_cache


func preset_size(index: int) -> float:
	if size_presets.is_empty():
		return 0.07
	return size_presets[clampi(index, 0, size_presets.size() - 1)]


func preset_name(index: int) -> String:
	if index < 0 or index >= size_names.size():
		return "Custom"
	return size_names[index]


func clamp_size(size: float) -> float:
	return clampf(size, min_size, max_size)


## Problems with this definition, for the content check in the tests.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("missing id")
	if display_name.is_empty():
		problems.append("%s: missing display_name" % id)
	if size_presets.size() != 3:
		problems.append("%s: needs exactly 3 size presets" % id)
	if size_names.size() != size_presets.size():
		problems.append("%s: size_names and size_presets differ in length" % id)
	if behavior == Behavior.STAMP and stamp == null:
		problems.append("%s: stamp tip without a stamp shape" % id)
	if behavior == Behavior.CONTINUOUS and profile == null:
		problems.append("%s: continuous tip without a profile" % id)
	return problems
