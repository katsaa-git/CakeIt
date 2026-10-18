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
	var _strip: CardStrip
	var _two_tone: Button
	var _main_slot: SwatchButton
	var _stripe_slot: SwatchButton

	func setup(new_context: EditorContext) -> void:
		context = new_context
		add_theme_constant_override("separation", 14)
		# The tips, a page at a time (arrows, the wheel, or Tab for the next tip).
		_strip = CardStrip.new(10)
		add_child(_strip)
		var group := ButtonGroup.new()
		for tip in Content.tips():
			var card := TipCard.make(tip, "\nTab: next tip")
			card.button_group = group
			card.color = context.color
			card.pressed.connect(func() -> void: context.set_tip(tip))
			_strip.add_card(card)
			_cards[tip.id] = card
		add_child(Shelves.divider())
		_add_bag_section()
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

	## The bag: plain or two-tone, and which colour the palette is setting.
	func _add_bag_section() -> void:
		var bag := Shelves.section("Bag")
		add_child(bag)
		_two_tone = Shelves.pill("Two-tone", "Fill the bag with two colours side by side: stripes, swirls and petals that blush into the second colour")
		_two_tone.toggle_mode = true
		_two_tone.toggled.connect(func(on: bool) -> void:
			if on != context.two_tone:
				context.set_two_tone(on)
				context.set_color_slot(1 if on else 0))
		bag.add_child(_two_tone)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 6)
		bag.add_child(slots)
		_main_slot = SwatchButton.make(context.color, "Main colour: click, then pick from the palette", 30.0)
		_main_slot.pressed.connect(func() -> void: context.set_color_slot(0))
		slots.add_child(_main_slot)
		_stripe_slot = SwatchButton.make(context.stripe_color, "Stripe colour: click, then pick from the palette", 30.0)
		_stripe_slot.pressed.connect(func() -> void:
			if not context.two_tone:
				context.set_two_tone(true)
			context.set_color_slot(1))
		slots.add_child(_stripe_slot)
		context.stripe_changed.connect(func(_on: bool, _c: Color) -> void: _refresh_bag())
		context.color_slot_changed.connect(func(_s: int) -> void: _refresh_bag())
		_refresh_bag()

	func _refresh_bag() -> void:
		_two_tone.set_pressed_no_signal(context.two_tone)
		_main_slot.color = context.color
		_stripe_slot.color = context.stripe_color
		_stripe_slot.modulate.a = 1.0 if context.two_tone else 0.45
		_main_slot.selected = context.two_tone and context.color_slot == 0
		_stripe_slot.selected = context.two_tone and context.color_slot == 1
		_main_slot.queue_redraw()
		_stripe_slot.queue_redraw()

	func set_thumbnail(key: Resource, texture: Texture2D) -> void:
		var tip := key as TipDefinition
		if tip != null and _cards.has(tip.id):
			(_cards[tip.id] as TipCard).thumbnail = texture

	func _on_color(color: Color) -> void:
		for card: TipCard in _cards.values():
			card.color = color
		_refresh_bag()

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
			_strip.reveal(_cards[tip.id])
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


## Lustre dust: brush size, how rich the shimmer gets, and brushing it off.
class DustShelf extends HBoxContainer:
	var context: EditorContext
	var _sizes: Array[Button] = []
	var _strengths: Array[Button] = []
	var _erase: Button

	func setup(new_context: EditorContext) -> void:
		context = new_context
		add_theme_constant_override("separation", 14)
		var size_box := Shelves.section("Brush")
		add_child(size_box)
		var size_row := HBoxContainer.new()
		size_row.add_theme_constant_override("separation", 4)
		size_box.add_child(size_row)
		var size_group := ButtonGroup.new()
		for i in range(3):
			var button := Shelves.pill(DustTool.SIZE_NAMES[i], "Brush %d cm across  (%d)" % [roundi(DustTool.SIZES[i] * 20.0), i + 1], size_group)
			button.pressed.connect(func() -> void: context.set_dust(i, context.dust_strength_index, context.dust_erase))
			size_row.add_child(button)
			_sizes.append(button)
		add_child(Shelves.divider())
		var strength_box := Shelves.section("Shimmer")
		add_child(strength_box)
		var strength_row := HBoxContainer.new()
		strength_row.add_theme_constant_override("separation", 4)
		strength_box.add_child(strength_row)
		var strength_group := ButtonGroup.new()
		var hints: Array[String] = ["A faint pearly glow", "A soft, sparkling sheen (like real lustre dust)", "Brushed on thick, like gold paint"]
		for i in range(3):
			var button := Shelves.pill(DustTool.STRENGTH_NAMES[i], hints[i], strength_group)
			button.pressed.connect(func() -> void: context.set_dust(context.dust_size_index, i, false))
			strength_row.add_child(button)
			_strengths.append(button)
		_erase = Shelves.pill("Brush off", "Brush dust away again", strength_group)
		_erase.pressed.connect(func() -> void: context.set_dust(context.dust_size_index, context.dust_strength_index, true))
		strength_row.add_child(_erase)
		add_child(Shelves.divider())
		add_child(Shelves.hint("Pick a colour (Metallic works best), then brush over\nthe cake: the longer you brush, the more it shimmers."))
		context.dust_changed.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		for i in range(_sizes.size()):
			_sizes[i].button_pressed = i == context.dust_size_index
		for i in range(_strengths.size()):
			_strengths[i].button_pressed = not context.dust_erase and i == context.dust_strength_index
		_erase.button_pressed = context.dust_erase


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


## Decorations: category tabs over the items in that category, sizes, and
## the words for a topper sign.
class DecorationShelf extends HBoxContainer:
	var context: EditorContext
	var _tabs: Dictionary = {}
	var _cards: Dictionary = {}
	var _items: CardStrip
	var _category: StringName = &""
	var _size_buttons: Array[Button] = []
	var _hint: Label
	var _words: VBoxContainer
	var _text: LineEdit

	func setup(new_context: EditorContext) -> void:
		context = new_context
		add_theme_constant_override("separation", 14)
		var left := VBoxContainer.new()
		left.add_theme_constant_override("separation", 6)
		add_child(left)
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 4)
		left.add_child(tabs)
		var tab_group := ButtonGroup.new()
		for entry: Array in DecorationDefinition.CATEGORIES:
			var category: StringName = entry[0]
			var tab := Shelves.pill(entry[1], "", tab_group)
			tab.custom_minimum_size = Vector2(0.0, 34.0)
			tab.add_theme_font_size_override("font_size", 15)
			tab.pressed.connect(func() -> void: _show_category(category))
			tabs.add_child(tab)
			_tabs[category] = tab
		_items = CardStrip.new(8)

		left.add_child(_items)
		var card_group := ButtonGroup.new()
		for res in Content.decorations():
			var definition := res as DecorationDefinition
			var card := TipCard.make_for(definition)
			card.button_group = card_group
			card.color = context.color
			card.pressed.connect(func() -> void: context.set_decoration(definition))
			card.set_meta("category", definition.category)
			_items.add_card(card)
			_cards[definition.id] = card
		add_child(Shelves.divider())
		var sizes := Shelves.section("Size")
		add_child(sizes)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		sizes.add_child(row)
		var size_group := ButtonGroup.new()
		for i in range(3):
			var button := Shelves.pill(str(i + 1), "Size (%d)" % (i + 1), size_group)
			button.pressed.connect(func() -> void: context.set_decoration_size_index(i))
			row.add_child(button)
			_size_buttons.append(button)
		_hint = UiTheme.caption("", true, 14)
		_hint.custom_minimum_size = Vector2(230.0, 0.0)
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sizes.add_child(_hint)
		_words = Shelves.section("Words")
		_text = LineEdit.new()
		_text.text = context.decoration_text
		_text.max_length = 32
		_text.custom_minimum_size = Vector2(220.0, 38.0)
		_text.placeholder_text = "Happy Birthday!"
		_text.text_changed.connect(func(value: String) -> void: context.decoration_text = value)
		# Typing must not trigger shortcuts (B, C, T...); Enter or Esc gives
		# the keys back to the cake.
		_text.text_submitted.connect(func(_value: String) -> void: _text.release_focus())
		_words.add_child(_text)
		add_child(_words)
		context.decoration_changed.connect(func(_d: Resource) -> void: _refresh())
		context.decoration_size_changed.connect(func(_i: int) -> void: _refresh())
		context.color_changed.connect(_on_color)
		if context.decoration == null and not Content.decorations().is_empty():
			context.set_decoration(Content.decorations()[0])
		_refresh()

	func set_thumbnail(key: Resource, texture: Texture2D) -> void:
		var definition := key as DecorationDefinition
		if definition != null and _cards.has(definition.id):
			(_cards[definition.id] as TipCard).thumbnail = texture

	func _on_color(color: Color) -> void:
		for card: TipCard in _cards.values():
			card.color = color

	func _show_category(category: StringName) -> void:
		_category = category
		(_tabs[category] as Button).button_pressed = true
		_items.set_filter(func(card: Control) -> bool: return card.get_meta("category") == category)
		var current := context.decoration as DecorationDefinition
		if current == null or current.category != category:
			for res in Content.decorations():
				if (res as DecorationDefinition).category == category:
					context.set_decoration(res)
					break

	func _refresh() -> void:
		var definition := context.decoration as DecorationDefinition
		if definition == null:
			return
		if definition.category != _category:
			_show_category(definition.category)
		(_cards[definition.id] as TipCard).button_pressed = true
		_items.reveal(_cards[definition.id])
		for i in range(_size_buttons.size()):
			_size_buttons[i].text = definition.preset_name(i)
			_size_buttons[i].button_pressed = i == context.decoration_size_index
		match definition.placement:
			DecorationDefinition.Placement.SCATTER:
				_hint.text = "Hold and move to sprinkle."
			DecorationDefinition.Placement.LINE:
				_hint.text = "Click for one, drag for a string."
			DecorationDefinition.Placement.RIM:
				_hint.text = "Drag along the top edge of a tier. Spin the cake to go all the way round."
			DecorationDefinition.Placement.BAND:
				_hint.text = "Drag round the side of a tier, or click to wrap it all the way round."
			_:
				_hint.text = "Click to place." + (" Goes on top of a tier." if definition.top_only else "")
		if definition.color_mode == DecorationDefinition.ColorMode.FIXED:
			_hint.text += " Comes in its own colours."
		elif definition.color_mode == DecorationDefinition.ColorMode.MIX:
			_hint.text += " Comes mixed; pick a Mix to change it."
		_words.visible = definition.uses_text()
