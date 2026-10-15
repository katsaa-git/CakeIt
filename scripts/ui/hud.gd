class_name Hud
extends CanvasLayer
## The decorating interface. Built entirely in code.
## (Interim layout; the full cozy interface replaces this in the UI milestone.)

signal add_tier_pressed
signal photo_pressed

const PALETTE: Array[Color] = [
	Color(1.0, 0.97, 0.92),
	Color(0.97, 0.76, 0.8),
	Color(0.73, 0.88, 0.8),
	Color(0.68, 0.82, 0.92),
	Color(0.99, 0.88, 0.6),
	Color(0.45, 0.29, 0.21),
]

var context: EditorContext
var tools: ToolController

var _tip_buttons: Dictionary = {}
var _size_buttons: Array[Button] = []
var _size_label: Label
var _toast: Label
var _toast_tween: Tween
var _root: Control


func setup(new_context: EditorContext, new_tools: ToolController) -> void:
	context = new_context
	tools = new_tools
	layer = 10
	name = "Hud"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(_make_help())
	_root.add_child(_make_toast())
	_root.add_child(_make_bar())
	context.tip_changed.connect(_show_tip)
	context.size_changed.connect(_show_size)
	context.message.connect(show_toast)
	_show_tip(context.tip)
	_show_size(context.size, context.size_index)


func set_interface_visible(shown: bool) -> void:
	_root.visible = shown


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _show_tip(tip: TipDefinition) -> void:
	if tip != null and _tip_buttons.has(tip.id):
		(_tip_buttons[tip.id] as Button).button_pressed = true
	for i in range(_size_buttons.size()):
		_size_buttons[i].text = tip.preset_name(i) if tip != null else str(i + 1)


func _show_size(size: float, index: int) -> void:
	_size_label.text = "%.1f cm" % (size * 20.0)
	if index >= 0 and index < _size_buttons.size():
		_size_buttons[index].button_pressed = true


func _make_help() -> Label:
	var label := Label.new()
	label.text = "Left-drag: pipe   Right-drag: orbit   Wheel: zoom   Middle-drag: pan\nDrag the plate rim (or Space+drag): spin   A/D: spin   R: auto-spin\nCtrl+Z / Ctrl+Y: undo / redo   1 2 3: size   Ctrl+Wheel or [ ]: fine size   Tab: next tip"
	label.position = Vector2(16.0, 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.18))
	return label


func _make_toast() -> Label:
	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = 16.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_color_override("font_color", Color(0.3, 0.22, 0.18))
	_toast.modulate.a = 0.0
	return _toast


func _make_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_bottom = -16.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.95, 0.88)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10.0)
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var tip_group := ButtonGroup.new()
	for tip in Content.tips():
		var tip_button := _button(tip.display_name, tip.description)
		tip_button.toggle_mode = true
		tip_button.button_group = tip_group
		tip_button.pressed.connect(func() -> void: context.set_tip(tip))
		_tip_buttons[tip.id] = tip_button
		row.add_child(tip_button)
	row.add_child(VSeparator.new())

	var size_group := ButtonGroup.new()
	for i in range(3):
		var size_button := _button(str(i + 1), "Tip size (%d)" % (i + 1))
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.pressed.connect(func() -> void: context.set_size_index(i))
		_size_buttons.append(size_button)
		row.add_child(size_button)
	_size_label = Label.new()
	_size_label.custom_minimum_size = Vector2(56.0, 0.0)
	_size_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.18))
	row.add_child(_size_label)
	row.add_child(VSeparator.new())

	for color in PALETTE:
		row.add_child(_swatch(color))
	row.add_child(VSeparator.new())
	row.add_child(_action("+ Tier", "Add a tier", func() -> void: add_tier_pressed.emit()))
	row.add_child(_action("Undo", "Undo (Ctrl+Z)", tools.undo))
	row.add_child(_action("Redo", "Redo (Ctrl+Y)", tools.redo))
	row.add_child(_action("Photo", "Save a picture", func() -> void: photo_pressed.emit()))
	return bar


func _button(text: String, hint: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	return button


func _action(text: String, hint: String, callback: Callable) -> Button:
	var button := _button(text, hint)
	button.pressed.connect(callback)
	return button


func _swatch(color: Color) -> Button:
	var button := _button("", "Colour")
	button.custom_minimum_size = Vector2(34.0, 34.0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(17)
	normal.set_border_width_all(2)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.9)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Color(0.4, 0.3, 0.25)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: context.set_color(color))
	return button
