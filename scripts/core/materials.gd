class_name Materials
extends RefCounted
## Shared materials and procedural textures, created once and reused, so
## every stroke on the cake can share a single material (one draw call per
## merged chunk) and nothing needs texture files.

const BUTTERCREAM_SHADER: Shader = preload("res://art/shaders/buttercream.gdshader")
const TIER_SHADER: Shader = preload("res://art/shaders/tier_frosting.gdshader")

static var _noise3d: NoiseTexture3D
static var _buttercream: ShaderMaterial
static var _ghost: StandardMaterial3D
static var _cache: Dictionary = {}


## Soft tileable 3D noise used for frosting detail.
static func noise3d() -> NoiseTexture3D:
	if _noise3d == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.08
		noise.fractal_octaves = 3
		noise.seed = 7
		_noise3d = NoiseTexture3D.new()
		_noise3d.width = 64
		_noise3d.height = 64
		_noise3d.depth = 64
		_noise3d.seamless = true
		_noise3d.normalize = true
		_noise3d.noise = noise
	return _noise3d


## The material every piped stroke uses (colour comes from vertex colours).
static func buttercream() -> ShaderMaterial:
	if _buttercream == null:
		_buttercream = ShaderMaterial.new()
		_buttercream.shader = BUTTERCREAM_SHADER
		_buttercream.set_shader_parameter("noise3d", noise3d())
	return _buttercream


## A fresh material for one tier (each tier has its own coat colour).
static func new_tier_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TIER_SHADER
	material.set_shader_parameter("noise3d", noise3d())
	return material


## Translucent, unshaded material for cursor previews.
static func ghost() -> StandardMaterial3D:
	if _ghost == null:
		_ghost = StandardMaterial3D.new()
		_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.vertex_color_use_as_albedo = true
		_ghost.vertex_color_is_srgb = true
		_ghost.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
		_ghost.cull_mode = BaseMaterial3D.CULL_BACK
		_ghost.no_depth_test = false
	return _ghost


## A simple lit material, cached by its settings.
static func standard(color: Color, roughness: float = 0.5, metallic: float = 0.0, specular: float = 0.5) -> StandardMaterial3D:
	var key: String = "std:%s:%.2f:%.2f:%.2f" % [color.to_html(), roughness, metallic, specular]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = specular
	_cache[key] = material
	return material
