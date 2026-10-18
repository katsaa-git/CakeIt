@tool
class_name SwatchPalette
extends Resource
## A named set of colours shown as swatches (one .tres per palette in
## data/palettes/), each palette a tab of the colour panel.
##
## A palette can also hold named colour mixes (`mix_names` and `mix_sizes`
## say how `colors` is cut into mixes): picking a mix gives every
## decoration placed a random one of its colours, and recolours mixed
## sprinkles.

## Tab order in the colour panel.
@export var sort_order: int = 0
@export var id: StringName = &""
@export var display_name: String = ""
@export var colors: PackedColorArray = PackedColorArray()
@export var names: PackedStringArray = PackedStringArray()
## Finish for each colour (0 plain, 1 metallic, about 0.5 pearl); empty =
## all plain.
@export var shines: PackedFloat32Array = PackedFloat32Array()
## For a palette of mixes: how many of `colors` each mix takes, in order.
@export var mix_sizes: PackedInt32Array = PackedInt32Array()
## Only offered with these tools (empty = all).
@export var tools: PackedStringArray = PackedStringArray()


func size() -> int:
	return colors.size()


func color_name(index: int) -> String:
	return names[index] if index >= 0 and index < names.size() else ""


func shine(index: int) -> float:
	return shines[index] if index >= 0 and index < shines.size() else 0.0


func index_of(color: Color) -> int:
	for i in range(colors.size()):
		if colors[i].is_equal_approx(color):
			return i
	return -1


func is_mixes() -> bool:
	return not mix_sizes.is_empty()


## The colours of mix `index`.
func mix(index: int) -> PackedColorArray:
	var start: int = 0
	for i in range(index):
		start += mix_sizes[i]
	return colors.slice(start, start + mix_sizes[index])


func offered_for(tool_id: StringName) -> bool:
	return tools.is_empty() or tools.has(String(tool_id))


## Problems with this palette, for the content check in the tests.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"" or display_name.is_empty():
		problems.append("%s: needs an id and a name" % id)
	if is_mixes():
		var total: int = 0
		for count in mix_sizes:
			total += count
		if total != colors.size():
			problems.append("%s: mix sizes add up to %d, not %d colours" % [id, total, colors.size()])
		if names.size() != mix_sizes.size():
			problems.append("%s: every mix needs a name" % id)
	elif names.size() != colors.size():
		problems.append("%s: every colour needs a name" % id)
	if not shines.is_empty() and shines.size() != colors.size():
		problems.append("%s: shines and colours differ in length" % id)
	return problems
