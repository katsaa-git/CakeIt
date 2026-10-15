class_name BakerySet
extends Node3D
## A corner of a seaside bakery, built from code: a marble counter, a tiled
## backsplash, a white-framed window looking out to sea, sheer curtains, a
## shelf of jars, a linen cloth under the cake stand and a few props. Most of
## it sits behind the cake, softly out of focus.
##
## Scale: 1 unit = 10 cm. The counter top is at y = 0; the cake is at the origin.

const MARBLE: Shader = preload("res://art/shaders/marble.gdshader")
const TILES: Shader = preload("res://art/shaders/tiles.gdshader")
const WINDOW_VIEW: Shader = preload("res://art/shaders/window_view.gdshader")
const LINEN: Shader = preload("res://art/shaders/linen.gdshader")
const CURTAIN: Shader = preload("res://art/shaders/curtain.gdshader")

const WALL_Z: float = -5.6
const WINDOW_LEFT: float = -4.4
const WINDOW_RIGHT: float = 4.4
const WINDOW_BOTTOM: float = 2.8
const WINDOW_TOP: float = 13.2
const BACKSPLASH_TOP: float = 2.8


func _ready() -> void:
	name = "BakerySet"
	_build_counter()
	_build_wall()
	_build_window()
	_build_curtains()
	_build_shelf()
	_build_cloth()
	_build_props()


func _box(size: Vector3, center: Vector3, material: Material, node_name: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	if not node_name.is_empty():
		instance.name = node_name
	add_child(instance)
	return instance


func _build_counter() -> void:
	var marble := Materials.set_shader(MARBLE)
	_box(Vector3(40.0, 0.45, 14.0), Vector3(0.0, -0.225, WALL_Z + 7.0), marble, "Counter")


func _plaster() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.9, 0.83)
	material.roughness = 0.92
	return material


func _build_wall() -> void:
	var tiles := Materials.set_shader(TILES)
	_box(Vector3(40.0, BACKSPLASH_TOP, 0.12), Vector3(0.0, BACKSPLASH_TOP * 0.5, WALL_Z + 0.06), tiles, "Backsplash")
	var plaster := _plaster()
	var height: float = 30.0
	var left_width: float = 20.0 + WINDOW_LEFT
	_box(Vector3(left_width, height, 0.3), Vector3(-20.0 + left_width * 0.5, BACKSPLASH_TOP + height * 0.5, WALL_Z - 0.15), plaster, "WallLeft")
	_box(Vector3(left_width, height, 0.3), Vector3(20.0 - left_width * 0.5, BACKSPLASH_TOP + height * 0.5, WALL_Z - 0.15), plaster, "WallRight")
	var above: float = BACKSPLASH_TOP + height - WINDOW_TOP
	_box(Vector3(WINDOW_RIGHT - WINDOW_LEFT, above, 0.3), Vector3(0.0, WINDOW_TOP + above * 0.5, WALL_Z - 0.15), plaster, "WallAbove")
	# Side walls so wide shots never show the void.
	_box(Vector3(0.3, height, 20.0), Vector3(-20.0, height * 0.5, WALL_Z + 10.0), plaster, "SideLeft")
	_box(Vector3(0.3, height, 20.0), Vector3(20.0, height * 0.5, WALL_Z + 10.0), plaster, "SideRight")


func _build_window() -> void:
	var white := Props.glaze(Color(0.97, 0.96, 0.93), 0.35)
	var width: float = WINDOW_RIGHT - WINDOW_LEFT
	var height: float = WINDOW_TOP - WINDOW_BOTTOM
	var center_y: float = (WINDOW_TOP + WINDOW_BOTTOM) * 0.5
	var depth: float = 0.9
	var view_z: float = WALL_Z - depth
	# The view outside.
	var view := MeshInstance3D.new()
	view.name = "WindowView"
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	view.mesh = quad
	view.material_override = Materials.set_shader(WINDOW_VIEW)
	view.position = Vector3(0.0, center_y, view_z - 0.05)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	# Recess sides, sill, frame and glazing bars.
	_box(Vector3(0.25, height, depth), Vector3(WINDOW_LEFT - 0.125, center_y, WALL_Z - depth * 0.5), white)
	_box(Vector3(0.25, height, depth), Vector3(WINDOW_RIGHT + 0.125, center_y, WALL_Z - depth * 0.5), white)
	_box(Vector3(width + 0.5, 0.25, depth), Vector3(0.0, WINDOW_TOP + 0.125, WALL_Z - depth * 0.5), white)
	_box(Vector3(width + 1.2, 0.22, depth + 0.7), Vector3(0.0, WINDOW_BOTTOM - 0.11, WALL_Z - depth * 0.5 + 0.35), white, "Sill")
	var bar: float = 0.16
	_box(Vector3(bar, height, bar), Vector3(0.0, center_y, view_z + 0.12), white)
	_box(Vector3(width, bar, bar), Vector3(0.0, WINDOW_BOTTOM + height * 0.58, view_z + 0.12), white)
	for x in [WINDOW_LEFT + 0.12, WINDOW_RIGHT - 0.12]:
		_box(Vector3(0.24, height, 0.24), Vector3(x, center_y, view_z + 0.12), white)
	_box(Vector3(width, 0.24, 0.24), Vector3(0.0, WINDOW_TOP - 0.12, view_z + 0.12), white)
	_box(Vector3(width, 0.24, 0.24), Vector3(0.0, WINDOW_BOTTOM + 0.12, view_z + 0.12), white)
	# Outer trim.
	_box(Vector3(width + 1.0, 0.35, 0.12), Vector3(0.0, WINDOW_TOP + 0.3, WALL_Z + 0.06), white)
	for x in [WINDOW_LEFT - 0.35, WINDOW_RIGHT + 0.35]:
		_box(Vector3(0.35, height + 0.6, 0.12), Vector3(x, center_y + 0.15, WALL_Z + 0.06), white)
	# A little potted herb on the sill.
	var herb: Node3D = Props.herb_pot()
	herb.position = Vector3(WINDOW_RIGHT - 1.4, WINDOW_BOTTOM, WALL_Z - 0.25)
	herb.scale = Vector3.ONE * 1.6
	add_child(herb)


func _build_curtains() -> void:
	for side in [-1.0, 1.0]:
		var curtain := MeshInstance3D.new()
		curtain.name = "Curtain"
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.4, 11.6)
		plane.subdivide_width = 48
		plane.subdivide_depth = 24
		plane.orientation = PlaneMesh.FACE_Z
		curtain.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = CURTAIN
		curtain.material_override = material
		var x: float = (WINDOW_RIGHT + 0.3) * side - 0.6 * side
		curtain.position = Vector3(x, WINDOW_BOTTOM + 0.6 + 5.8 + 0.4, WALL_Z + 0.45)
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(curtain)
	# Curtain rail.
	var rail := CylinderMesh.new()
	rail.top_radius = 0.07
	rail.bottom_radius = 0.07
	rail.height = WINDOW_RIGHT - WINDOW_LEFT + 4.0
	var rail_node := MeshInstance3D.new()
	rail_node.mesh = rail
	rail_node.material_override = Props.wood(Color(0.6, 0.44, 0.3))
	rail_node.rotation.z = PI * 0.5
	rail_node.position = Vector3(0.0, WINDOW_TOP + 0.8, WALL_Z + 0.5)
	add_child(rail_node)


func _build_shelf() -> void:
	var plank := Props.wood(Color(0.74, 0.56, 0.4))
	var shelf_y: float = 7.6
	_box(Vector3(5.6, 0.18, 1.3), Vector3(10.2, shelf_y, WALL_Z + 0.65), plank, "Shelf")
	for x in [8.0, 12.4]:
		_box(Vector3(0.16, 0.8, 1.0), Vector3(x, shelf_y - 0.45, WALL_Z + 0.5), plank)
	var jars: Array = [[Color(0.98, 0.97, 0.94), 1.3, 8.6], [Color(0.97, 0.78, 0.82), 1.0, 9.7], [Color(0.55, 0.37, 0.27), 1.5, 10.8]]
	for entry: Array in jars:
		var jar: Node3D = Props.storage_jar(entry[0], entry[1])
		jar.position = Vector3(entry[2], shelf_y + 0.09, WALL_Z + 0.65)
		add_child(jar)
	var plates: Node3D = Props.plate_stack(4)
	plates.position = Vector3(12.0, shelf_y + 0.09, WALL_Z + 0.6)
	plates.scale = Vector3.ONE * 0.8
	add_child(plates)


func _build_cloth() -> void:
	# A linen tea towel under the stand, with soft folds toward its edges.
	var size: float = 5.6
	var steps: int = 40
	var out := MeshArrays.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.35
	noise.seed = 4
	for j in range(steps + 1):
		for i in range(steps + 1):
			var u: float = float(i) / float(steps)
			var v: float = float(j) / float(steps)
			var x: float = (u - 0.5) * size
			var z: float = (v - 0.5) * size
			var edge: float = smoothstep(1.2, size * 0.5, maxf(absf(x), absf(z)))
			var y: float = 0.01 + absf(noise.get_noise_2d(x * 1.6, z * 1.6)) * 0.09 * edge
			out.add_vertex(Vector3(x, y, z), Vector3.UP, Color.WHITE, Vector2(u, v))
	for j in range(steps):
		for i in range(steps):
			var a: int = j * (steps + 1) + i
			var b: int = a + 1
			var c: int = a + steps + 1
			var d: int = c + 1
			# Clockwise from above, so the cloth faces up.
			out.add_triangle(a, b, c)
			out.add_triangle(b, d, c)
	_smooth_normals(out)
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	cloth.mesh = out.to_mesh()
	var material := ShaderMaterial.new()
	material.shader = LINEN
	cloth.material_override = material
	cloth.rotation.y = 0.32
	add_child(cloth)


func _smooth_normals(out: MeshArrays) -> void:
	var sums := PackedVector3Array()
	sums.resize(out.verts.size())
	for i in range(0, out.indices.size(), 3):
		var a: int = out.indices[i]
		var b: int = out.indices[i + 1]
		var c: int = out.indices[i + 2]
		var face: Vector3 = (out.verts[c] - out.verts[a]).cross(out.verts[b] - out.verts[a])
		sums[a] += face
		sums[b] += face
		sums[c] += face
	for i in range(sums.size()):
		out.normals[i] = sums[i].normalized() if sums[i].length_squared() > 0.0 else Vector3.UP


func _build_props() -> void:
	var jar: Node3D = Props.sprinkle_jar()
	jar.position = Vector3(-5.4, 0.0, -2.6)
	jar.scale = Vector3.ONE * 1.5
	add_child(jar)
	var jug: Node3D = Props.flower_jug()
	jug.position = Vector3(-8.2, 0.0, -3.4)
	jug.scale = Vector3.ONE * 1.7
	add_child(jug)
	var bowl: Node3D = Props.mixing_bowl()
	bowl.position = Vector3(6.2, 0.0, -3.0)
	bowl.scale = Vector3.ONE * 1.5
	add_child(bowl)
	var plates: Node3D = Props.plate_stack(2)
	plates.position = Vector3(5.2, 0.0, 1.6)
	plates.scale = Vector3.ONE * 1.3
	add_child(plates)
