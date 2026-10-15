class_name PipingController
extends Node
## Handles the mouse and keyboard for decorating: piping strokes onto the cake,
## the cursor preview, tip/size/colour choices, adding tiers, and undo/redo.
##
## Undo and redo work on a single chronological stack. Every action (a stroke or
## a new tier) is one node that is detached on undo and re-attached on redo.

signal tip_changed(tip: int)
signal size_changed(radius: float)
signal message(text: String)
signal photo_requested

const MIN_RADIUS: float = 0.03
const MAX_RADIUS: float = 0.16
const SIZE_PRESETS: Array[float] = [0.04, 0.07, 0.11]

var camera: Camera3D
var cake: CakeStack
var tip: int = PipingStroke.Tip.ROUND
var radius: float = 0.07
var color: Color = Color(1.0, 0.96, 0.92)
## Set by the HUD while the mouse is over a panel, so clicks there do not pipe.
var pointer_blocked: bool = false

var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _stroke: PipingStroke = null
var _undo_stack: Array[Node3D] = []
var _redo_stack: Array[Node3D] = []


func setup(new_camera: Camera3D, new_cake: CakeStack) -> void:
	camera = new_camera
	cake = new_cake
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.albedo_color = Color(color, 0.5)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_marker = MeshInstance3D.new()
	_marker.mesh = sphere
	_marker.material_override = _marker_material
	_marker.top_level = true
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


# --- Choices -----------------------------------------------------------------

func set_tip(new_tip: int) -> void:
	tip = new_tip
	tip_changed.emit(tip)


func set_radius(new_radius: float) -> void:
	radius = clampf(new_radius, MIN_RADIUS, MAX_RADIUS)
	size_changed.emit(radius)


func set_color(new_color: Color) -> void:
	color = new_color
	if _marker_material != null:
		_marker_material.albedo_color = Color(color, 0.5)


# --- Piping ------------------------------------------------------------------

func begin_stroke(position: Vector3, normal: Vector3) -> void:
	var stroke := PipingStroke.new()
	stroke.setup(tip, radius, color)
	cake.add_child(stroke)
	stroke.add_sample(position, normal)
	_register(stroke, cake)
	_stroke = stroke


func extend_stroke(position: Vector3, normal: Vector3) -> void:
	if _stroke == null:
		return
	var last: Vector3 = _stroke.points[_stroke.points.size() - 1]
	if position.distance_to(last) >= _stroke.radius * 0.5:
		_stroke.add_sample(position, normal)


func end_stroke() -> void:
	_stroke = null


func add_tier() -> void:
	if cake == null:
		return
	end_stroke()
	if not cake.can_add_tier():
		message.emit("That is the tallest cake for now")
		return
	var tier: CakeTier = cake.create_tier()
	cake.add_child(tier)
	_register(tier, cake)


# --- Undo and redo -----------------------------------------------------------

func undo() -> void:
	end_stroke()
	if _undo_stack.is_empty():
		return
	var node: Node3D = _undo_stack.pop_back()
	var parent: Node = node.get_meta("undo_parent")
	parent.remove_child(node)
	_redo_stack.append(node)


func redo() -> void:
	end_stroke()
	if _redo_stack.is_empty():
		return
	var node: Node3D = _redo_stack.pop_back()
	var parent: Node = node.get_meta("undo_parent")
	parent.add_child(node)
	_undo_stack.append(node)


func undo_count() -> int:
	return _undo_stack.size()


func redo_count() -> int:
	return _redo_stack.size()


func _register(node: Node3D, parent: Node) -> void:
	node.set_meta("undo_parent", parent)
	_undo_stack.append(node)
	for old in _redo_stack:
		if is_instance_valid(old):
			old.free()
	_redo_stack.clear()


# --- Input and cursor --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin_from_pointer()
		else:
			end_stroke()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key)


func _handle_key(key: InputEventKey) -> void:
	var ctrl: bool = key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_Z:
			if ctrl:
				if key.shift_pressed:
					redo()
				else:
					undo()
		KEY_Y:
			if ctrl:
				redo()
		KEY_1:
			set_radius(SIZE_PRESETS[0])
		KEY_2:
			set_radius(SIZE_PRESETS[1])
		KEY_3:
			set_radius(SIZE_PRESETS[2])
		KEY_BRACKETLEFT:
			set_radius(radius * 0.85)
		KEY_BRACKETRIGHT:
			set_radius(radius * 1.18)
		KEY_R:
			if not ctrl:
				set_tip(PipingStroke.Tip.ROUND)
		KEY_S:
			if not ctrl:
				set_tip(PipingStroke.Tip.STAR)
		KEY_N:
			add_tier()
		KEY_P:
			photo_requested.emit()


func _begin_from_pointer() -> void:
	if pointer_blocked:
		return
	var hit: Dictionary = _raycast()
	if hit.is_empty():
		return
	begin_stroke(hit["position"], hit["normal"])


func _physics_process(_delta: float) -> void:
	if camera == null or cake == null:
		return
	var hit: Dictionary = _raycast()
	if hit.is_empty() or pointer_blocked:
		_marker.visible = false
		return
	var position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	_marker.visible = true
	_marker.global_position = position + normal * radius * PipingStroke.LIFT
	_marker.scale = Vector3.ONE * radius
	if _stroke != null:
		extend_stroke(position, normal)


# Ray from the camera through the mouse pointer into the cake. Empty if it misses.
func _raycast() -> Dictionary:
	if camera == null or not camera.is_inside_tree():
		return {}
	var mouse: Vector2 = camera.get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var end: Vector3 = origin + camera.project_ray_normal(mouse) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, CakeTier.COLLISION_LAYER_CAKE)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)
