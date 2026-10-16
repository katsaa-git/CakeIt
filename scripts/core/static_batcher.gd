class_name StaticBatcher
extends RefCounted
## Merges many small, never-moving meshes into one mesh with one surface per
## material, so a set full of props costs a handful of draw calls instead of
## one per jar, plank and plate.
##
## Only meshes whose material is shared by at least two of them are merged
## (merging a one-off gains nothing). Transparent materials are left alone so
## they keep sorting correctly, and any node can opt out with the meta
## "no_merge" (for things that will move or animate).


## Merges the static meshes under `root` into a single child of `root` and
## frees the originals. Returns how many meshes were merged.
static func merge(root: Node3D, merged_name: String = "MergedStatic") -> int:
	var groups: Dictionary = {}
	var to_root: Transform3D = root.global_transform.affine_inverse()
	for instance in _candidates(root):
		var material: Material = instance.material_override
		if not groups.has(material):
			groups[material] = []
		(groups[material] as Array).append(instance)

	var mesh := ArrayMesh.new()
	var merged: Array[MeshInstance3D] = []
	for material: Material in groups:
		var members: Array = groups[material]
		if members.size() < 2:
			continue
		var arrays: Array = []
		for instance: MeshInstance3D in members:
			var xform: Transform3D = to_root * instance.global_transform
			for surface in range(instance.mesh.get_surface_count()):
				arrays = _append(arrays, instance.mesh.surface_get_arrays(surface), xform)
			merged.append(instance)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)

	if merged.is_empty():
		return 0
	var node := MeshInstance3D.new()
	node.name = merged_name
	node.mesh = mesh
	root.add_child(node)
	for instance in merged:
		instance.get_parent().remove_child(instance)
		instance.queue_free()
	# Holder nodes (a prop's root) that are now empty can go too.
	_free_empty(root, node)
	return merged.size()


static func _candidates(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child.has_meta("no_merge"):
			continue
		var instance := child as MeshInstance3D
		if instance != null and instance.mesh != null and instance.visible and _mergeable(instance.material_override):
			out.append(instance)
		out.append_array(_candidates(child))
	return out


static func _mergeable(material: Material) -> bool:
	if material == null:
		return false
	var standard := material as BaseMaterial3D
	if standard != null:
		return standard.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	return material is ShaderMaterial


## Appends one surface (moved by `xform`) to the accumulated arrays.
static func _append(into: Array, surface: Array, xform: Transform3D) -> Array:
	var normal_basis: Basis = xform.basis.inverse().transposed()
	var verts: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var count: int = verts.size()
	var moved := PackedVector3Array()
	moved.resize(count)
	for i in range(count):
		moved[i] = xform * verts[i]
	var normals := PackedVector3Array()
	if surface[Mesh.ARRAY_NORMAL] != null:
		var source: PackedVector3Array = surface[Mesh.ARRAY_NORMAL]
		normals.resize(count)
		for i in range(count):
			normals[i] = (normal_basis * source[i]).normalized()
	var tangents := PackedFloat32Array()
	if surface[Mesh.ARRAY_TANGENT] != null:
		var source: PackedFloat32Array = surface[Mesh.ARRAY_TANGENT]
		tangents.resize(source.size())
		for i in range(count):
			var t: Vector3 = (xform.basis * Vector3(source[i * 4], source[i * 4 + 1], source[i * 4 + 2])).normalized()
			tangents[i * 4] = t.x
			tangents[i * 4 + 1] = t.y
			tangents[i * 4 + 2] = t.z
			tangents[i * 4 + 3] = source[i * 4 + 3]
	var uvs: PackedVector2Array = surface[Mesh.ARRAY_TEX_UV] if surface[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if uvs.size() != count:
		uvs = PackedVector2Array()
		uvs.resize(count)
	var colors: PackedColorArray = surface[Mesh.ARRAY_COLOR] if surface[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices := PackedInt32Array()
	if surface[Mesh.ARRAY_INDEX] != null:
		indices = surface[Mesh.ARRAY_INDEX]
	else:
		indices.resize(count)
		for i in range(count):
			indices[i] = i

	if into.is_empty():
		into.resize(Mesh.ARRAY_MAX)
		into[Mesh.ARRAY_VERTEX] = PackedVector3Array()
		into[Mesh.ARRAY_NORMAL] = PackedVector3Array()
		into[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
		into[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
		into[Mesh.ARRAY_COLOR] = PackedColorArray()
		into[Mesh.ARRAY_INDEX] = PackedInt32Array()
	if normals.is_empty():
		normals.resize(count)
		normals.fill(Vector3.UP)
	if tangents.is_empty():
		tangents.resize(count * 4)
		for i in range(count):
			tangents[i * 4] = 1.0
			tangents[i * 4 + 3] = 1.0
	if colors.size() != count:
		colors = PackedColorArray()
		colors.resize(count)
		colors.fill(Color.WHITE)
	# Packed arrays are values in GDScript: take each one out, grow it, put it back.
	var all_verts: PackedVector3Array = into[Mesh.ARRAY_VERTEX]
	var offset: int = all_verts.size()
	all_verts.append_array(moved)
	into[Mesh.ARRAY_VERTEX] = all_verts
	var all_normals: PackedVector3Array = into[Mesh.ARRAY_NORMAL]
	all_normals.append_array(normals)
	into[Mesh.ARRAY_NORMAL] = all_normals
	var all_tangents: PackedFloat32Array = into[Mesh.ARRAY_TANGENT]
	all_tangents.append_array(tangents)
	into[Mesh.ARRAY_TANGENT] = all_tangents
	var all_uvs: PackedVector2Array = into[Mesh.ARRAY_TEX_UV]
	all_uvs.append_array(uvs)
	into[Mesh.ARRAY_TEX_UV] = all_uvs
	var all_colors: PackedColorArray = into[Mesh.ARRAY_COLOR]
	all_colors.append_array(colors)
	into[Mesh.ARRAY_COLOR] = all_colors
	var all_indices: PackedInt32Array = into[Mesh.ARRAY_INDEX]
	var start: int = all_indices.size()
	all_indices.append_array(indices)
	for i in range(start, all_indices.size()):
		all_indices[i] += offset
	into[Mesh.ARRAY_INDEX] = all_indices
	return into


static func _free_empty(node: Node, keep: Node) -> void:
	for child in node.get_children():
		if child == keep:
			continue
		_free_empty(child, keep)
		if child.get_child_count() == 0 and child.get_class() == "Node3D":
			node.remove_child(child)
			child.queue_free()
