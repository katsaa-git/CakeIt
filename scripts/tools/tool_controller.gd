class_name ToolController
extends Node
## Routes all decorating input in one place, so camera, turntable and tools
## never fight over the mouse:
##   Left button        active tool (pipe, coat, decorate, tiers)
##   Left on plate rim  grab and spin the turntable (also Space + left-drag)
##   Right-drag         orbit the camera      Wheel        zoom
##   Middle-drag        pan up and down       Ctrl+Wheel   tip size
##   A / D (hold)       spin the turntable    R            auto-spin on/off
##   1 2 3              size presets          [ ]          fine-tune size
##   Tab / Shift+Tab    next / previous tip   Ctrl+Z, Ctrl+Y  undo, redo
##   B C F V T          pipe, coat, scraper, decorate, tiers
##   H  P               help, photo

signal undo_performed(command: CakeCommand)
signal redo_performed(command: CakeCommand)
signal spin_toggled(enabled: bool)
signal help_requested
signal photo_requested

const TOOL_KEYS: Dictionary = {KEY_B: &"pipe", KEY_C: &"coat", KEY_F: &"spatula", KEY_V: &"decorate", KEY_T: &"tiers"}

var context: EditorContext
var tools: Dictionary = {}
var active: DecoratingTool

var _orbiting: bool = false
var _panning: bool = false
var _spinning: bool = false
var _left_down: bool = false
var _keys_spin: Dictionary = {}
var _hit: CakePicker.Hit
var _cursor_hidden: bool = false
var _enabled: bool = true
var _cursor_shape: Input.CursorShape = Input.CURSOR_ARROW
## Last known pointer position, from mouse events (so injected test input works too).
var _pointer := Vector2(-1.0, -1.0)


func setup(new_context: EditorContext) -> void:
	context = new_context
	name = "Tools"


func add_tool(tool: DecoratingTool) -> void:
	tool.setup(context)
	tools[tool.tool_id] = tool
	add_child(tool)
	if active == null:
		_activate(tool)


func select_tool(tool_id: StringName) -> void:
	var tool: DecoratingTool = tools.get(tool_id)
	if tool == null or tool == active:
		return
	_activate(tool)


func _activate(tool: DecoratingTool) -> void:
	if active != null:
		active.deactivate()
	active = tool
	active.activate()
	context.set_tool(tool.tool_id)


## Turns decorating input off (photo mode, automated screenshots) or back on.
func set_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	if active == null:
		return
	if enabled:
		active.activate()
	else:
		active.deactivate()
		_spinning = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_cursor_hidden = false


func is_enabled() -> bool:
	return _enabled


func current_hit() -> CakePicker.Hit:
	return _hit


func undo() -> void:
	if active != null and active.is_busy():
		active.release()
	var command: CakeCommand = context.commands.undo()
	if command != null:
		undo_performed.emit(command)
	else:
		context.toast("Nothing to undo")


func redo() -> void:
	var command: CakeCommand = context.commands.redo()
	if command != null:
		redo_performed.emit(command)
	else:
		context.toast("Nothing to redo")


func toggle_auto_spin() -> void:
	context.turntable.auto_spin = not context.turntable.auto_spin
	spin_toggled.emit(context.turntable.auto_spin)


func _process(delta: float) -> void:
	if _enabled:
		_update_pointer(delta)

	var spin_keys: float = 0.0
	if _keys_spin.get(KEY_A, false):
		spin_keys += 1.0
	if _keys_spin.get(KEY_D, false):
		spin_keys -= 1.0
	context.turntable.key_direction = spin_keys

	# Keep the camera aimed at the middle of the cake.
	var cake_height: float = context.model.total_height()
	var spin_root: Node3D = context.turntable.spin_root
	context.camera.target_goal = spin_root.global_position + Vector3(0.0, cake_height * 0.5, 0.0)
	context.camera.focus_point = spin_root.global_position + Vector3(0.0, cake_height * 0.55, 0.0)


func pointer_position() -> Vector2:
	return _pointer if _pointer.x >= 0.0 else get_viewport().get_mouse_position()


func _update_pointer(delta: float) -> void:
	var mouse: Vector2 = pointer_position()
	context.pointer_over_ui = _pointer_over_ui()
	var blocked: bool = context.pointer_over_ui and not (active != null and active.is_busy())
	_hit = null if blocked or _spinning or _orbiting else context.picker.pick(mouse)
	if _spinning:
		context.turntable.update_grab(_plate_world_point(mouse), mouse.x)

	# Rim hover feedback (only when not over the cake itself).
	var over_rim: bool = false
	if not blocked and not _spinning and (_hit == null or _hit.kind == &"board") and not (active != null and active.is_busy()):
		over_rim = _over_rim(mouse)
	context.turntable.set_rim_hover(over_rim)

	if active != null:
		active.update(delta, null if over_rim else _hit, mouse)

	var hide: bool = active != null and active.hides_cursor() and not blocked and not over_rim
	if hide != _cursor_hidden:
		_cursor_hidden = hide
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	var shape: Input.CursorShape = Input.CURSOR_DRAG if (over_rim or _spinning) else Input.CURSOR_ARROW
	if shape != _cursor_shape:
		_cursor_shape = shape
		Input.set_default_cursor_shape(shape)


func _input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouse
	if mouse_event != null:
		_pointer = mouse_event.position


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_handle_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _orbiting:
			context.camera.orbit(motion.relative)
		elif _panning:
			context.camera.pan_vertical(motion.relative.y)
		return
	var key := event as InputEventKey
	if key != null:
		_handle_key(key)


func _handle_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not button.pressed:
				return
			var direction: float = 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if button.ctrl_pressed:
				context.adjust_size(1.06 if direction > 0.0 else 1.0 / 1.06)
			else:
				context.camera.zoom(direction * button.factor if button.factor > 0.0 else direction)
		MOUSE_BUTTON_LEFT:
			if not _enabled:
				return
			if button.pressed:
				_left_down = true
				var mouse: Vector2 = button.position
				# Pick exactly where the click happened, not where the pointer was last frame.
				_pointer = mouse
				_hit = null if context.pointer_over_ui else context.picker.pick(mouse)
				if Input.is_key_pressed(KEY_SPACE):
					_start_spin(null, mouse)
				elif (_hit == null or _hit.kind == &"board") and _over_rim(mouse):
					_start_spin(_plate_world_point(mouse), mouse)
				elif active != null:
					active.press(_hit, mouse)
			else:
				_left_down = false
				if _spinning:
					_spinning = false
					context.turntable.end_grab()
				elif active != null:
					active.release()
	get_viewport().set_input_as_handled()


func _start_spin(world_point: Variant, mouse: Vector2) -> void:
	_spinning = true
	context.turntable.begin_grab(world_point, mouse.x)


func _handle_key(key: InputEventKey) -> void:
	if key.keycode == KEY_A or key.keycode == KEY_D:
		if not key.ctrl_pressed:
			_keys_spin[key.keycode] = key.pressed
		return
	if not key.pressed:
		return
	var ctrl: bool = key.ctrl_pressed or key.meta_pressed
	var handled: bool = true
	match key.keycode:
		KEY_Z:
			if ctrl and key.shift_pressed:
				redo()
			elif ctrl:
				undo()
			else:
				handled = false
		KEY_Y:
			if ctrl:
				redo()
			else:
				handled = false
		KEY_1, KEY_2, KEY_3:
			if key.echo:
				return
			context.set_size_index(key.keycode - KEY_1)
		KEY_BRACKETLEFT:
			context.adjust_size(1.0 / 1.08)
		KEY_BRACKETRIGHT:
			context.adjust_size(1.08)
		KEY_TAB:
			if not key.echo:
				context.cycle_tip(-1 if key.shift_pressed else 1)
		KEY_R:
			if not key.echo and not ctrl:
				toggle_auto_spin()
		KEY_H:
			if not key.echo:
				help_requested.emit()
		KEY_P:
			if not key.echo and not ctrl:
				photo_requested.emit()
		KEY_B, KEY_C, KEY_F, KEY_V, KEY_T:
			if key.echo or ctrl:
				return
			if tools.has(TOOL_KEYS[key.keycode]):
				select_tool(TOOL_KEYS[key.keycode])
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _plate_world_point(mouse: Vector2) -> Variant:
	var camera: Camera3D = context.camera
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	var plane_y: float = context.turntable.spin_root.global_position.y
	if absf(direction.y) < 0.0001:
		return null
	var t: float = (plane_y - origin.y) / direction.y
	if t <= 0.0:
		return null
	return origin + direction * t


func _over_rim(mouse: Vector2) -> bool:
	var point: Variant = _plate_world_point(mouse)
	if point == null:
		return false
	var local: Vector3 = (point as Vector3) - context.turntable.spin_root.global_position
	var bottom_radius: float = context.model.tiers[0].radius if not context.model.tiers.is_empty() else 0.0
	return context.turntable.is_rim_point(local, bottom_radius)


func _pointer_over_ui() -> bool:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE
