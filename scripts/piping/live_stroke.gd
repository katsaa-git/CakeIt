class_name LiveStroke
extends Node3D
## Shows a stroke while it is being piped. Sealed chunks from the builder get
## their own mesh once and are never touched again; only the short tail near
## the nozzle is re-uploaded each frame, so cost stays flat however long the
## line gets. Lives under the tier's view, so it turns with the turntable.

var builder: StrokeBuilder
var material: Material

var _shown: int = 0
var _tail_mesh := ArrayMesh.new()
var _tail: MeshInstance3D


func setup(new_builder: StrokeBuilder, new_material: Material) -> void:
	builder = new_builder
	material = new_material
	name = "LiveStroke"
	_tail = MeshInstance3D.new()
	_tail.mesh = _tail_mesh
	add_child(_tail)


## Call once per frame after feeding the builder.
func refresh() -> void:
	while _shown < builder.pieces.size():
		var piece: MeshArrays = builder.pieces[_shown]
		var instance := MeshInstance3D.new()
		instance.mesh = piece.to_mesh(material)
		add_child(instance)
		_shown += 1
	builder.preview().commit_to(_tail_mesh, material)
