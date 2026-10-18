class_name CardStrip
extends HBoxContainer
## A row of shelf cards shown a page at a time, with soft arrow buttons on
## either side, a little "2 / 3" under them, and the mouse wheel flipping
## pages. A filter can hide cards (decoration tabs); paging only counts the
## cards that are shown.

## Cards per page.
var per_page: int = 9

var _cards: Array[Control] = []
var _filter: Callable = Callable()
var _page: int = 0
var _row: HBoxContainer
var _prev: Button
var _next: Button
var _count: Label


func _init(cards_per_page: int = 9) -> void:
	per_page = cards_per_page
	add_theme_constant_override("separation", 2)
	_prev = _arrow("‹", "Previous page (or scroll the wheel)")
	_prev.pressed.connect(func() -> void: flip(-1))
	add_child(_prev)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 0)
	add_child(middle)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 2)
	middle.add_child(_row)
	_count = UiTheme.caption("", true, 12)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_count)
	_next = _arrow("›", "Next page (or scroll the wheel)")
	_next.pressed.connect(func() -> void: flip(1))
	add_child(_next)
	mouse_filter = Control.MOUSE_FILTER_PASS


func add_card(card: Control) -> void:
	_cards.append(card)
	_row.add_child(card)
	_layout()


## Only cards for which `filter(card)` is true are shown (an empty Callable
## shows all). Goes back to the first page.
func set_filter(filter: Callable) -> void:
	_filter = filter
	_page = 0
	_layout()


## Turns to the page holding `card`.
func reveal(card: Control) -> void:
	var shown: Array[Control] = _shown_cards()
	var index: int = shown.find(card)
	if index >= 0 and index / per_page != _page:
		_page = index / per_page
		_layout()


func flip(step: int) -> void:
	var pages: int = _page_count()
	var page: int = clampi(_page + step, 0, pages - 1)
	if page != _page:
		_page = page
		_layout()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and _page_count() > 1:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			flip(-1)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN or button.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			flip(1)
			accept_event()


func _shown_cards() -> Array[Control]:
	var out: Array[Control] = []
	for card in _cards:
		if not _filter.is_valid() or bool(_filter.call(card)):
			out.append(card)
	return out


func _page_count() -> int:
	return maxi(ceili(float(_shown_cards().size()) / float(per_page)), 1)


func _layout() -> void:
	var shown: Array[Control] = _shown_cards()
	var pages: int = _page_count()
	_page = clampi(_page, 0, pages - 1)
	for card in _cards:
		card.visible = false
	for i in range(shown.size()):
		shown[i].visible = i / per_page == _page
	var paged: bool = pages > 1
	_prev.visible = paged
	_next.visible = paged
	_prev.disabled = _page == 0
	_next.disabled = _page == pages - 1
	_count.text = "%d / %d" % [_page + 1, pages] if paged else ""
	_count.visible = paged


func _arrow(text: String, hint: String) -> Button:
	var button := Shelves.pill(text, hint)
	button.custom_minimum_size = Vector2(30.0, 84.0)
	button.add_theme_font_size_override("font_size", 26)
	return button
