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
	var piping := PipingTool.new()
	tools.add_tool(piping)
	tools.add_tool(CoatTool.new())
	tools.add_tool(SpatulaTool.new())
	tools.add_tool(DecorationTool.new())
	tools.add_tool(TierTool.new())
	context.set_color((Content.palette(&"frosting") as SwatchPalette).colors[0])

	hud = Hud.new()
	add_child(hud)
	hud.setup(context, tools)
	hud.photo_requested.connect(take_photo)
	hud.clear_confirmed.connect(func() -> void: commands.run(TierCommands.ClearAll.new(model)))
	tools.help_requested.connect(hud.toggle_help)
	tools.photo_requested.connect(take_photo)
	piping.stroke_finished.connect(func(_s: StrokeData) -> void: hud.hide_first_hint())

	DevRunner.attach_if_requested(self)
	print("CakeGame decorating scene ready")


func add_tier() -> void:
	(tools.tools[&"tiers"] as TierTool).add_tier()


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
