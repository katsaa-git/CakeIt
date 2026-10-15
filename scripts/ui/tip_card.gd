class_name TipCard
extends Button
## A tip in the piping shelf: a picture of what it pipes (once thumbnails are
## rendered) or the shape of its opening, plus its name.

var tip: TipDefinition
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var thumbnail: Texture2D:
	set(value):
		thumbnail = value
		queue_redraw()

var _hover: float = 0.0
var _hover_goal: float = 0.0
var _bounce: float = 0.0
var _bounce_velocity: float = 0.0


static func make(new_tip: TipDefinition, hotkey_hint: String = "") -> TipCard:
	var card := TipCard.new()
	card.tip = new_tip
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(84.0, 96.0)
	card.tooltip_text = "%s\n%s%s" % [new_tip.display_name, new_tip.description, hotkey_hint]
	return card


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover_goal = 1.0)
	mouse_exited.connect(func() -> void: _hover_goal = 0.0)
	pressed.connect(func() -> void: _bounce_velocity = -9.0)


func _process(delta: float) -> void:
	var redraw: bool = false
	if not is_equal_approx(_hover, _hover_goal):
		_hover = move_toward(_hover, _hover_goal, delta * 8.0)
		redraw = true
	if absf(_bounce) > 0.0005 or absf(_bounce_velocity) > 0.0005:
		_bounce_velocity += (-_bounce * 320.0 - _bounce_velocity * 16.0) * delta
		_bounce += _bounce_velocity * delta
		redraw = true
	if redraw:
		queue_redraw()


func _draw() -> void:
	var picture_size: float = 56.0 * (1.0 + _bounce * 0.12 + _hover * 0.05)
	var center := Vector2(size.x * 0.5, 36.0 - _hover * 2.0)
	if thumbnail != null:
		draw_texture_rect(thumbnail, Rect2(center - Vector2(picture_size, picture_size) * 0.5, Vector2(picture_size, picture_size)), false)
	else:
		_draw_profile(center, picture_size * 0.42)
	var font: Font = UiTheme.font(true)
	var label: String = tip.display_name
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.TEXT if button_pressed else UiTheme.TEXT_MUTED)


# The tip's opening, filled with the current colour.
func _draw_profile(center: Vector2, radius: float) -> void:
	var shape: ProfileShape = tip.shape()
	var points := PackedVector2Array()
	var extent: float = 0.0
	for p in shape.points:
		extent = maxf(extent, p.length())
	for p in shape.points:
		points.append(center + Vector2(p.x, -p.y) / maxf(extent, 0.001) * radius)
	draw_colored_polygon(points, color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color.darkened(0.35), 1.5, true)
