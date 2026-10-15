class_name StudioLighting
extends Node3D
## Lights and post-processing for the decorating scene.
##  - Window light: warm sun from behind and to the left, through the window,
##    giving soft shadows and a glowing rim on the frosting.
##  - Front fill: a large soft light from the camera's side, so the cake's face
##    is bright and airy (no harsh dark side).
##  - Window glow: warm bounce light near the window.
##  - A reflection probe so glossy and metal things reflect the room.
##  - Post: AgX tone mapping, gentle ambient occlusion, mild bloom, a little
##    warm haze for depth, and dust motes drifting in the window light.

const VIGNETTE: Shader = preload("res://art/shaders/vignette.gdshader")

var environment: Environment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var dust: GPUParticles3D


func _ready() -> void:
	name = "Lighting"
	_build_environment()
	_build_lights()
	_build_probe()
	_build_dust()
	_build_vignette()


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.93, 0.88, 0.82)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.98, 0.91, 0.84)
	environment.ambient_light_energy = 0.3
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 1.5
	environment.ssao_power = 1.3
	environment.ssao_light_affect = 0.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color(0.98, 0.92, 0.85)
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.06
	environment.adjustment_contrast = 1.06
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "WindowLight"
	sun.basis = Basis.looking_at(Vector3(0.42, -0.62, 0.66).normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.9, 0.77)
	sun.light_energy = 1.7
	sun.light_specular = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 2.4
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 16.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.6
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.name = "FrontFill"
	fill.basis = Basis.looking_at(Vector3(0.62, -0.38, -0.69).normalized(), Vector3.UP)
	fill.light_color = Color(0.98, 0.95, 0.93)
	fill.light_energy = 0.62
	fill.light_specular = 0.25
	fill.shadow_enabled = false
	add_child(fill)

	var glow := OmniLight3D.new()
	glow.name = "WindowGlow"
	glow.position = Vector3(0.0, 8.0, BakerySet.WALL_Z + 1.2)
	glow.light_color = Color(1.0, 0.92, 0.82)
	glow.light_energy = 1.4
	glow.omni_range = 16.0
	glow.omni_attenuation = 1.4
	glow.shadow_enabled = false
	glow.light_specular = 0.3
	add_child(glow)


func _build_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "RoomReflections"
	probe.position = Vector3(0.0, 6.0, 0.0)
	probe.size = Vector3(40.0, 28.0, 22.0)
	probe.box_projection = true
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.98, 0.92, 0.86)
	probe.ambient_color_energy = 0.35
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 0.9
	add_child(probe)


func _build_dust() -> void:
	dust = GPUParticles3D.new()
	dust.name = "DustMotes"
	dust.amount = 70
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.position = Vector3(-1.0, 6.5, -2.2)
	dust.visibility_aabb = AABB(Vector3(-8.0, -6.0, -5.0), Vector3(16.0, 12.0, 10.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(6.0, 5.0, 3.0)
	process.direction = Vector3(0.3, -0.2, 0.2)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.08
	process.gravity = Vector3(0.0, -0.004, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_speed_random = 0.2
	process.turbulence_influence_min = 0.02
	process.turbulence_influence_max = 0.06
	process.scale_min = 0.6
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var mote := StandardMaterial3D.new()
	mote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mote.vertex_color_use_as_albedo = true
	mote.albedo_color = Color(1.0, 0.94, 0.82, 0.45)
	mote.albedo_texture = _soft_dot()
	quad.material = mote
	dust.draw_pass_1 = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE
	rect.material = material
	layer.add_child(rect)
	add_child(layer)


static func _soft_dot() -> ImageTexture:
	var size: int = 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) - 15.5, float(y) - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2.0))
	return ImageTexture.create_from_image(image)
