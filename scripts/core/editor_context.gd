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
signal decoration_size_changed(index: int)
## A colour mix was picked in the palette (empty = none).
signal mix_changed(colors: PackedColorArray)
## The two-tone bag was switched on or off, or its second colour changed.
signal stripe_changed(on: bool, color: Color)
## Which colour the palette is setting: 0 the main colour, 1 the stripe.
signal color_slot_changed(slot: int)
## The dust brush's size, strength or eraser changed.
signal dust_changed

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
## Decorations: the chosen size preset (0..2) and the words for topper signs.
var decoration_size_index: int = 1
var decoration_text: String = "Happy Birthday!"
## Finish of the picked colour: 0 plain, 1 metallic (metallic swatches).
var shine: float = 0.0
## A colour mix picked for decorations (empty = just the one colour).
var mix := PackedColorArray()
var mix_name: String = ""
## Two-tone piping bag and its second colour.
var two_tone: bool = false
var stripe_color: Color = Color(1.0, 0.97, 0.93)
## 0: the palette sets the main colour; 1: it sets the stripe.
var color_slot: int = 0
## Dust brush: size and strength presets (0..2) and whether it brushes off.
var dust_size_index: int = 1
var dust_strength_index: int = 1
var dust_erase: bool = false


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


## Picks a colour (and its finish: 1 for metallic swatches). While the
## two-tone bag's stripe slot is chosen, this sets the stripe instead.
func set_color(new_color: Color, new_shine: float = 0.0) -> void:
	if color_slot == 1 and tool_id == &"pipe":
		stripe_color = Color(new_color, 1.0)
		stripe_changed.emit(two_tone, stripe_color)
		return
	color = Color(new_color, 1.0)
	shine = clampf(new_shine, 0.0, 1.0)
	if not mix.is_empty():
		mix = PackedColorArray()
		mix_name = ""
		mix_changed.emit(mix)
	color_changed.emit(color)


## Picks a colour mix for decorations (each piece takes one of its colours).
func set_mix(colors: PackedColorArray, mix_title: String = "") -> void:
	mix = colors.duplicate()
	mix_name = mix_title
	mix_changed.emit(mix)


## The stripe colour as stored with a stroke (alpha 0 when the bag is plain).
func stripe() -> Color:
	return stripe_color if two_tone else Color(0.0, 0.0, 0.0, 0.0)


func set_two_tone(on: bool) -> void:
	two_tone = on
	if not on and color_slot == 1:
		set_color_slot(0)
	stripe_changed.emit(two_tone, stripe_color)


func set_color_slot(slot: int) -> void:
	color_slot = clampi(slot, 0, 1)
	color_slot_changed.emit(color_slot)


func set_dust(size_index: int, strength_index: int, erase: bool) -> void:
	dust_size_index = clampi(size_index, 0, 2)
	dust_strength_index = clampi(strength_index, 0, 2)
	dust_erase = erase
	dust_changed.emit()


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


func set_decoration_size_index(index: int) -> void:
	decoration_size_index = clampi(index, 0, 2)
	decoration_size_changed.emit(decoration_size_index)
