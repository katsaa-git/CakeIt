class_name Props
extends RefCounted
## Simple bakery props built from code. They sit around the cake, mostly out
## of focus, so they only need nice silhouettes and materials.

static var _materials: Dictionary = {}


static func _mesh(mesh: Mesh, material: Material, position := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	return instance


static func _lathe(points: Array, segments: int = 48) -> ArrayMesh:
	var profile: Dictionary = LatheMesh.smooth_profile(PackedVector2Array(points))
	return LatheMesh.build(profile["points"], profile["normals"], segments)


## Glazed ceramic. Materials are shared by colour, so identical props can be
## merged into one draw call (see StaticBatcher).
static func glaze(color: Color, roughness: float = 0.18) -> StandardMaterial3D:
	var key: String = "glaze:%s:%.2f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.6
	material.clearcoat_enabled = true
	material.clearcoat = 0.5
	material.clearcoat_roughness = 0.1
	_materials[key] = material
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
	var key: String = "wood:%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	_materials[key] = material
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
		# Petals are open cups, seen from inside too: a copy with back faces on
		# (the cached material itself is shared and must stay unchanged).
		var bloom_material: StandardMaterial3D = _two_sided(petal_colors[i % petal_colors.size()], 0.65)
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


## A little pot of basil: a terracotta pot with dark soil and soft, cupped
## leaves in opposite pairs up each stem, each pair turned a quarter from the
## one below, like the real plant. Low-poly; it sits out of focus on the sill.
static func herb_pot() -> Node3D:
	var root := Node3D.new()
	root.name = "HerbPot"
	var terracotta := Materials.standard(Color(0.8, 0.5, 0.36), 0.85)
	root.add_child(_mesh(_lathe([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.33, 0.04), Vector2(0.4, 0.5), Vector2(0.47, 0.52),
		Vector2(0.48, 0.66), Vector2(0.44, 0.67), Vector2(0.4, 0.6), Vector2(0.0, 0.58)], 28), terracotta))
	root.add_child(_mesh(_lathe([Vector2(0, 0.6), Vector2(0.4, 0.6), Vector2(0.0, 0.62)], 20), Materials.standard(Color(0.3, 0.22, 0.17), 0.95)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var stem_material := Materials.standard(Color(0.42, 0.56, 0.3), 0.7)
	var leaf_mesh: ArrayMesh = _leaf_mesh()
	var greens: Array[StandardMaterial3D] = [_two_sided(Color(0.42, 0.64, 0.33), 0.55), _two_sided(Color(0.5, 0.7, 0.38), 0.55)]
	for i in range(8):
		var a: float = TAU * float(i) / 7.0 + rng.randf_range(-0.3, 0.3)
		var base := Vector3(cos(a) * 0.2, 0.6, sin(a) * 0.2) if i > 0 else Vector3(0.0, 0.6, 0.0)
		var lean := Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4).normalized() if i > 0 else Vector3.UP
		var height: float = rng.randf_range(0.5, 0.75) if i > 0 else 0.85
		var stem := CylinderMesh.new()
		stem.top_radius = 0.012
		stem.bottom_radius = 0.018
		stem.height = height
		stem.radial_segments = 5
		stem.rings = 1
		var stem_node := _mesh(stem, stem_material, base + lean * height * 0.5)
		stem_node.basis = Basis(Quaternion(Vector3.UP, lean))
		root.add_child(stem_node)
		var turn: float = rng.randf() * TAU
		var pairs: int = 4
		for k in range(pairs):
			var t: float = 0.35 + 0.65 * float(k) / float(pairs - 1)
			var size: float = lerpf(1.0, 0.5, float(k) / float(pairs - 1)) * rng.randf_range(0.85, 1.1)
			for side in [0.0, PI]:
				var yaw: float = turn + side + float(k) * PI * 0.5
				var leaf := _mesh(leaf_mesh, greens[(i + k) % 2], base + lean * height * t)
				# Leaves reach out and up a little, then droop at the tip (the mesh does that).
				leaf.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.35).scaled(Vector3.ONE * size)
				root.add_child(leaf)
		# A small cluster of young leaves at the top.
		for side in [0.4, 2.5, 4.6]:
			var tip := _mesh(leaf_mesh, greens[1], base + lean * height)
			tip.basis = Basis(Vector3.UP, turn + side) * Basis(Vector3.RIGHT, -0.9).scaled(Vector3.ONE * 0.4)
			root.add_child(tip)
	return root


## One basil leaf along +Z: an oval folded along its midrib, cupped, with the
## tip drooping. About 40 triangles.
static func _leaf_mesh() -> ArrayMesh:
	var out := MeshArrays.new()
	var length: float = 0.42
	var width: float = 0.24
	var steps: int = 6
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var w: float = sin(PI * pow(t, 0.75)) * width * 0.5
		for s in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var x: float = s * w
			var y: float = absf(s) * w * 0.45 - t * t * length * 0.35
			out.add_vertex(Vector3(x, y, t * length), Vector3.UP, Color.WHITE, Vector2((s + 1.0) * 0.5, t))
	for i in range(steps):
		for j in range(4):
			var a: int = i * 5 + j
			var b: int = a + 1
			var c: int = a + 5
			var d: int = c + 1
			out.add_triangle(a, c, b)
			out.add_triangle(b, c, d)
	# Smooth normals from the faces.
	var sums := PackedVector3Array()
	sums.resize(out.verts.size())
	for i in range(0, out.indices.size(), 3):
		var ia: int = out.indices[i]
		var ib: int = out.indices[i + 1]
		var ic: int = out.indices[i + 2]
		var face: Vector3 = (out.verts[ic] - out.verts[ia]).cross(out.verts[ib] - out.verts[ia])
		sums[ia] += face
		sums[ib] += face
		sums[ic] += face
	for i in range(sums.size()):
		out.normals[i] = sums[i].normalized() if sums[i].length_squared() > 0.0 else Vector3.UP
	return out.to_mesh()


static func _two_sided(color: Color, roughness: float) -> StandardMaterial3D:
	var key: String = "two_sided:%s:%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var material: StandardMaterial3D = Materials.standard(color, roughness).duplicate()
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material
	return _materials[key]
