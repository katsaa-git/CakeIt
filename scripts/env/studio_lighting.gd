class_name StudioLighting
extends Node3D
## Lights and post-processing for the decorating scene: a warm window light,
## soft fill, gentle ambient occlusion, mild bloom and filmic tone mapping.

var environment: Environment
var sun: DirectionalLight3D


func _ready() -> void:
	name = "Lighting"
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.86, 0.8, 0.74)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.93, 0.88, 0.84)
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.5
	environment.ssao_intensity = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	sun = DirectionalLight3D.new()
	sun.name = "WindowLight"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.light_energy = 1.25
	sun.light_angular_distance = 0.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.2
	sun.directional_shadow_max_distance = 18.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	add_child(fill)
