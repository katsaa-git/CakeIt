class_name IconButton
extends Button
## A rounded button with a drawn icon, an optional caption underneath and an
## optional hotkey "keycap". It lifts slightly on hover and bounces when
## pressed, so every tap feels acknowledged.

signal tapped

var icon_id: StringName = &""
var caption_text: String = ""
var hotkey: String = ""
var icon_size: float = 34.0

var _hover: float = 0.0
var _bounce: float = 0.0
var _bounce_velocity: float = 0.0
var _hover_goal: float = 0.0


static func make(id: StringName, hint: String, key: String = "", caption: String = "", size: float = 64.0) -> IconButton:
	var button := IconButton.new()
	button.icon_id = id
	button.tooltip_text = hint + ("  (%s)" % key if not key.is_empty() else "")
	button.hotkey = key
	button.caption_text = caption
	button.custom_minimum_size = Vector2(size, size + (18.0 if not caption.is_empty() else 0.0))
	button.icon_size = size * 0.52
	return button


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	mouse_entered.connect(func() -> void: _wake(1.0))
	mouse_exited.connect(func() -> void: _wake(0.0))
	# Idle buttons do no work at all; hovering or pressing wakes them up.
	set_process(false)


func _wake(hover_goal: float) -> void:
	_hover_goal = hover_goal
	set_process(true)


func _on_pressed() -> void:
	_bounce_velocity = -9.0
	set_process(true)
	tapped.emit()


func _process(delta: float) -> void:
	var changed: bool = false
	if not is_equal_approx(_hover, _hover_goal):
		_hover = move_toward(_hover, _hover_goal, delta * 8.0)
		changed = true
	if absf(_bounce) > 0.0005 or absf(_bounce_velocity) > 0.0005:
		_bounce_velocity += (-_bounce * 320.0 - _bounce_velocity * 16.0) * delta
		_bounce += _bounce_velocity * delta
		changed = true
	if changed:
		queue_redraw()
	else:
		set_process(false)


func _draw() -> void:
	var lift: float = -2.0 * _hover
	var scale_amount: float = 1.0 + _bounce * 0.12 + _hover * 0.04
	var icon_area_height: float = size.y - (18.0 if not caption_text.is_empty() else 0.0)
	var center := Vector2(size.x * 0.5, icon_area_height * 0.5 + lift)
	var icon_extent: float = icon_size * scale_amount
	var color: Color = UiTheme.TEXT if not disabled else Color(UiTheme.TEXT_MUTED, 0.5)
	UiIcons.draw(self, icon_id, Rect2(center - Vector2(icon_extent, icon_extent) * 0.5, Vector2(icon_extent, icon_extent)), color)
	var font: Font = UiTheme.font(true)
	if not caption_text.is_empty():
		var text_width: float = font.get_string_size(caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2((size.x - text_width) * 0.5, size.y - 6.0), caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.TEXT if button_pressed else UiTheme.TEXT_MUTED)
	if not hotkey.is_empty():
		var key_width: float = font.get_string_size(hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
		var key_rect := Rect2(Vector2(size.x - key_width - 4.0, 4.0), Vector2(key_width, 15.0))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.95, 0.9, 0.85, 0.9)
		box.set_corner_radius_all(4)
		draw_style_box(box, key_rect)
		draw_string(font, key_rect.position + Vector2(4.0, 12.0), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.TEXT_MUTED)
