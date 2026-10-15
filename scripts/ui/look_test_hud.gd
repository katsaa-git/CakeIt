class_name LookTestHud
extends CanvasLayer
## Simple toolbar for the look test: tip, size, colour, tiers, undo/redo, photo.
## Built entirely in code so there is no scene to maintain yet.

signal tip_chosen(tip: int)
signal size_chosen(radius: float)
signal color_chosen(color: Color)
signal add_tier_pressed
signal undo_pressed
signal redo_pressed
signal photo_pressed
signal pointer_over_ui_changed(over: bool)

const TIP_NAMES: Array[String] = ["Round", "Star"]
const SIZE_NAMES: Array[String] = ["S", "M", "L"]
const SIZE_PRESETS: Array[float] = [0.04, 0.07, 0.11]
const PALETTE: Array[Color] = [
	Color(1.0, 0.96, 0.9),
	Color(0.97, 0.62, 0.72),
	Color(0.62, 0.86, 0.75),
	Color(0.47, 0.72, 0.85),
	Color(0.98, 0.85, 0.45),
	Color(0.42, 0.26, 0.18),
]
const PALETTE_NAMES: Array[String] = ["Buttercream", "Pink", "Mint", "Sea blue", "Butter yellow", "Chocolate"]
const HELP_TEXT: String = "Left-drag: pipe   Right-drag: rotate   Wheel: zoom\nCtrl+Z / Ctrl+Y: undo / redo   1 2 3: size   [ ]: fine-tune size\nR / S: round / star tip   N: add tier   P: photo"

var pointer_over_ui: bool = false

var _bar: PanelContainer
var _tip_buttons: Array[Button] = []
var _size_buttons: Array[Button] = []
var _size_label: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(_make_help_label())
	root.add_child(_make_toast())
	root.add_child(_make_bar())


func _process(_delta: float) -> void:
	if _bar == null:
		return
	var over: bool = _bar.visible and _bar.get_global_rect().has_point(get_viewport().get_mouse_position())
	if over != pointer_over_ui:
		pointer_over_ui = over
		pointer_over_ui_changed.emit(over)


## Shows or hides the whole interface (used for clean photos).
func set_interface_visible(shown: bool) -> void:
	for child in get_children():
		if child is Control:
			(child as Control).visible = shown


func show_tip(tip: int) -> void:
	if tip >= 0 and tip < _tip_buttons.size():
		_tip_buttons[tip].button_pressed = true


func show_size(radius: float) -> void:
	if _size_label != null:
		_size_label.text = "%.1f cm" % (radius * 20.0)
	for i in range(_size_buttons.size()):
		if absf(radius - SIZE_PRESETS[i]) < 0.0005:
			_size_buttons[i].button_pressed = true


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _make_help_label() -> Label:
	var label := Label.new()
	label.text = HELP_TEXT
	label.position = Vector2(16.0, 12.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.18, 0.22, 0.28))
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
	_toast.add_theme_color_override("font_color", Color(0.18, 0.22, 0.28))
	_toast.modulate.a = 0.0
	return _toast


func _make_bar() -> PanelContainer:
	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_bottom = -16.0
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.85)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10.0)
	_bar.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bar.add_child(row)

	var tip_group := ButtonGroup.new()
	for i in range(TIP_NAMES.size()):
		var tip_button := _button(TIP_NAMES[i], "Piping tip")
		tip_button.toggle_mode = true
		tip_button.button_group = tip_group
		tip_button.pressed.connect(func() -> void: tip_chosen.emit(i))
		_tip_buttons.append(tip_button)
		row.add_child(tip_button)
	row.add_child(VSeparator.new())

	var size_group := ButtonGroup.new()
	for i in range(SIZE_NAMES.size()):
		var size_button := _button(SIZE_NAMES[i], "Tip size")
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.pressed.connect(func() -> void: size_chosen.emit(SIZE_PRESETS[i]))
		_size_buttons.append(size_button)
		row.add_child(size_button)
	_size_label = Label.new()
	_size_label.custom_minimum_size = Vector2(52.0, 0.0)
	_size_label.add_theme_color_override("font_color", Color(0.18, 0.22, 0.28))
	row.add_child(_size_label)
	row.add_child(VSeparator.new())

	for i in range(PALETTE.size()):
		row.add_child(_swatch(PALETTE[i], PALETTE_NAMES[i]))
	row.add_child(VSeparator.new())

	row.add_child(_action("+ Tier", "Add a tier (N)", func() -> void: add_tier_pressed.emit()))
	row.add_child(_action("Undo", "Undo (Ctrl+Z)", func() -> void: undo_pressed.emit()))
	row.add_child(_action("Redo", "Redo (Ctrl+Y)", func() -> void: redo_pressed.emit()))
	row.add_child(_action("Photo", "Save a picture (P)", func() -> void: photo_pressed.emit()))
	return _bar


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


func _swatch(color: Color, hint: String) -> Button:
	var button := _button("", hint)
	button.custom_minimum_size = Vector2(34.0, 34.0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(17)
	normal.set_border_width_all(2)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.9)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Color(0.2, 0.25, 0.3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: color_chosen.emit(color))
	return button
