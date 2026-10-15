extends Node3D
## Look test: a cake on a stand, built entirely from code, that you can pipe
## frosting onto with the mouse. Everything here is placeholder, meant to show
## how far code alone gets the look before any art is commissioned.
##
## Scale: 1 unit = 10 cm.

const STAND_PEDESTAL_HEIGHT: float = 0.8
const STAND_PLATE_HEIGHT: float = 0.12

var _camera: OrbitCamera
var _cake: CakeStack
var _controller: PipingController
var _hud: LookTestHud


func _ready() -> void:
	_build_environment()
	_build_set()
	_build_cake()
	_build_camera_and_controls()
	_build_hud()
	print("CakeGame look test ready")


func _process(_delta: float) -> void:
	_camera.target_goal = Vector3(0.0, _cake.mid_y(), 0.0)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.62, 0.79, 0.88)
	sky_material.sky_horizon_color = Color(0.93, 0.95, 0.94)
	sky_material.ground_horizon_color = Color(0.93, 0.95, 0.94)
	sky_material.ground_bottom_color = Color(0.8, 0.78, 0.74)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.85, 0.93)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_hdr_threshold = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 0.45
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_set() -> void:
	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	table.mesh = plane
	var table_material := StandardMaterial3D.new()
	table_material.albedo_color = Color(0.82, 0.74, 0.64)
	table_material.roughness = 0.85
	table.material_override = table_material
	table.name = "Table"
	add_child(table)

	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color(0.9, 0.9, 0.9)
	porcelain.roughness = 0.3
	porcelain.metallic_specular = 0.35

	var pedestal_profile: Dictionary = LatheMesh.rounded_cylinder_profile(0.45, STAND_PEDESTAL_HEIGHT, 0.05)
	var pedestal := MeshInstance3D.new()
	pedestal.mesh = LatheMesh.build(pedestal_profile["points"], pedestal_profile["normals"], 48)
	pedestal.material_override = porcelain
	pedestal.name = "StandPedestal"
	add_child(pedestal)

	var plate_profile: Dictionary = LatheMesh.rounded_cylinder_profile(2.2, STAND_PLATE_HEIGHT, 0.04)
	var plate := MeshInstance3D.new()
	plate.mesh = LatheMesh.build(plate_profile["points"], plate_profile["normals"], 72)
	plate.material_override = porcelain
	plate.position.y = STAND_PEDESTAL_HEIGHT
	plate.name = "StandPlate"
	add_child(plate)


func _build_cake() -> void:
	var frosting := StandardMaterial3D.new()
	frosting.albedo_color = Color(0.95, 0.89, 0.8)
	frosting.roughness = 0.7
	frosting.metallic_specular = 0.2
	frosting.rim_enabled = true
	frosting.rim = 0.2
	frosting.rim_tint = 0.6

	_cake = CakeStack.new()
	_cake.name = "Cake"
	_cake.base_y = STAND_PEDESTAL_HEIGHT + STAND_PLATE_HEIGHT
	_cake.tier_material = frosting
	add_child(_cake)
	_cake.add_child(_cake.create_tier())


func _build_camera_and_controls() -> void:
	_camera = OrbitCamera.new()
	_camera.name = "Camera"
	_camera.target = Vector3(0.0, _cake.mid_y(), 0.0)
	_camera.target_goal = _camera.target
	add_child(_camera)

	_controller = PipingController.new()
	_controller.name = "PipingController"
	add_child(_controller)
	_controller.setup(_camera, _cake)


func _build_hud() -> void:
	_hud = LookTestHud.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.tip_chosen.connect(_controller.set_tip)
	_hud.size_chosen.connect(_controller.set_radius)
	_hud.color_chosen.connect(_controller.set_color)
	_hud.add_tier_pressed.connect(_controller.add_tier)
	_hud.undo_pressed.connect(_controller.undo)
	_hud.redo_pressed.connect(_controller.redo)
	_hud.photo_pressed.connect(_take_photo)
	_hud.pointer_over_ui_changed.connect(func(over: bool) -> void: _controller.pointer_blocked = over)
	_controller.photo_requested.connect(_take_photo)
	_controller.tip_changed.connect(_hud.show_tip)
	_controller.size_changed.connect(_hud.show_size)
	_controller.message.connect(_hud.show_toast)
	_hud.show_tip(_controller.tip)
	_hud.show_size(_controller.radius)


# Saves a picture of the cake (without the toolbar) to the user's photos folder.
func _take_photo() -> void:
	_hud.set_interface_visible(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	_hud.set_interface_visible(true)
	var folder: String = "user://photos"
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%s/cake_%s.png" % [folder, stamp]
	if image.save_png(path) == OK:
		_hud.show_toast("Saved to " + ProjectSettings.globalize_path(path))
	else:
		_hud.show_toast("Could not save the photo")
