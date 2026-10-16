class_name Hud
extends CanvasLayer
## The decorating interface, built entirely in code:
##   left    tool rail (pipe, coat, spatula, decorate, tiers)
##   bottom  the active tool's shelf (tips and sizes, coat style, tier sizes...)
##   right   colour palette
##   top     undo, redo, clear, photo, help
##   corner  turntable ring
## Plus gentle toasts, a first-time hint, a help card and a clear-all confirm.

signal photo_requested
signal clear_confirmed

const TOOL_BUTTONS: Array = [
	[&"pipe", "Piping bag", "B"],
	[&"coat", "Frosting coat", "C"],
	[&"spatula", "Smoothing scraper", "F"],
	[&"decorate", "Decorations", "V"],
	[&"tiers", "Tiers", "T"],
]

var context: EditorContext
var tools: ToolController

var _root: Control
var _shelf_panel: PanelContainer
var _shelves: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _palette: PalettePanel
var _toast: Label
var _toast_tween: Tween
var _hint: Label
var _help: PanelContainer
var _confirm: Control
var _undo_button: IconButton
var _redo_button: IconButton


func setup(new_context: EditorContext, new_tools: ToolController) -> void:
	context = new_context
	tools = new_tools
	layer = 10
	name = "Hud"
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_tool_rail()
	_build_shelf()
	_build_palette()
	_build_top_bar()
	_build_turntable_dial()
	_build_toast_and_hint()
	_build_help()
	_build_confirm()

	context.tool_changed.connect(_on_tool_changed)
	context.message.connect(show_toast)
	context.commands.changed.connect(func(_c: CakeCommand, _d: int) -> void: _refresh_undo())
	_on_tool_changed(context.tool_id)
	_refresh_undo()


func set_interface_visible(shown: bool) -> void:
	_root.visible = shown


func is_modal_open() -> bool:
	return _confirm.visible or _help.visible


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.92, 0.92)
	_toast.pivot_offset = _toast.size * 0.5
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.5)


func hide_first_hint() -> void:
	if _hint.visible and _hint.modulate.a > 0.0:
		var tween := create_tween()
		tween.tween_property(_hint, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func() -> void: _hint.visible = false)


func toggle_help() -> void:
	_help.visible = not _help.visible


func ask_clear() -> void:
	if context.model.item_count() == 0:
		show_toast("The cake is already bare")
		return
	_confirm.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and (_help.visible or _confirm.visible):
		_help.visible = false
		_confirm.visible = false
		get_viewport().set_input_as_handled()


# --- Building --------------------------------------------------------------------

func _build_tool_rail() -> void:
	var rail := PanelContainer.new()
	rail.name = "ToolRail"
	rail.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 8.0))
	rail.anchor_top = 0.5
	rail.anchor_bottom = 0.5
	rail.offset_left = 22.0
	rail.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(rail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	rail.add_child(column)
	var group := ButtonGroup.new()
	for entry: Array in TOOL_BUTTONS:
		var id: StringName = entry[0]
		var button := IconButton.make(id, entry[1], entry[2], String(entry[1]).get_slice(" ", 0), 72.0)
		button.toggle_mode = true
		button.button_group = group
		button.disabled = not tools.tools.has(id)
		button.pressed.connect(func() -> void: tools.select_tool(id))
		column.add_child(button)
		_tool_buttons[id] = button


func _build_shelf() -> void:
	_shelf_panel = PanelContainer.new()
	_shelf_panel.name = "Shelf"
	_shelf_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(24, 14.0))
	_shelf_panel.anchor_left = 0.5
	_shelf_panel.anchor_right = 0.5
	_shelf_panel.anchor_top = 1.0
	_shelf_panel.anchor_bottom = 1.0
	_shelf_panel.offset_bottom = -22.0
	_shelf_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shelf_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_shelf_panel)

	var pipe := Shelves.PipeShelf.new()
	pipe.setup(context)
	_shelves[&"pipe"] = pipe
	# Little 3D pictures of what each tip pipes, rendered once in the background.
	var thumbnails := TipThumbnails.new()
	thumbnails.name = "TipThumbnails"
	add_child(thumbnails)
	thumbnails.rendered.connect(pipe.set_thumbnail)
	thumbnails.render_all.call_deferred(Content.tips())
	var coat := Shelves.CoatShelf.new()
	coat.setup(context)
	_shelves[&"coat"] = coat
	var spatula := Shelves.SpatulaShelf.new()
	spatula.setup(context)
	_shelves[&"spatula"] = spatula
	if tools.tools.has(&"tiers"):
		var tiers := Shelves.TierShelf.new()
		tiers.setup(context, tools.tools[&"tiers"])
		_shelves[&"tiers"] = tiers
	for shelf: Control in _shelves.values():
		shelf.visible = false
		_shelf_panel.add_child(shelf)


func _build_palette() -> void:
	_palette = PalettePanel.new()
	_palette.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 10.0))
	_palette.setup(context, Content.palette(&"frosting") as SwatchPalette)
	_palette.anchor_left = 1.0
	_palette.anchor_right = 1.0
	_palette.anchor_top = 0.5
	_palette.anchor_bottom = 0.5
	_palette.offset_right = -22.0
	_palette.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_palette.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_palette)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.add_theme_stylebox_override("panel", UiTheme.panel_style(22, 6.0))
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.offset_right = -22.0
	bar.offset_top = 20.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	bar.add_child(row)
	_undo_button = IconButton.make(&"undo", "Undo", "Ctrl+Z", "", 54.0)
	_undo_button.pressed.connect(tools.undo)
	row.add_child(_undo_button)
	_redo_button = IconButton.make(&"redo", "Redo", "Ctrl+Y", "", 54.0)
	_redo_button.pressed.connect(tools.redo)
	row.add_child(_redo_button)
	var clear := IconButton.make(&"clear", "Clear all piping and decorations", "", "", 54.0)
	clear.pressed.connect(ask_clear)
	row.add_child(clear)
	var photo := IconButton.make(&"photo", "Photo mode", "P", "", 54.0)
	photo.pressed.connect(func() -> void: photo_requested.emit())
	row.add_child(photo)
	var help := IconButton.make(&"help", "Controls", "H", "", 54.0)
	help.pressed.connect(toggle_help)
	row.add_child(help)


func _build_turntable_dial() -> void:
	var dial := TurntableDial.new()
	dial.name = "TurntableDial"
	dial.setup(context.turntable, context.camera)
	dial.anchor_left = 1.0
	dial.anchor_right = 1.0
	dial.anchor_top = 1.0
	dial.anchor_bottom = 1.0
	dial.offset_left = -150.0
	dial.offset_top = -150.0
	dial.offset_right = -26.0
	dial.offset_bottom = -26.0
	dial.auto_spin_toggled.connect(func(on: bool) -> void: show_toast("Auto-spin on" if on else "Auto-spin off"))
	_root.add_child(dial)


func _build_toast_and_hint() -> void:
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -360.0
	_toast.offset_right = 360.0
	_toast.offset_top = 28.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_override("font", UiTheme.font(true))
	_toast.add_theme_font_size_override("font_size", 20)
	var style := UiTheme.panel_style(20, 10.0)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	_toast.add_theme_stylebox_override("normal", style)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_hint = Label.new()
	_hint.name = "FirstHint"
	_hint.text = "Hold the left mouse button on the cake to pipe  ·  right-drag to look around"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 0.0
	_hint.offset_right = 0.0
	_hint.offset_top = -190.0
	_hint.offset_bottom = -190.0
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 17)
	var hint_style := UiTheme.panel_style(18, 8.0)
	hint_style.bg_color = Color(UiTheme.PANEL_SOLID, 0.82)
	hint_style.shadow_size = 6
	hint_style.content_margin_left = 18.0
	hint_style.content_margin_right = 18.0
	_hint.add_theme_stylebox_override("normal", hint_style)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_hint)


func _build_help() -> void:
	_help = PanelContainer.new()
	_help.name = "Help"
	_help.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 26.0))
	_help.set_anchors_preset(Control.PRESET_CENTER)
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.visible = false
	_root.add_child(_help)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_help.add_child(column)
	var title := Label.new()
	title.text = "How to decorate"
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	var rows: Array = [
		["Left mouse", "Use the tool (hold and drag to pipe)"],
		["Right-drag  ·  wheel", "Look around  ·  zoom"],
		["Middle-drag", "Look higher or lower"],
		["Turntable ring, stand rim, Space + drag", "Spin the cake (flick it to let it coast)"],
		["A / D  ·  R", "Spin smoothly  ·  auto-spin"],
		["B  C  F  V  T", "Piping, coat, scraper, decorations, tiers"],
		["1 2 3  ·  [ ]  ·  Ctrl + wheel", "Size presets  ·  fine-tune size"],
		["Tab", "Next tip"],
		["Ctrl+Z  ·  Ctrl+Y", "Undo  ·  redo"],
		["P  ·  H", "Photo mode  ·  this card"],
	]
	for row: Array in rows:
		var key := Label.new()
		key.text = row[0]
		key.add_theme_font_override("font", UiTheme.font(true))
		key.add_theme_color_override("font_color", UiTheme.ACCENT.darkened(0.25))
		grid.add_child(key)
		var what := Label.new()
		what.text = row[1]
		grid.add_child(what)
	var close := Shelves.pill("Back to decorating", "Close (Esc or H)")
	close.pressed.connect(toggle_help)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(close)


func _build_confirm() -> void:
	_confirm = ColorRect.new()
	(_confirm as ColorRect).color = Color(0.3, 0.2, 0.15, 0.25)
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.visible = false
	_root.add_child(_confirm)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(26, 26.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Start the decorating over?"
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	column.add_child(UiTheme.caption("All piping and decorations come off. The tiers and their coats stay,\nand you can always undo it.", true, 16))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var keep := Shelves.pill("Keep decorating", "")
	keep.pressed.connect(func() -> void: _confirm.visible = false)
	row.add_child(keep)
	var clear := Shelves.pill("Clear it all", "")
	clear.add_theme_stylebox_override("normal", UiTheme.button_style(UiTheme.ACCENT_SOFT, UiTheme.ACCENT))
	clear.pressed.connect(func() -> void:
		_confirm.visible = false
		clear_confirmed.emit())
	row.add_child(clear)


# --- Updates ---------------------------------------------------------------------

func _on_tool_changed(tool_id: StringName) -> void:
	if _tool_buttons.has(tool_id):
		(_tool_buttons[tool_id] as IconButton).button_pressed = true
	for id: StringName in _shelves:
		(_shelves[id] as Control).visible = id == tool_id
	_shelf_panel.visible = _shelves.has(tool_id)
	_palette.visible = tool_id in [&"pipe", &"coat", &"decorate"]
	# Collapse to zero size at the anchor; the panel then grows up and out to
	# exactly fit the new shelf (its minimum size).
	_shelf_panel.offset_left = 0.0
	_shelf_panel.offset_right = 0.0
	_shelf_panel.offset_top = -22.0
	_shelf_panel.offset_bottom = -22.0


func _refresh_undo() -> void:
	_undo_button.disabled = not context.commands.can_undo()
	_redo_button.disabled = not context.commands.can_redo()
	_undo_button.queue_redraw()
	_redo_button.queue_redraw()
