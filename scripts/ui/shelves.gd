class_name Shelves
extends RefCounted
## The bottom shelf for each tool. Each shelf is a row of controls inside the
## shared shelf panel; the HUD swaps them when the tool changes.


static func pill(text: String, hint: String, group: ButtonGroup = null) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0.0, 40.0)
	if group != null:
		button.toggle_mode = true
		button.button_group = group
	return button


static func section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := UiTheme.caption(title)
	box.add_child(label)
	return box


static func divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiTheme.PANEL_BORDER, 0.9)
	line.custom_minimum_size = Vector2(1.5, 64.0)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func hint(text: String) -> Label:
	var label := UiTheme.caption(text, true, 15)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## Piping: tips, size presets and fine size.
class PipeShelf extends HBoxContainer:
	var context: EditorContext
	var _cards: Dictionary = {}
	var _size_buttons: Array[Button] = []
	var _slider: HSlider
	var _size_label: Label
	var _updating: bool = false

	func setup(new_context: EditorContext) -> void:
		context = new_context
		add_theme_constant_override("separation", 14)
		var tips_box := HBoxContainer.new()
		tips_box.add_theme_constant_override("separation", 2)
		add_child(tips_box)
		var group := ButtonGroup.new()
		for tip in Content.tips():
			var card := TipCard.make(tip, "\nTab: next tip")
			card.button_group = group
			card.color = context.color
			card.pressed.connect(func() -> void: context.set_tip(tip))
			tips_box.add_child(card)
			_cards[tip.id] = card
		add_child(Shelves.divider())
		var sizes := Shelves.section("Size")
		add_child(sizes)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		sizes.add_child(row)
		var size_group := ButtonGroup.new()
		for i in range(3):
			var button := Shelves.pill(str(i + 1), "Size preset (%d)" % (i + 1), size_group)
			button.pressed.connect(func() -> void: context.set_size_index(i))
			row.add_child(button)
			_size_buttons.append(button)
		var fine := HBoxContainer.new()
		fine.add_theme_constant_override("separation", 8)
		sizes.add_child(fine)
		_slider = HSlider.new()
		_slider.custom_minimum_size = Vector2(150.0, 24.0)
		_slider.step = 0.001
		_slider.focus_mode = Control.FOCUS_NONE
		_slider.tooltip_text = "Fine-tune the size  (Ctrl + wheel, or [ and ])"
		_slider.value_changed.connect(_on_slider)
		fine.add_child(_slider)
		_size_label = UiTheme.caption("", false, 15)
		_size_label.custom_minimum_size = Vector2(58.0, 0.0)
		fine.add_child(_size_label)
		context.tip_changed.connect(func(_tip: TipDefinition) -> void: _refresh())
		context.size_changed.connect(func(_size: float, _index: int) -> void: _refresh())
		context.color_changed.connect(_on_color)
		_refresh()

	func set_thumbnail(tip: TipDefinition, texture: Texture2D) -> void:
		if _cards.has(tip.id):
			(_cards[tip.id] as TipCard).thumbnail = texture

	func _on_color(color: Color) -> void:
		for card: TipCard in _cards.values():
			card.color = color

	func _on_slider(value: float) -> void:
		if _updating or context.tip == null:
			return
		context.adjust_size(value / context.size)

	func _refresh() -> void:
		var tip: TipDefinition = context.tip
		if tip == null:
			return
		_updating = true
		if _cards.has(tip.id):
			(_cards[tip.id] as TipCard).button_pressed = true
		for i in range(_size_buttons.size()):
			_size_buttons[i].text = tip.preset_name(i)
			_size_buttons[i].button_pressed = i == context.size_index
		if context.size_index < 0:
			for button in _size_buttons:
				button.button_pressed = false
		_slider.min_value = tip.min_size
		_slider.max_value = tip.max_size
		_slider.value = context.size
		_size_label.text = "%.1f cm" % (context.size * 20.0)
		_updating = false


## Coat: full smooth coat or semi-naked, applied by clicking a tier.
class CoatShelf extends HBoxContainer:
	var context: EditorContext

	func setup(new_context: EditorContext) -> void:
		context = new_context
		add_theme_constant_override("separation", 14)
		var style := Shelves.section("Coat")
		add_child(style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		style.add_child(row)
		var group := ButtonGroup.new()
		var smooth := Shelves.pill("Smooth buttercream", "A full, even coat of frosting", group)
		var naked := Shelves.pill("Semi-naked", "A thin scraped coat with the sponge layers peeking through", group)
		smooth.button_pressed = not context.coat_naked
		naked.button_pressed = context.coat_naked
		smooth.pressed.connect(func() -> void: context.set_coat_naked(false))
		naked.pressed.connect(func() -> void: context.set_coat_naked(true))
		row.add_child(smooth)
		row.add_child(naked)
		add_child(Shelves.divider())
		add_child(Shelves.hint("Pick a colour, then click a tier to coat it."))


## Spatula: just a friendly explanation.
class SpatulaShelf extends HBoxContainer:
	func setup(_context: EditorContext) -> void:
		add_theme_constant_override("separation", 14)
		add_child(Shelves.hint("Hold the scraper against a tier and let the cake spin under it\n(A / D, the turntable ring, or drag along the side) to smooth the coat."))


## Tiers: width, height, add and remove.
class TierShelf extends HBoxContainer:
	var context: EditorContext
	var tool: TierTool
	var _width_buttons: Dictionary = {}
	var _height_buttons: Dictionary = {}
	var _remove: Button

	func setup(new_context: EditorContext, tier_tool: TierTool) -> void:
		context = new_context
		tool = tier_tool
		add_theme_constant_override("separation", 14)
		var width_box := Shelves.section("Width")
		var height_box := Shelves.section("Height")
		var width_row := HBoxContainer.new()
		var height_row := HBoxContainer.new()
		width_row.add_theme_constant_override("separation", 4)
		height_row.add_theme_constant_override("separation", 4)
		width_box.add_child(width_row)
		height_box.add_child(height_row)
		var width_group := ButtonGroup.new()
		var height_group := ButtonGroup.new()
		for res in Content.tier_presets():
			var preset: TierPreset = res as TierPreset
			if preset == null:
				continue
			var value: float = preset.value
			if preset.kind == TierPreset.Kind.WIDTH:
				var button := Shelves.pill(preset.display_name, preset.describe(), width_group)
				button.pressed.connect(func() -> void: tool.set_width(value))
				width_row.add_child(button)
				_width_buttons[value] = button
			else:
				var button := Shelves.pill(preset.display_name, preset.describe(), height_group)
				button.pressed.connect(func() -> void: tool.set_height(value))
				height_row.add_child(button)
				_height_buttons[value] = button
		add_child(width_box)
		add_child(height_box)
		add_child(Shelves.divider())
		var actions := Shelves.section("Tiers")
		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 4)
		actions.add_child(action_row)
		var add_button := Shelves.pill("+ Add on top", "Add a smaller tier on top")
		add_button.pressed.connect(tool.add_tier)
		action_row.add_child(add_button)
		_remove = Shelves.pill("Remove", "Take away the selected tier (you can undo it)")
		_remove.pressed.connect(tool.remove_selected)
		action_row.add_child(_remove)
		add_child(actions)
		context.tier_selection_changed.connect(func(_id: int) -> void: _refresh())
		context.model.tiers_changed.connect(_refresh)
		context.model.reset.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		var tier: TierData = context.model.tier_by_id(context.selected_tier_id)
		for value: float in _width_buttons:
			(_width_buttons[value] as Button).button_pressed = tier != null and is_equal_approx(tier.radius, value)
		for value: float in _height_buttons:
			(_height_buttons[value] as Button).button_pressed = tier != null and is_equal_approx(tier.height, value)
		_remove.disabled = context.model.tiers.size() <= 1
