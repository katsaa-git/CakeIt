class_name StrokeBatch
extends Node3D
## All the piped strokes on one tier, merged into a few big meshes ("chunks")
## so a heavily decorated cake stays cheap to draw.
##
## A newly added stroke is shown right away (the piping tool hands over the
## very meshes the player watched being piped), then merged into a chunk a
## little at a time within a per-frame time budget, so finishing even a very
## long stroke never causes a hitch. Removing a stroke only drops its
## triangles from the chunk's index list; unused vertices are cleaned up once
## enough of them pile up.
##
## Each stroke also gets a low-detail collision body (in the unrotated
## collision tree) so you can pipe and decorate on top of it. Its shapes are
## built in small slices over a few frames.

const MAX_CHUNK_VERTS: int = 32000
const MERGE_BUDGET_USEC: int = 1500
const COLLISION_BUDGET_USEC: int = 1200
## Triangles per collision shape slice.
const COLLISION_SLICE: int = 900
const COMPACT_RATIO: float = 0.55


class Chunk:
	var node: MeshInstance3D
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	## stroke id -> PackedInt32Array of indices already offset into this chunk.
	var strokes: Dictionary = {}
	var garbage_verts: int = 0
	var dirty: bool = false


class Entry:
	var id: int
	var pieces: Array[MeshArrays] = []
	var vertex_count: int = 0
	var faces := PackedVector3Array()
	## How many collision triangles have shapes so far.
	var faces_done: int = 0
	var pending_node: Node3D
	var body: StaticBody3D
	var chunk: Chunk


var tier_id: int = 0
var material: Material
## Where collision bodies go (this tier's frame in the unrotated collision tree).
var collision_parent: Node3D

var _entries: Dictionary = {}
var _queue: Array[int] = []
var _collision_queue: Array[int] = []
var _chunks: Array[Chunk] = []


func setup(new_tier_id: int, new_material: Material, new_collision_parent: Node3D) -> void:
	tier_id = new_tier_id
	material = new_material
	collision_parent = new_collision_parent
	name = "StrokeBatch"


func has_stroke(id: int) -> bool:
	return _entries.has(id)


func stroke_count() -> int:
	return _entries.size()


func chunk_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _queue.size() + _collision_queue.size()


## Shows a finished stroke immediately and queues it for merging. Pass the
## node that is already showing it (the live stroke) as `display` to reuse
## its meshes; otherwise meshes are made from `pieces`.
func add(id: int, pieces: Array[MeshArrays], collision_faces: PackedVector3Array, display: Node3D = null) -> void:
	if _entries.has(id):
		remove(id)
	var entry := Entry.new()
	entry.id = id
	entry.pieces = pieces
	for piece in pieces:
		entry.vertex_count += piece.vertex_count()
	if display != null:
		var transform_before: Transform3D = display.global_transform
		if display.get_parent() != null:
			display.get_parent().remove_child(display)
		add_child(display)
		display.global_transform = transform_before
		entry.pending_node = display
	else:
		entry.pending_node = Node3D.new()
		entry.pending_node.name = "Pending%d" % id
		for piece in pieces:
			var instance := MeshInstance3D.new()
			instance.mesh = piece.to_mesh(material)
			entry.pending_node.add_child(instance)
		add_child(entry.pending_node)
	entry.faces = collision_faces
	_entries[id] = entry
	_queue.append(id)
	_collision_queue.append(id)


## Removes a stroke. Returns [pieces, collision_faces] so it can come back
## instantly on redo (empty if the stroke was not here).
func remove(id: int) -> Array:
	var entry: Entry = _entries.get(id)
	if entry == null:
		return []
	_entries.erase(id)
	if entry.chunk != null:
		entry.chunk.strokes.erase(id)
		entry.chunk.garbage_verts += entry.vertex_count
		entry.chunk.dirty = true
	if entry.pending_node != null:
		entry.pending_node.queue_free()
		_queue.erase(id)
	_collision_queue.erase(id)
	if entry.body != null:
		entry.body.queue_free()
	return [entry.pieces, entry.faces]


func clear_all() -> void:
	for id in _entries.keys():
		remove(id)
	for chunk in _chunks:
		chunk.node.queue_free()
	_chunks.clear()


## Merges everything and builds all collision right away (tests, benchmarks).
func flush() -> void:
	_merge(1 << 30)
	_build_collision(1 << 30)


func _process(_delta: float) -> void:
	_merge(MERGE_BUDGET_USEC)
	_build_collision(COLLISION_BUDGET_USEC)


func _merge(budget_usec: int) -> void:
	var started: int = Time.get_ticks_usec()
	var merged: Array[Entry] = []
	while not _queue.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var entry: Entry = _entries.get(_queue.pop_front())
		if entry == null:
			continue
		var chunk: Chunk = _chunk_with_room(entry.vertex_count)
		chunk.strokes[entry.id] = _append_pieces(chunk, entry.pieces)
		chunk.dirty = true
		entry.chunk = chunk
		merged.append(entry)
	for chunk in _chunks:
		if chunk.dirty:
			_compact_if_wasteful(chunk)
			_rebuild_chunk(chunk)
	# The chunk meshes now include these strokes, so drop their temporary meshes
	# in the same frame (no flicker).
	for entry in merged:
		if entry.pending_node != null:
			entry.pending_node.queue_free()
			entry.pending_node = null


func _append_pieces(chunk: Chunk, pieces: Array[MeshArrays]) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for piece in pieces:
		var offset: int = chunk.verts.size()
		chunk.verts.append_array(piece.verts)
		chunk.normals.append_array(piece.normals)
		chunk.colors.append_array(piece.colors)
		chunk.uvs.append_array(piece.uvs)
		var start: int = indices.size()
		indices.append_array(piece.indices)
		for i in range(start, indices.size()):
			indices[i] += offset
	return indices


func _build_collision(budget_usec: int) -> void:
	if collision_parent == null:
		_collision_queue.clear()
		return
	var started: int = Time.get_ticks_usec()
	while not _collision_queue.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var entry: Entry = _entries.get(_collision_queue[0])
		if entry == null or entry.faces.size() < 3:
			_collision_queue.pop_front()
			continue
		if entry.body == null:
			entry.body = _make_body(entry.id)
		var total: int = entry.faces.size() / 3
		var count: int = mini(COLLISION_SLICE, total - entry.faces_done)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(entry.faces.slice(entry.faces_done * 3, (entry.faces_done + count) * 3))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		entry.body.add_child(collision)
		entry.faces_done += count
		if entry.faces_done >= total:
			_collision_queue.pop_front()


func _chunk_with_room(vertex_count: int) -> Chunk:
	if not _chunks.is_empty():
		var last: Chunk = _chunks[_chunks.size() - 1]
		if last.verts.size() + vertex_count <= MAX_CHUNK_VERTS or last.verts.is_empty():
			return last
	var chunk := Chunk.new()
	chunk.node = MeshInstance3D.new()
	chunk.node.name = "Chunk%d" % _chunks.size()
	chunk.node.mesh = chunk.mesh
	add_child(chunk.node)
	_chunks.append(chunk)
	return chunk


func _rebuild_chunk(chunk: Chunk) -> void:
	chunk.dirty = false
	chunk.mesh.clear_surfaces()
	var indices := PackedInt32Array()
	for stroke_indices: PackedInt32Array in chunk.strokes.values():
		indices.append_array(stroke_indices)
	if indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = chunk.verts
	arrays[Mesh.ARRAY_NORMAL] = chunk.normals
	arrays[Mesh.ARRAY_COLOR] = chunk.colors
	arrays[Mesh.ARRAY_TEX_UV] = chunk.uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	chunk.mesh.surface_set_material(0, material)


## Rebuilds a chunk's vertex lists from its remaining strokes when most of
## its vertices are no longer used (after lots of undo).
func _compact_if_wasteful(chunk: Chunk) -> void:
	if chunk.verts.size() < 8000 or float(chunk.garbage_verts) < float(chunk.verts.size()) * COMPACT_RATIO:
		return
	var ids: Array = chunk.strokes.keys()
	chunk.verts = PackedVector3Array()
	chunk.normals = PackedVector3Array()
	chunk.colors = PackedColorArray()
	chunk.uvs = PackedVector2Array()
	chunk.strokes.clear()
	chunk.garbage_verts = 0
	for id: int in ids:
		var entry: Entry = _entries.get(id)
		if entry != null:
			chunk.strokes[id] = _append_pieces(chunk, entry.pieces)


func _make_body(id: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Stroke%d" % id
	body.collision_layer = CakePicker.LAYER_CAKE
	body.collision_mask = 0
	body.set_meta("tier_id", tier_id)
	body.set_meta("kind", &"stroke")
	body.set_meta("item_id", id)
	collision_parent.add_child(body)
	return body
