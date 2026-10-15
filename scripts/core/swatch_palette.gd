@tool
class_name SwatchPalette
extends Resource
## A named set of colours shown as swatches (one .tres per palette in
## data/palettes/). Frosting, sprinkles and metallics each have their own.

@export var id: StringName = &""
@export var display_name: String = ""
@export var colors: PackedColorArray = PackedColorArray()
@export var names: PackedStringArray = PackedStringArray()


func size() -> int:
	return colors.size()


func color_name(index: int) -> String:
	return names[index] if index >= 0 and index < names.size() else ""


func index_of(color: Color) -> int:
	for i in range(colors.size()):
		if colors[i].is_equal_approx(color):
			return i
	return -1
