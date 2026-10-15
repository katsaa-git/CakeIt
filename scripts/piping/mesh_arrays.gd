class_name MeshArrays
extends RefCounted
## Growable vertex and index lists for one piece of procedural geometry.
## Cheaper than SurfaceTool for code that streams many vertices, and easy to
## merge: appending another MeshArrays offsets its indices automatically.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
## x = distance along the stroke (in tip radii), y = position around the profile (0..1).
var uvs := PackedVector2Array()
var indices := PackedInt32Array()


func vertex_count() -> int:
	return verts.size()


func is_empty() -> bool:
	return indices.is_empty()


func clear() -> void:
	verts.clear()
	normals.clear()
	colors.clear()
	uvs.clear()
	indices.clear()


func add_vertex(position: Vector3, normal: Vector3, color: Color, uv: Vector2) -> void:
	verts.append(position)
	normals.append(normal)
	colors.append(color)
	uvs.append(uv)


func add_triangle(a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)


## Appends another piece of geometry, shifting its indices to fit after ours.
func append(other: MeshArrays) -> void:
	var offset: int = verts.size()
	verts.append_array(other.verts)
	normals.append_array(other.normals)
	colors.append_array(other.colors)
	uvs.append_array(other.uvs)
	if offset == 0:
		indices.append_array(other.indices)
		return
	var start: int = indices.size()
	indices.append_array(other.indices)
	for i in range(start, indices.size()):
		indices[i] += offset


func duplicate_arrays() -> MeshArrays:
	var copy := MeshArrays.new()
	copy.verts = verts.duplicate()
	copy.normals = normals.duplicate()
	copy.colors = colors.duplicate()
	copy.uvs = uvs.duplicate()
	copy.indices = indices.duplicate()
	return copy


func to_surface_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Replaces the mesh's contents with this geometry (or empties it).
func commit_to(mesh: ArrayMesh, material: Material = null) -> void:
	mesh.clear_surfaces()
	if indices.is_empty():
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_surface_arrays())
	if material != null:
		mesh.surface_set_material(0, material)


func to_mesh(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	commit_to(mesh, material)
	return mesh


## Axis-aligned bounds of the vertices (empty AABB if there are none).
func bounds() -> AABB:
	if verts.is_empty():
		return AABB()
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box
