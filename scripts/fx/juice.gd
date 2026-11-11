class_name Juice
extends Node3D
## Little rewards that make decorating feel alive:
##  - a soft puff of sugar dust where a new coat lands, and a sparkle when the
##    scraper polishes a tier to silk;
##  - fine glitter drifting off the dust brush while it works;
##  - a gentle camera bump and a puff of flour when a tier lands on the stack.
## (Decorations pop in by themselves: see DecorationLayer.pop_new.)
##
## Particles are CPU particles with tiny soft billboards: a few dozen at a
## time, so they cost next to nothing.

const PUFF_COUNT: int = 26
const SPARKLE_COUNT: int = 18

var context: EditorContext

var _dot: ImageTexture
var _star: ImageTexture
var _puff_material: StandardMaterial3D
var _glint_material: StandardMaterial3D
var _trail: CPUParticles3D
var _trail_time: float = 0.0


func attach(main: Node) -> void:
	name = "Juice"
	context = main.get("context")
	_dot = _soft_dot(32)
	_star = _glint_star(48)
	_puff_material = _billboard(false)
	_glint_material = _billboard(true)
	_trail = _make_trail()
	add_child(_trail)
	var tools: ToolController = main.get("tools")
	var coat := tools.tools.get(&"coat") as CoatTool
	if coat != null:
		coat.coat_applied.connect(func(at: Vector3, color: Color) -> void: puff(at, color.lightened(0.35)))
	var spatula := tools.tools.get(&"spatula") as SpatulaTool
	if spatula != null:
		spatula.fully_smooth.connect(func(at: Vector3) -> void: sparkle(at, Color(1.0, 0.98, 0.94)))
	var dust := tools.tools.get(&"dust") as DustTool
	if dust != null:
		dust.dusting.connect(_on_dusting)
	var view: CakeView = main.get("cake_view")
	view.tier_added_visual.connect(_on_tier_added)


func _process(delta: float) -> void:
	_trail_time -= delta
	if _trail.emitting and _trail_time <= 0.0:
		_trail.emitting = false


## A soft puff of sugar dust at `at` (world space): a faint cloud that
## billows out and thins away, with a few fine specks of sugar in it.
func puff(at: Vector3, color: Color, count: int = PUFF_COUNT, size: float = 0.09) -> CPUParticles3D:
	# Start a little out from the surface (toward the camera), not inside the cake.
	if context != null and context.camera != null:
		at += (context.camera.global_position - at).normalized() * 0.08
	var cloud := _burst(maxi(count / 2, 4), 1.1, size, Color(color, 0.4), _puff_material)
	cloud.emission_sphere_radius = 0.06
	cloud.direction = Vector3.UP
	cloud.spread = 85.0
	cloud.initial_velocity_min = 0.12
	cloud.initial_velocity_max = 0.4
	cloud.gravity = Vector3(0.0, 0.02, 0.0)
	cloud.damping_min = 0.8
	cloud.damping_max = 1.4
	cloud.scale_amount_curve = _grow_curve()
	_launch(cloud, at)
	var specks := _burst(count, 0.8, size * 0.13, color.lightened(0.2), _puff_material)
	specks.emission_sphere_radius = 0.05
	specks.direction = Vector3.UP
	specks.spread = 70.0
	specks.initial_velocity_min = 0.3
	specks.initial_velocity_max = 0.8
	specks.gravity = Vector3(0.0, -0.9, 0.0)
	specks.damping_min = 1.0
	specks.damping_max = 1.8
	_launch(specks, at)
	return cloud


## A little burst of four-point glints (a coat polished to silk).
func sparkle(at: Vector3, color: Color) -> CPUParticles3D:
	var particles := _burst(SPARKLE_COUNT, 0.9, 0.05, color, _glint_material)
	particles.emission_sphere_radius = 0.12
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.35
	particles.gravity = Vector3(0.0, 0.08, 0.0)
	particles.damping_min = 0.6
	particles.damping_max = 1.0
	_launch(particles, at)
	return particles


func _on_dusting(at: Vector3) -> void:
	_trail.global_position = at + Vector3(0.0, 0.04, 0.0)
	_trail.color = context.color.lightened(0.25) if context != null else Color.WHITE
	_trail_time = 0.12
	_trail.emitting = true


func _on_tier_added(tier_view: TierView) -> void:
	# The tier drops for ~0.38 s; bump the camera and puff some flour as it lands.
	get_tree().create_timer(0.36).timeout.connect(func() -> void:
		if not is_instance_valid(tier_view) or context == null:
			return
		context.camera.nudge(Vector3.DOWN, 0.07)
		var to_camera: Vector3 = context.camera.global_position - tier_view.global_position
		to_camera.y = 0.0
		var tier: TierData = context.model.tier_by_id(tier_view.tier_id)
		var reach: float = tier.radius if tier != null else 1.0
		var spot: Vector3 = tier_view.global_position + to_camera.normalized() * reach
		puff(spot, Color(1.0, 0.98, 0.95), 18, 0.03))


func _burst(count: int, lifetime: float, size: float, color: Color, material: Material) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	particles.scale_amount_curve = _fade_curve()
	particles.color = color
	particles.color_ramp = _alpha_ramp()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _launch(particles: CPUParticles3D, at: Vector3) -> void:
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _make_trail() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "DustTrail"
	particles.amount = 40
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.emitting = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.06
	particles.direction = Vector3.DOWN
	particles.spread = 50.0
	particles.initial_velocity_min = 0.02
	particles.initial_velocity_max = 0.1
	particles.gravity = Vector3(0.0, -0.25, 0.0)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	particles.scale_amount_curve = _fade_curve()
	particles.color_ramp = _alpha_ramp()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = _glint_material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Billboards of a soft round dot; glints add light instead of covering.
func _billboard(glint: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glint else BaseMaterial3D.BLEND_MODE_MIX
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _star if glint else _dot
	material.disable_receive_shadows = true
	return material


static func _soft_dot(size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) - center, float(y) - center).length() / (float(size) * 0.5)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(clampf(1.0 - d, 0.0, 1.0), 1.6)))
	return ImageTexture.create_from_image(image)


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	return curve


static func _alpha_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.15, Color(1.0, 1.0, 1.0, 0.85))
	gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
	return gradient


## A soft four-point star: a glint of light.
static func _glint_star(size: int) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x) - center, float(y) - center) / (float(size) * 0.5)
			var core: float = pow(clampf(1.0 - p.length() * 3.0, 0.0, 1.0), 1.5)
			var rays: float = pow(clampf(1.0 - absf(p.x) * 9.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(p.y), 0.0, 1.0)
			rays += pow(clampf(1.0 - absf(p.y) * 9.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(p.x), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(core + rays * 0.8, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Grows as it fades: a cloud billowing out.
static func _grow_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(1.0, 1.0))
	return curve
