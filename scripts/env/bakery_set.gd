class_name BakerySet
extends Node3D
## The counter and surroundings the cake sits in.

const COUNTER_HEIGHT: float = 0.0


func _ready() -> void:
	name = "BakerySet"
	var counter := MeshInstance3D.new()
	counter.name = "Counter"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	counter.mesh = plane
	counter.material_override = Materials.standard(Color(0.88, 0.84, 0.79), 0.4)
	add_child(counter)
