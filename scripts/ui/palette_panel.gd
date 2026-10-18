class_name PalettePanel
extends PanelContainer
## The colour panel: a tab per palette in data/palettes/ (Colours, Metallic,
## Mixes...) over a scrolling grid of round swatches, then a custom colour
## picker and the last few custom colours. Picking a swatch sets the colour
## (and its finish: metallic swatches make pieces shine) for piping, coats,
## decorations and lustre dust; picking a mix gives each decoration a random
## colour from it. While the two-tone bag's stripe is chosen, picks set the
## stripe instead.

const COLUMNS: int = 5
const SWATCH: float = 38.0
const ROWS_SHOWN: int = 8
const MAX_CUSTOM: int = 5

var context: EditorContext

var _title: Label
var _tabs: Dictionary = {}
var _grids: Dictionary = {}
var _palettes: Array[SwatchPalette] = []
var _swatches: Array[SwatchButton] = []
var _current: StringName = &""
var _custom_row: HBoxContainer
var _custom: Array[Color] = []
var _popup: PopupPanel
var _picker: ColorPicker


func setup(new_context: EditorContext) -> void:
	context = new_context
	name = "Palette"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_title = UiTheme.caption("Colour")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(tab_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(float(COLUMNS) * (SWATCH + 4.0) + 6.0, float(ROWS_SHOWN) * (SWATCH + 4.0))
	column.add_child(scroll)
	var pages := VBoxContainer.new()
	scroll.add_child(pages)
	var tab_group := ButtonGroup.new()
	for res in Content.palettes():
		var palette := res as SwatchPalette
		if palette == null:
			continue
		_palettes.append(palette)
		var tab := Shelves.pill(palette.display_name, _tab_hint(palette), tab_group)
		tab.custom_minimum_size = Vector2(0.0, 28.0)
		tab.add_theme_font_size_override("font_size", 13)
		tab.add_theme_constant_override("h_separation", 0)
		var id: StringName = palette.id
		tab.pressed.connect(func() -> void: _show_tab(id))
		tab_row.add_child(tab)
		_tabs[id] = tab
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		pages.add_child(grid)
		_grids[id] = grid
		if palette.is_mixes():
			for i in range(palette.mix_sizes.size()):
				var colors: PackedColorArray = palette.mix(i)
				var swatch := SwatchButton.make(colors[0], "%s mix" % palette.color_name(i), SWATCH)
				swatch.colors = colors
				var title: String = palette.color_name(i)
				swatch.pressed.connect(func() -> void: context.set_mix(colors, title))
				grid.add_child(swatch)
				_swatches.append(swatch)
		else:
			for i in range(palette.size()):
				var color: Color = palette.colors[i]
				var shine: float = palette.shine(i)
				var swatch := SwatchButton.make(color, palette.color_name(i), SWATCH)
				swatch.shine = shine
				swatch.pressed.connect(func() -> void: context.set_color(color, shine))
				grid.add_child(swatch)
				_swatches.append(swatch)
	# Custom colours: a picker, and the last few picked with it.
	var custom_box := VBoxContainer.new()
	custom_box.add_theme_constant_override("separation", 4)
	column.add_child(custom_box)
	var custom_button := Shelves.pill("+ Custom colour", "Mix any shade you like")
	custom_button.custom_minimum_size = Vector2(0.0, 32.0)
	custom_button.add_theme_font_size_override("font_size", 14)
	custom_button.pressed.connect(_open_picker)
	custom_box.add_child(custom_button)
	_custom_row = HBoxContainer.new()
	_custom_row.add_theme_constant_override("separation", 4)
	_custom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_box.add_child(_custom_row)
	_build_picker()
	context.color_changed.connect(func(_c: Color) -> void: _refresh())
	context.mix_changed.connect(func(_m: PackedColorArray) -> void: _refresh())
	context.stripe_changed.connect(func(_on: bool, _c: Color) -> void: _refresh())
	context.color_slot_changed.connect(func(_s: int) -> void: _refresh())
	context.tool_changed.connect(_on_tool_changed)
	_show_tab(_palettes[0].id if not _palettes.is_empty() else &"")
	_refresh_tabs()
	_refresh()


## Shows one palette's swatches.
func _show_tab(id: StringName) -> void:
	_current = id
	if _tabs.has(id):
		(_tabs[id] as Button).button_pressed = true
	for key: StringName in _grids:
		(_grids[key] as Control).visible = key == id


## Offers only the palettes that suit the tool (mixes are for decorations).
func _refresh_tabs() -> void:
	var first: StringName = &""
	for palette in _palettes:
		var offered: bool = palette.offered_for(context.tool_id)
		(_tabs[palette.id] as Control).visible = offered
		if offered and first == &"":
			first = palette.id
	var current: SwatchPalette = _palette(_current)
	if current == null or not current.offered_for(context.tool_id):
		_show_tab(first)


func _palette(id: StringName) -> SwatchPalette:
	for palette in _palettes:
		if palette.id == id:
			return palette
	return null


func _tab_hint(palette: SwatchPalette) -> String:
	if palette.is_mixes():
		return "Colour mixes for decorations: each piece takes one of the colours"
	if not palette.shines.is_empty():
		return "Metallic and pearl colours that shine like gold leaf"
	return palette.display_name


func _refresh() -> void:
	var stripe: bool = context.color_slot == 1 and context.tool_id == &"pipe"
	_title.text = "Stripe colour" if stripe else "Colour"
	for swatch in _swatches:
		if swatch.colors.size() > 1:
			swatch.selected = not stripe and context.mix == swatch.colors
		elif stripe:
			swatch.selected = swatch.color.is_equal_approx(context.stripe_color)
		else:
			swatch.selected = context.mix.is_empty() and swatch.color.is_equal_approx(context.color) and is_equal_approx(swatch.shine, context.shine)
	for child in _custom_row.get_children():
		var swatch := child as SwatchButton
		if swatch != null:
			swatch.selected = context.mix.is_empty() and swatch.color.is_equal_approx(context.stripe_color if stripe else context.color)


func _build_picker() -> void:
	_popup = PopupPanel.new()
	_popup.name = "CustomColour"
	_popup.add_theme_stylebox_override("panel", UiTheme.panel_style(18, 12.0))
	add_child(_popup)
	_picker = ColorPicker.new()
	_picker.edit_alpha = false
	_picker.presets_visible = false
	_picker.can_add_swatches = false
	_picker.sampler_visible = false
	_picker.color_modes_visible = false
	_picker.picker_shape = ColorPicker.SHAPE_OKHSL_CIRCLE
	_picker.color_changed.connect(func(c: Color) -> void: context.set_color(Color(c, 1.0)))
	_popup.add_child(_picker)
	_popup.popup_hide.connect(_remember_custom)


func _open_picker() -> void:
	_picker.color = context.stripe_color if context.color_slot == 1 and context.tool_id == &"pipe" else context.color
	_popup.reset_size()
	var rect: Rect2 = get_global_rect()
	_popup.popup(Rect2i(Vector2i(int(rect.position.x - _popup.size.x - 12.0), int(rect.position.y)), _popup.size))


## Keeps the colour just mixed in the row under the picker button.
func _remember_custom() -> void:
	var color: Color = Color(_picker.color, 1.0)
	for old in _custom:
		if old.is_equal_approx(color):
			return
	for palette in _palettes:
		if palette.index_of(color) >= 0:
			return
	_custom.push_front(color)
	if _custom.size() > MAX_CUSTOM:
		_custom.pop_back()
	for child in _custom_row.get_children():
		child.queue_free()
	for c in _custom:
		var swatch := SwatchButton.make(c, "Custom #%s" % c.to_html(false), 30.0)
		var picked: Color = c
		swatch.pressed.connect(func() -> void: context.set_color(picked))
		_custom_row.add_child(swatch)
	_refresh.call_deferred()


func _on_tool_changed(tool_id: StringName) -> void:
	_refresh_tabs()
	# Dust looks best in metallic and pearl colours: start there.
	if tool_id == &"dust":
		for palette in _palettes:
			if not palette.shines.is_empty():
				_show_tab(palette.id)
				break
