class_name RoundTierShape
extends TierShape
## A round tier: a cylinder with crisp but softened edges, like a cake
## smoothed with a bench scraper.

const SEGMENTS: int = 160


func build_mesh(tier: TierData) -> ArrayMesh:
	var profile: Dictionary = LatheMesh.rounded_cylinder_profile(tier.radius, tier.height, edge_radius(tier), 7)
	return LatheMesh.build(profile["points"], profile["normals"], SEGMENTS)


func build_collision(tier: TierData) -> Shape3D:
	var profile: Dictionary = LatheMesh.rounded_cylinder_profile(tier.radius, tier.height, edge_radius(tier), 4)
	var arrays: MeshArrays = LatheMesh.build_arrays(profile["points"], profile["normals"], 96)
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	TubeBuilder.triangles_for_collision(arrays, faces)
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape


func rim_point(tier: TierData, angle: float) -> Array:
	var e: float = edge_radius(tier)
	# Middle of the rounded top edge, normal pointing out and up.
	var n := Vector3(cos(angle) * 0.7071, 0.7071, sin(angle) * 0.7071)
	var centre := Vector3(cos(angle) * (tier.radius - e), tier.height - e, sin(angle) * (tier.radius - e))
	return [centre + n * e, n]


func side_point(tier: TierData, angle: float, y: float) -> Array:
	var n := Vector3(cos(angle), 0.0, sin(angle))
	return [n * tier.radius + Vector3(0.0, y, 0.0), n]
