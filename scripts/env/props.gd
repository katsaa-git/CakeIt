class_name Props
extends RefCounted
## Simple bakery props built from code. They sit around the cake, mostly out
## of focus, so they only need nice silhouettes and materials.


static func _mesh(mesh: Mesh, material: Material, position := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	return instance


static func _lathe(points: Array, segments: int = 48) -> ArrayMesh:
	var profile: Dictionary = LatheMesh.smooth_profile(PackedVector2Array(points))
	return LatheMesh.build(profile["points"], profile["normals"], segments)


static func glaze(color: Color, roughness: float = 0.18) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.6
	material.clearcoat_enabled = true
	material.clearcoat = 0.5
	material.clearcoat_roughness = 0.1
	return material


static func glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.97, 0.97, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.04
	material.metallic_specular = 0.9
	material.rim_enabled = true
	material.rim = 0.6
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func wood(color: Color = Color(0.72, 0.53, 0.36)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material


## A texture full of tiny sprinkles in happy colours, drawn at startup.
static func sprinkle_texture(seed_value: int = 3) -> ImageTexture:
	var size: int = 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.97, 0.93))
	var colors: Array[Color] = [Color(0.96, 0.55, 0.65), Color(0.55, 0.78, 0.95), Color(0.99, 0.84, 0.4),
		Color(0.6, 0.85, 0.65), Color(0.78, 0.66, 0.94), Color(1.0, 1.0, 1.0), Color(0.95, 0.65, 0.45)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(900):
		var center := Vector2(rng.randf() * size, rng.randf() * size)
		var angle: float = rng.randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var color: Color = colors[rng.randi() % colors.size()]
		for t in range(-4, 5):
			for w in range(-1, 2):
				var p: Vector2 = center + dir * float(t) + Vector2(-dir.y, dir.x) * float(w) * 0.8
				image.set_pixel(posmod(int(p.x), size), posmod(int(p.y), size), color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func sprinkle_jar() -> Node3D:
	var root := Node3D.new()
	root.name = "SprinkleJar"
	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_texture = sprinkle_texture()
	fill_material.uv1_scale = Vector3(3.0, 2.0, 1.0)
	fill_material.roughness = 0.5
	root.add_child(_mesh(_lathe([Vector2(0, 0.02), Vector2(0.52, 0.02), Vector2(0.55, 0.1), Vector2(0.55, 1.15), Vector2(0.0, 1.15)]), fill_material))
	root.add_child(_mesh(_lathe([Vector2(0, 0), Vector2(0.6, 0), Vector2(0.62, 0.06), Vector2(0.62, 1.55), Vector2(0.5, 1.62), Vector2(0.5, 1.7), Vector2(0, 1.7)]), glass()))
	root.add_child(_mesh(_lathe([Vector2(0, 1.68), Vector2(0.56, 1.68), Vector2(0.58, 1.75), Vector2(0.56, 1.92), Vector2(0, 1.95)]), wood()))
	return root


static func flower_jug() -> Node3D:
	var root := Node3D.new()
	root.name = "FlowerJug"
	var jug := _lathe([Vector2(0, 0), Vector2(0.55, 0), Vector2(0.62, 0.08), Vector2(0.72, 0.5), Vector2(0.66, 1.0),
		Vector2(0.46, 1.4), Vector2(0.42, 1.65), Vector2(0.48, 1.8), Vector2(0.42, 1.82), Vector2(0.0, 1.6)])
	root.add_child(_mesh(jug, glaze(Color(0.72, 0.82, 0.74))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var petal_colors: Array[Color] = [Color(0.98, 0.76, 0.8), Color(1.0, 0.95, 0.9), Color(0.99, 0.82, 0.68), Color(0.94, 0.62, 0.72)]
	var stem_material := Materials.standard(Color(0.45, 0.62, 0.38), 0.6)
	# A tulip head: a soft cup of petals, open at the top.
	var tulip := _lathe([Vector2(0.0, 0.0), Vector2(0.1, 0.03), Vector2(0.19, 0.14), Vector2(0.21, 0.3), Vector2(0.17, 0.44), Vector2(0.13, 0.48)], 6)
	var leaf := _lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.3), Vector2(0.07, 0.8), Vector2(0.0, 1.1)], 4)
	for i in range(7):
		var lean := Vector3(rng.randf_range(-0.45, 0.45), 1.0, rng.randf_range(-0.45, 0.45)).normalized()
		var length: float = rng.randf_range(1.5, 2.3)
		var stem := CylinderMesh.new()
		stem.top_radius = 0.025
		stem.bottom_radius = 0.032
		stem.height = length
		stem.radial_segments = 8
		var stem_node := _mesh(stem, stem_material)
		stem_node.basis = Basis(Quaternion(Vector3.UP, lean))
		stem_node.position = Vector3(0.0, 1.3, 0.0) + lean * length * 0.5
		root.add_child(stem_node)
		var bloom_material := Materials.standard(petal_colors[i % petal_colors.size()], 0.65)
		bloom_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var head := _mesh(tulip, bloom_material, Vector3(0.0, 1.3, 0.0) + lean * (length - 0.05))
		head.basis = Basis(Quaternion(Vector3.UP, lean)).rotated(lean, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2))
		root.add_child(head)
		if i % 2 == 0:
			var leaf_node := _mesh(leaf, Materials.standard(Color(0.5, 0.68, 0.42), 0.6), Vector3(0.0, 1.35, 0.0))
			leaf_node.basis = Basis(Quaternion(Vector3.UP, (lean + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))).normalized())).scaled(Vector3(1.0, 1.0, 0.3))
			root.add_child(leaf_node)
	return root


static func mixing_bowl() -> Node3D:
	var root := Node3D.new()
	root.name = "MixingBowl"
	var bowl := _lathe([Vector2(0, 0), Vector2(0.55, 0), Vector2(0.6, 0.06), Vector2(0.95, 0.35), Vector2(1.25, 0.82),
		Vector2(1.3, 0.9), Vector2(1.22, 0.9), Vector2(1.15, 0.84), Vector2(0.0, 0.2)])
	root.add_child(_mesh(bowl, glaze(Color(0.66, 0.78, 0.88))))
	var batter := _lathe([Vector2(0, 0.62), Vector2(1.05, 0.62), Vector2(0.0, 0.66)])
	root.add_child(_mesh(batter, Materials.standard(Color(0.98, 0.92, 0.8), 0.6)))
	return root


static func plate_stack(count: int = 3) -> Node3D:
	var root := Node3D.new()
	root.name = "Plates"
	var plate := _lathe([Vector2(0, 0), Vector2(0.8, 0), Vector2(1.1, 0.08), Vector2(1.18, 0.12), Vector2(1.1, 0.13), Vector2(0.75, 0.06), Vector2(0, 0.06)], 56)
	for i in range(count):
		var node := _mesh(plate, glaze(Color(0.98, 0.96, 0.93)), Vector3(0.0, float(i) * 0.12, 0.0))
		node.rotation.y = float(i) * 0.7
		root.add_child(node)
	return root


static func storage_jar(contents: Color, height: float = 1.2) -> Node3D:
	var root := Node3D.new()
	root.name = "Jar"
	root.add_child(_mesh(_lathe([Vector2(0, 0.02), Vector2(0.38, 0.02), Vector2(0.4, height * 0.65), Vector2(0, height * 0.66)]), Materials.standard(contents, 0.8)))
	root.add_child(_mesh(_lathe([Vector2(0, 0), Vector2(0.44, 0), Vector2(0.45, height), Vector2(0.36, height + 0.06), Vector2(0, height + 0.06)]), glass()))
	root.add_child(_mesh(_lathe([Vector2(0, height + 0.04), Vector2(0.4, height + 0.04), Vector2(0.4, height + 0.18), Vector2(0, height + 0.2)]), wood(Color(0.62, 0.45, 0.3))))
	return root


static func herb_pot() -> Node3D:
	var root := Node3D.new()
	root.name = "HerbPot"
	root.add_child(_mesh(_lathe([Vector2(0, 0), Vector2(0.32, 0), Vector2(0.42, 0.55), Vector2(0.47, 0.58), Vector2(0.47, 0.68), Vector2(0, 0.66)]), Materials.standard(Color(0.82, 0.52, 0.38), 0.85)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var leaf_material := Materials.standard(Color(0.48, 0.66, 0.42), 0.7)
	for i in range(12):
		var leaf := SphereMesh.new()
		leaf.radius = rng.randf_range(0.14, 0.22)
		leaf.height = leaf.radius * 1.6
		root.add_child(_mesh(leaf, leaf_material, Vector3(rng.randf_range(-0.3, 0.3), 0.75 + rng.randf() * 0.45, rng.randf_range(-0.3, 0.3))))
	return root
