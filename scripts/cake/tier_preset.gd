@tool
class_name TierPreset
extends Resource
## A named tier size choice: either a width or a height (one .tres per preset
## in data/tiers/). The tier tool shows these as buttons.

enum Kind { WIDTH, HEIGHT }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.WIDTH
## Radius for WIDTH presets, height for HEIGHT presets (game units, 1 = 10 cm).
@export var value: float = 1.0
@export var sort_order: int = 0


## Real-world size for tooltips, e.g. "22 cm wide".
func describe() -> String:
	if kind == Kind.WIDTH:
		return "%d cm wide" % roundi(value * 20.0)
	return "%d cm tall" % roundi(value * 10.0)
