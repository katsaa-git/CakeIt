class_name TierView
extends Node3D
## The visible side of one tier: its frosted mesh, its merged piping, its
## decorations, and a matching collision body in the unrotated collision tree.
## Also used for the stand's plate ("board"), which has no mesh of its own.

const COAT_SWEEP_SECONDS: float = 1.0

var tier_id: int = 0
var is_board: bool = false
var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var strokes: StrokeBatch
## Decorations attach here (see DecorationLayer).
var decoration_root: Node3D
## This tier's frame in the collision tree.
var collision_frame: Node3D

var _body: StaticBody3D
var _built_radius: float = -1.0
var _built_height: float = -1.0
var _coat_tween: Tween
var _move_tween: Tween
var _shape_tween: Tween
var _highlight: float = 0.0
var _highlight_goal: float = 0.0


func setup(id: int, collision_root: Node3D, board: bool = false, board_radius: float = 2.0) -> void:
	tier_id = id
	is_board = board
	name = "Board" if board else "Tier%d" % id
	collision_frame = Node3D.new()
	collision_frame.name = name
	collision_root.add_child(collision_frame)

	if not board:
		material = Materials.new_tier_material()
		material.set_shader_parameter("seed", float(id) * 0.137)
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Frosting"
		add_child(mesh_instance)
	else:
		_body = _new_body(&"board")
		var shape := CylinderShape3D.new()
		shape.radius = board_radius
		shape.height = 0.1
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = -0.05
		_body.add_child(collision)

	strokes = StrokeBatch.new()
	strokes.setup(id, Materials.buttercream(), collision_frame)
	add_child(strokes)
	decoration_root = Node3D.new()
	decoration_root.name = "Decorations"
	add_child(decoration_root)


## Matches the tier data: size, coat and height on the stack.
func sync(tier: TierData, base_y: float, animate: bool) -> void:
	collision_frame.position.y = base_y
	if animate and is_inside_tree():
		if _move_tween != null:
			_move_tween.kill()
		_move_tween = create_tween()
		_move_tween.tween_property(self, "position:y", base_y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		position.y = base_y
	if is_board or tier == null:
		return
	if not is_equal_approx(tier.radius, _built_radius) or not is_equal_approx(tier.height, _built_height):
		var had_shape: bool = _built_radius > 0.0
		var old_scale := Vector3(_built_radius / tier.radius, _built_height / tier.height, _built_radius / tier.radius) if had_shape else Vector3.ONE
		_rebuild_shape(tier)
		if animate and had_shape and is_inside_tree():
			# Grow or shrink smoothly into the new size (the data has already changed).
			scale = old_scale
			if _shape_tween != null:
				_shape_tween.kill()
			_shape_tween = create_tween()
			_shape_tween.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	apply_coat(tier, false)


func _rebuild_shape(tier: TierData) -> void:
	var shape: TierShape = TierShape.get_shape(tier.shape_id)
	mesh_instance.mesh = shape.build_mesh(tier)
	mesh_instance.material_override = material
	material.set_shader_parameter("tier_radius", tier.radius)
	material.set_shader_parameter("tier_height", tier.height)
	_built_radius = tier.radius
	_built_height = tier.height
	if _body != null:
		_body.queue_free()
	_body = _new_body(&"tier")
	var collision := CollisionShape3D.new()
	collision.shape = shape.build_collision(tier)
	_body.add_child(collision)


## Shows the tier's coat. When animated, the new coat spreads from the top
## centre down the sides.
func apply_coat(tier: TierData, animate: bool) -> void:
	if material == null:
		return
	if _coat_tween != null:
		_coat_tween.kill()
		_coat_tween = null
	var coated_value: float = 1.0 if tier.coated else 0.0
	if animate and is_inside_tree():
		# What is showing now becomes the "previous" coat.
		var sweep: float = material.get_shader_parameter("sweep")
		if sweep >= 0.5:
			material.set_shader_parameter("prev_color", material.get_shader_parameter("coat_color"))
			material.set_shader_parameter("prev_coated", material.get_shader_parameter("coated"))
			material.set_shader_parameter("prev_smoothness", material.get_shader_parameter("smoothness"))
		material.set_shader_parameter("coat_color", tier.coat_color)
		material.set_shader_parameter("coated", coated_value)
		material.set_shader_parameter("smoothness", tier.smoothness)
		material.set_shader_parameter("sweep", 0.0)
		_coat_tween = create_tween()
		_coat_tween.tween_method(func(v: float) -> void: material.set_shader_parameter("sweep", v), 0.0, 1.0, COAT_SWEEP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		material.set_shader_parameter("coat_color", tier.coat_color)
		material.set_shader_parameter("prev_color", tier.coat_color)
		material.set_shader_parameter("coated", coated_value)
		material.set_shader_parameter("prev_coated", coated_value)
		material.set_shader_parameter("smoothness", tier.smoothness)
		material.set_shader_parameter("prev_smoothness", tier.smoothness)
		material.set_shader_parameter("sweep", 1.0)


## Soft glow used when the tier tool hovers or selects this tier.
func set_highlight(amount: float) -> void:
	_highlight_goal = amount


## Plays a gentle drop-and-settle when a tier is added.
func play_drop_in() -> void:
	if not is_inside_tree():
		return
	var final_y: float = position.y
	position.y = final_y + 2.2
	scale = Vector3(0.96, 1.05, 0.96)
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position:y", final_y, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_property(self, "scale", Vector3(1.05, 0.92, 1.05), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Shrinks away and frees itself (visual only; the collision goes right away).
func play_remove_and_free() -> void:
	if collision_frame != null:
		collision_frame.queue_free()
		collision_frame = null
	if not is_inside_tree():
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.04, 1.04, 1.04), 0.06)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if material == null:
		return
	if not is_equal_approx(_highlight, _highlight_goal):
		_highlight = move_toward(_highlight, _highlight_goal, delta * 4.0)
		material.set_shader_parameter("highlight", _highlight)


func _new_body(kind: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = CakePicker.LAYER_CAKE
	body.collision_mask = 0
	body.set_meta("tier_id", tier_id)
	body.set_meta("kind", kind)
	collision_frame.add_child(body)
	return body
