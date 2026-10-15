class_name CakeTier
extends StaticBody3D
## One round cake tier: a rounded cylinder built from code, with a collision
## shape so the mouse ray can hit its surface.
##
## Scale: 1 unit = 10 cm. A tier of radius 1.5 is a 30 cm wide cake.

const COLLISION_LAYER_CAKE: int = 1

var tier_radius: float = 1.5
var tier_height: float = 1.0


func setup(radius: float, height: float, material: Material) -> void:
	tier_radius = radius
	tier_height = height
	name = "CakeTier"
	collision_layer = COLLISION_LAYER_CAKE
	collision_mask = 0
	var profile: Dictionary = LatheMesh.rounded_cylinder_profile(radius, height, minf(0.12, height * 0.25))
	var mesh: ArrayMesh = LatheMesh.build(profile["points"], profile["normals"], 72)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add_child(shape)
