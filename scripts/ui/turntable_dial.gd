class_name TurntableDial
extends Control
## An on-screen turntable ring. It turns with the cake stand (the notches show
## the spin) and you can grab it and drag round to spin the cake, with the
## same flick-and-coast feel as grabbing the stand itself. The centre button
## toggles a slow auto-spin.
##
## The ring is a top-down view of the stand, turned so that its bottom edge is
## the side of the cake facing the camera: dragging the bottom of the ring to
## the right moves the front of the cake to the right.

signal auto_spin_toggled(enabled: bool)

const RING_WIDTH: float = 16.0

var turntable: Turntable
var camera: OrbitCamera

var _dragging: bool = false
var _hover: bool = false
var _center_hover: bool = false


func setup(new_turntable: Turntable, new_camera: OrbitCamera) -> void:
	turntable = new_turntable
	camera = new_camera
	custom_minimum_size = Vector2(124.0, 124.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Turntable: drag the ring to spin the cake, click the middle for auto-spin  (A / D, R)"


var _drawn_state := Vector4(INF, INF, INF, INF)


## Redraws only when something it shows has changed (the stand turned, the
## camera moved round, hover or auto-spin changed), not every frame.
func _process(_delta: float) -> void:
	if turntable == null:
		return
	var flags: float = (1.0 if _hover else 0.0) + (2.0 if _center_hover else 0.0) + (4.0 if _dragging else 0.0) + (8.0 if turntable.auto_spin else 0.0)
	var state := Vector4(snappedf(wrapf(turntable.angle, 0.0, TAU), 0.002), snappedf(_camera_angle(), 0.002), flags, 0.0)
	if state != _drawn_state:
		_drawn_state = state
		queue_redraw()


func _outer_radius() -> float:
	return minf(size.x, size.y) * 0.5 - 6.0


func _camera_angle() -> float:
	if camera == null or turntable == null:
		return PI * 0.5
	var offset: Vector3 = camera.global_position - turntable.global_position
	return atan2(offset.z, offset.x)


## Screen angle on the ring -> world angle around the stand.
func _world_angle(screen_angle: float) -> float:
	return screen_angle + _camera_angle() - PI * 0.5


func _gui_input(event: InputEvent) -> void:
	var center: Vector2 = size * 0.5
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		var offset: Vector2 = button.position - center
		if button.pressed:
			if offset.length() < _outer_radius() - RING_WIDTH - 4.0:
				turntable.auto_spin = not turntable.auto_spin
				auto_spin_toggled.emit(turntable.auto_spin)
			else:
				_dragging = true
				turntable.auto_spin = false
				turntable.begin_grab_angle(_world_angle(offset.angle()))
		elif _dragging:
			_dragging = false
			turntable.end_grab()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var offset: Vector2 = motion.position - center
		_center_hover = offset.length() < _outer_radius() - RING_WIDTH - 4.0
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _center_hover else Control.CURSOR_DRAG
		if _dragging:
			turntable.update_grab_angle(_world_angle(offset.angle()))
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_center_hover = false


func _draw() -> void:
	if turntable == null:
		return
	var center: Vector2 = size * 0.5
	var outer: float = _outer_radius()
	var mid: float = outer - RING_WIDTH * 0.5
	# Soft shadow and the cream ring.
	draw_circle(center + Vector2(0.0, 3.0), outer + 2.0, Color(0.35, 0.2, 0.12, 0.12))
	draw_circle(center, outer, UiTheme.PANEL_SOLID)
	draw_arc(center, outer, 0.0, TAU, 64, UiTheme.PANEL_BORDER, 1.5, true)
	var ring_color: Color = UiTheme.ACCENT_SOFT if (_hover and not _center_hover) or _dragging else Color(0.96, 0.92, 0.88)
	draw_arc(center, mid, 0.0, TAU, 64, ring_color, RING_WIDTH, true)
	# Notches that turn with the stand.
	var spin_screen: float = -turntable.angle - _camera_angle() + PI * 0.5
	for i in range(24):
		var a: float = spin_screen + TAU * float(i) / 24.0
		var big: bool = i % 6 == 0
		var inner_r: float = mid - (5.0 if big else 3.0)
		var outer_r: float = mid + (5.0 if big else 3.0)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * inner_r, center + dir * outer_r, UiTheme.ACCENT if big else UiTheme.TEXT_MUTED, 2.5 if big else 1.5, true)
	# Centre: auto-spin button.
	var inner: float = outer - RING_WIDTH - 6.0
	var fill: Color = UiTheme.ACCENT_SOFT if turntable.auto_spin else (UiTheme.HOVER if _center_hover else UiTheme.PANEL_SOLID)
	draw_circle(center, inner, fill)
	if turntable.auto_spin:
		draw_arc(center, inner, 0.0, TAU, 48, UiTheme.ACCENT, 2.0, true)
	UiIcons.draw(self, &"spin", Rect2(center - Vector2(inner, inner) * 0.6, Vector2(inner, inner) * 1.2), UiTheme.TEXT)
