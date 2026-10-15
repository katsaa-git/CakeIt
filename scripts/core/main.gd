extends Node3D
## The decorating scene, built entirely from code: the set and lighting, the
## turntable stand, the cake (data model + view), the camera, the tools and
## the interface.
##
## Scale: 1 unit = 10 cm.

var context: EditorContext
var model: CakeModel
var commands: CommandStack
var turntable: Turntable
var cake_view: CakeView
var camera: OrbitCamera
var tools: ToolController
var hud: Hud
var lighting: StudioLighting


func _ready() -> void:
	lighting = StudioLighting.new()
	add_child(lighting)
	add_child(BakerySet.new())

	turntable = Turntable.new()
	add_child(turntable)

	# Collision shapes live in an unrotated twin of the turntable's spinning part.
	var collision_root := Node3D.new()
	collision_root.name = "CakeCollision"
	collision_root.position = Vector3(0.0, turntable.top_height(), 0.0)
	add_child(collision_root)

	model = CakeModel.new()
	commands = CommandStack.new(model)
	cake_view = CakeView.new()
	turntable.spin_root.add_child(cake_view)
	model.make_default()
	cake_view.setup(model, collision_root, Turntable.PLATE_RADIUS - 0.05)

	camera = OrbitCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.yaw_goal = 0.35
	camera.yaw = 0.35
	camera.target = Vector3(0.0, turntable.top_height() + model.total_height() * 0.5, 0.0)
	camera.target_goal = camera.target

	context = EditorContext.new()
	context.model = model
	context.commands = commands
	context.view = cake_view
	context.camera = camera
	context.turntable = turntable
	context.picker = CakePicker.new(camera, turntable.spin_root, collision_root, model)
	context.tip = Content.tips()[0]
	context.set_size_index(1)

	tools = ToolController.new()
	tools.setup(context)
	add_child(tools)
	tools.add_tool(PipingTool.new())

	hud = Hud.new()
	add_child(hud)
	hud.setup(context, tools)
	hud.add_tier_pressed.connect(add_tier)
	hud.photo_pressed.connect(take_photo)

	DevRunner.attach_if_requested(self)
	print("CakeGame decorating scene ready")


func add_tier() -> void:
	if not model.can_add_tier():
		context.toast("That's the tallest cake the stand can hold")
		return
	var top: TierData = model.tiers[model.tiers.size() - 1] if not model.tiers.is_empty() else null
	var tier := TierData.new()
	tier.id = model.new_id()
	tier.radius = maxf(top.radius * 0.72, 0.6) if top != null else 1.4
	tier.height = top.height * 0.92 if top != null else 1.1
	if top != null:
		tier.coat_color = top.coat_color
		tier.coated = top.coated
	commands.run(TierCommands.AddTier.new(tier, model.tiers.size()))


## Saves a picture of the cake (without the interface) to the screenshots folder.
func take_photo() -> void:
	hud.set_interface_visible(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	hud.set_interface_visible(true)
	var folder: String = "user://screenshots"
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%s/cake_%s.png" % [folder, stamp]
	if image.save_png(path) == OK:
		context.toast("Saved to " + ProjectSettings.globalize_path(path))
	else:
		context.toast("Could not save the photo")
