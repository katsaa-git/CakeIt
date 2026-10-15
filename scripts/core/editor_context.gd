class_name EditorContext
extends RefCounted
## Shared state for the decorating tools and the interface: the cake, the
## undo history, the scene helpers, and the player's current choices (tip,
## size, colour, active tool). Tools and UI talk through this instead of
## holding references to each other.

signal tool_changed(tool_id: StringName)
signal tip_changed(tip: TipDefinition)
signal size_changed(size: float, preset_index: int)
signal color_changed(color: Color)
signal decoration_changed(definition: Resource)
signal message(text: String)
signal tier_selection_changed(tier_id: int)
signal coat_style_changed(naked: bool)

var model: CakeModel
var commands: CommandStack
var view: CakeView
var picker: CakePicker
var camera: OrbitCamera
var turntable: Turntable

var tool_id: StringName = &"pipe"
var tip: TipDefinition
## Current tip radius in game units.
var size: float = 0.06
## 0..2 for a named preset, -1 after fine-tuning.
var size_index: int = 1
var color: Color = Color(1.0, 0.97, 0.92)
var decoration: Resource
## True while the mouse is over an interface panel.
var pointer_over_ui: bool = false
## The tier picked with the tier tool (0 = none).
var selected_tier_id: int = 0
## Coat tool: true applies the semi-naked sponge look instead of a full coat.
var coat_naked: bool = false


func set_tool(id: StringName) -> void:
	if id == tool_id:
		return
	tool_id = id
	tool_changed.emit(id)


func set_tip(new_tip: TipDefinition) -> void:
	if new_tip == null:
		return
	tip = new_tip
	tip_changed.emit(tip)
	# Keep the same named size (Small/Medium/Large) on the new tip.
	set_size_index(size_index if size_index >= 0 else 1)


func cycle_tip(step: int) -> void:
	var tips: Array[TipDefinition] = Content.tips()
	if tips.is_empty():
		return
	var index: int = tips.find(tip)
	set_tip(tips[posmod(index + step, tips.size())])


func set_size_index(index: int) -> void:
	size_index = clampi(index, 0, 2)
	size = tip.preset_size(size_index) if tip != null else 0.06
	size_changed.emit(size, size_index)


## Fine-tunes the size by a factor (e.g. 1.08 bigger, 0.92 smaller).
func adjust_size(factor: float) -> void:
	var new_size: float = size * factor
	if tip != null:
		new_size = tip.clamp_size(new_size)
	size = new_size
	size_index = -1
	if tip != null:
		for i in range(tip.size_presets.size()):
			if absf(tip.size_presets[i] - size) < 0.0015:
				size_index = i
	size_changed.emit(size, size_index)


func set_color(new_color: Color) -> void:
	color = new_color
	color_changed.emit(color)


func set_decoration(definition: Resource) -> void:
	decoration = definition
	decoration_changed.emit(definition)


func toast(text: String) -> void:
	message.emit(text)


func select_tier(tier_id: int) -> void:
	if tier_id == selected_tier_id:
		return
	selected_tier_id = tier_id
	tier_selection_changed.emit(tier_id)


func set_coat_naked(naked: bool) -> void:
	coat_naked = naked
	coat_style_changed.emit(naked)
