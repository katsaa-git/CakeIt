class_name PalettePanel
extends PanelContainer
## The colour palette: a column of round swatches. Picking one sets the
## colour for piping, coats and decorations.

var context: EditorContext
var palette: SwatchPalette

var _swatches: Array[SwatchButton] = []


func setup(new_context: EditorContext, new_palette: SwatchPalette) -> void:
	context = new_context
	palette = new_palette
	name = "Palette"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := UiTheme.caption("Colour")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for i in range(palette.size()):
		var swatch := SwatchButton.make(palette.colors[i], palette.color_name(i), 44.0)
		var color: Color = palette.colors[i]
		swatch.pressed.connect(func() -> void: context.set_color(color))
		grid.add_child(swatch)
		_swatches.append(swatch)
	context.color_changed.connect(_show_color)
	_show_color(context.color)


func _show_color(color: Color) -> void:
	for swatch in _swatches:
		swatch.selected = swatch.color.is_equal_approx(color)
