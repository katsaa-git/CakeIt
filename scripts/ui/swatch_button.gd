class_name SwatchButton
extends Button
## A round colour swatch. The selected one wears a ring and sits a little
## larger; hovering makes it swell gently.

var color: Color = Color.WHITE
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## A colour mix, drawn as pie slices (empty = one colour).
var colors: PackedColorArray = PackedColorArray()
## The colour's finish (metallic swatches shine; pearl ones shimmer).
var shine: float = 0.0

var _hover: float = 0.0
var _hover_goal: float = 0.0
var _pop: float = 0.0


static func make(swatch_color: Color, hint: String, diameter: float = 36.0) -> SwatchButton:
	var button := SwatchButton.new()
	button.color = swatch_color
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(diameter, diameter)
	return button


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void: _wake(1.0))
	mouse_exited.connect(func() -> void: _wake(0.0))
	pressed.connect(func() -> void:
		_pop = 1.0
		set_process(true))
	# Idle swatches do no work; hovering or pressing wakes them up.
	set_process(false)


func _wake(hover_goal: float) -> void:
	_hover_goal = hover_goal
	set_process(true)


func _process(delta: float) -> void:
	var redraw: bool = false
	if not is_equal_approx(_hover, _hover_goal):
		_hover = move_toward(_hover, _hover_goal, delta * 8.0)
		redraw = true
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 4.0, 0.0)
		redraw = true
	if redraw:
		queue_redraw()
	else:
		set_process(false)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	radius *= 0.86 + 0.08 * _hover + (0.1 if selected else 0.0) + sin(_pop * PI) * 0.08
	if selected:
		draw_arc(center, radius + 3.5, 0.0, TAU, 40, UiTheme.TEXT, 2.0, true)
	# Soft shadow, then the colour, then a little highlight so it reads as glossy.
	draw_circle(center + Vector2(0.0, 1.5), radius, Color(0.3, 0.2, 0.15, 0.12))
	if colors.size() > 1:
		var slices: int = colors.size()
		for i in range(slices):
			var a0: float = TAU * float(i) / float(slices) - PI * 0.5
			var a1: float = TAU * float(i + 1) / float(slices) - PI * 0.5
			var points := PackedVector2Array([center])
			for k in range(9):
				var a: float = lerpf(a0, a1, float(k) / 8.0)
				points.append(center + Vector2(cos(a), sin(a)) * radius)
			draw_colored_polygon(points, colors[i])
	else:
		draw_circle(center, radius, color)
	if shine > 0.0:
		# A metal sheen: darker toward the bottom, a bright band across the top.
		for k in range(6):
			var f: float = float(k) / 5.0
			draw_circle(center + Vector2(0.0, radius * 0.45 * f), radius * (1.0 - 0.55 * f), Color(color.darkened(0.25 * shine), 0.18))
		draw_arc(center + Vector2(-radius * 0.08, -radius * 0.06), radius * 0.62, PI * 1.08, PI * 1.62, 16, Color(1.0, 1.0, 1.0, 0.55 * shine + 0.15), radius * 0.22, true)
	draw_arc(center, radius, 0.0, TAU, 40, Color(0.3, 0.2, 0.15, 0.18), 1.0, true)
	draw_circle(center + Vector2(-radius * 0.32, -radius * 0.34), radius * 0.22, Color(1.0, 1.0, 1.0, 0.35))
