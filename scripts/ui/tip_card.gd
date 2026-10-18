class_name TipCard
extends Button
## A card on a shelf: a little 3D picture and a name. Used for piping tips
## (before its picture is ready it shows the tip's opening) and decorations.

var tip: TipDefinition
var title: String = ""
## Pictures of things that take the picked colour are white and get tinted;
## the rest (cherries, gold) keep their own colours.
var tint_thumbnail: bool = true
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
	card.title = new_tip.display_name
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(84.0, 96.0)
	card.tooltip_text = "%s\n%s%s" % [new_tip.display_name, new_tip.description, hotkey_hint]
	return card


## A card for a decoration.
static func make_for(definition: DecorationDefinition) -> TipCard:
	var card := TipCard.new()
	card.title = definition.display_name
	card.tint_thumbnail = definition.uses_palette() and definition.placement != DecorationDefinition.Placement.RIM and definition.placement != DecorationDefinition.Placement.BAND
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(100.0, 96.0)
	card.tooltip_text = "%s\n%s" % [definition.display_name, definition.description]
	return card


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _wake(1.0))
	mouse_exited.connect(func() -> void: _wake(0.0))
	pressed.connect(func() -> void:
		_bounce_velocity = -9.0
		set_process(true))
	# Idle cards do no work; hovering or pressing wakes them up.
	set_process(false)


func _wake(hover_goal: float) -> void:
	_hover_goal = hover_goal
	set_process(true)


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
	else:
		set_process(false)


func _draw() -> void:
	var picture_size: float = 64.0 * (1.0 + _bounce * 0.12 + _hover * 0.05)
	var center := Vector2(size.x * 0.5, 38.0 - _hover * 2.0)
	if thumbnail != null:
		# A soft round backdrop so pale frosting stands out from the card.
		draw_circle(center + Vector2(0.0, 2.0), picture_size * 0.44, Color(0.55, 0.38, 0.3, 0.1 + 0.05 * _hover))
		# The picture is white frosting; tint it with the current colour.
		draw_texture_rect(thumbnail, Rect2(center - Vector2(picture_size, picture_size) * 0.5, Vector2(picture_size, picture_size)), false, color if tint_thumbnail else Color.WHITE)
	elif tip != null:
		_draw_profile(center, picture_size * 0.42)
	else:
		draw_circle(center, picture_size * 0.3, Color(color, 0.6))
	var font: Font = UiTheme.font(true)
	var label: String = title
	# Long names get a slightly smaller font so they never run into the next card.
	var font_size: int = 14
	while font_size > 10 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 8.0:
		font_size -= 1
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.TEXT if button_pressed else UiTheme.TEXT_MUTED)


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
