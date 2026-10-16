class_name TipThumbnails
extends Node
## Renders a small 3D picture of what each piping tip makes (a short wavy
## line, a few stamps, or a click shape), once, in a hidden mini scene with
## its own light. The frosting is rendered white so the tip cards can tint it
## with the current colour without rendering again.

signal rendered(tip: TipDefinition, texture: Texture2D)

const SIZE: int = 160
const RADIUS: float = 0.07

var _viewport: SubViewport
var _holder: MeshInstance3D
var _camera: Camera3D


## Renders every tip, a frame or two each, emitting `rendered` as each is done.
## Does nothing without a real renderer (headless tests).
func render_all(tips: Array[TipDefinition]) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_build_stage()
	for tip in tips:
		_holder.mesh = _sample_mesh(tip)
		_frame(_holder.get_aabb())
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		image.generate_mipmaps()
		rendered.emit(tip, ImageTexture.create_from_image(image))
	_viewport.queue_free()
	_viewport = null


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "TipThumbnailStage"
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.95, 0.9)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(Vector3(0.5, -0.8, -0.4).normalized(), Vector3.UP)
	key.light_energy = 1.6
	key.light_color = Color(1.0, 0.96, 0.9)
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.basis = Basis.looking_at(Vector3(-0.4, -0.3, 0.8).normalized(), Vector3.UP)
	rim.light_energy = 0.5
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_holder = MeshInstance3D.new()
	_viewport.add_child(_holder)


## What the tip is for, small and in white: one drop flower, a short row of
## shells or grass tufts, a single leaf, petal or basketweave bar, and a tight
## S-curve for lines (ruffles too, so the frill shows).
func _sample_mesh(tip: TipDefinition) -> ArrayMesh:
	var builder := StrokeBuilder.new(tip, RADIUS, Color.WHITE, 3)
	builder.fallback_forward = Vector3.RIGHT
	var is_stamp: bool = tip.behavior == TipDefinition.Behavior.STAMP
	if (is_stamp and tip.stamp is DropFlowerStamp) or (not is_stamp and tip.click_length > 0.0 and tip.wave_amplitude == 0.0):
		builder.add_sample(Vector3.ZERO, Vector3.UP, 1.3)
	elif is_stamp:
		var row: float = tip.stamp_spacing * RADIUS * 2.0
		for i in range(13):
			builder.add_sample(Vector3((float(i) / 12.0 - 0.5) * row, 0.0, 0.0), Vector3.UP, 1.0)
	else:
		var length: float = RADIUS * 5.0
		for i in range(25):
			var t: float = float(i) / 24.0
			builder.add_sample(Vector3((t - 0.5) * length, 0.0, sin(t * TAU) * RADIUS * 1.1), Vector3.UP, 1.0)
	builder.finish()
	var all := MeshArrays.new()
	for piece in builder.pieces:
		all.append(piece)
	return all.to_mesh(Materials.buttercream())


## Points the camera at the sample from the front and above, filling the frame.
func _frame(box: AABB) -> void:
	var center: Vector3 = box.get_center()
	var reach: float = maxf(box.size.length() * 0.5, 0.05)
	var direction := Vector3(0.0, 1.5, 1.0).normalized()
	var distance: float = reach / tan(deg_to_rad(_camera.fov * 0.5)) * 0.92
	_camera.position = center + direction * distance
	_camera.look_at(center, Vector3.UP)
	_camera.near = distance * 0.1
	_camera.far = distance * 4.0
