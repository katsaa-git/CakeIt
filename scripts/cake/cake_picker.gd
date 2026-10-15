class_name CakePicker
extends RefCounted
## Finds what the mouse is pointing at on the cake.
##
## Collision shapes live in their own unrotated copy of the cake ("cake
## frame"), so the turntable never has to move them. To pick, the mouse ray
## is turned into the cake frame (undoing the spin), tested there, and the
## result is turned back into world space for effects and the piping bag.

const LAYER_CAKE: int = 1


class Hit:
	## Which tier was hit (CakeModel.BOARD_ID for the stand's plate).
	var tier_id: int = 0
	## &"tier", &"board", &"stroke" or &"decoration".
	var kind: StringName = &""
	var item_id: int = 0
	## Point and normal in the cake frame (origin: centre of the stand top).
	var cake_position := Vector3.ZERO
	var cake_normal := Vector3.UP
	## Point in the hit tier's own frame (origin: centre of its bottom face).
	var local_position := Vector3.ZERO
	var world_position := Vector3.ZERO
	var world_normal := Vector3.UP
	## The pick ray in the cake frame.
	var ray_origin := Vector3.ZERO
	var ray_direction := Vector3.FORWARD


var camera: Camera3D
## Spins with the turntable; the cake visuals are under it.
var spin_root: Node3D
## Unrotated twin of spin_root holding the collision shapes.
var collision_root: Node3D
var model: CakeModel


func _init(new_camera: Camera3D, new_spin_root: Node3D, new_collision_root: Node3D, new_model: CakeModel) -> void:
	camera = new_camera
	spin_root = new_spin_root
	collision_root = new_collision_root
	model = new_model


## The mouse ray in the cake frame: [origin, direction].
func ray_in_cake_frame(screen_position: Vector2) -> Array:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var inverse: Transform3D = spin_root.global_transform.affine_inverse()
	return [inverse * origin, (inverse.basis * direction).normalized()]


func pick(screen_position: Vector2, exclude: Array[RID] = []) -> Hit:
	if camera == null or not camera.is_inside_tree():
		return null
	var ray: Array = ray_in_cake_frame(screen_position)
	return pick_ray(ray[0], ray[1], exclude)


## Picks with a ray already in the cake frame (used by scatter brushes too).
func pick_ray(origin: Vector3, direction: Vector3, exclude: Array[RID] = []) -> Hit:
	var to_world: Transform3D = collision_root.global_transform
	var query := PhysicsRayQueryParameters3D.create(to_world * origin, to_world * (origin + direction * 60.0), LAYER_CAKE, exclude)
	query.hit_back_faces = true
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result["collider"]
	var hit := Hit.new()
	hit.tier_id = int(collider.get_meta("tier_id", 0))
	hit.kind = collider.get_meta("kind", &"tier")
	hit.item_id = int(collider.get_meta("item_id", 0))
	hit.cake_position = to_world.affine_inverse() * (result["position"] as Vector3)
	var normal: Vector3 = to_world.basis.inverse() * (result["normal"] as Vector3)
	# Shapes are double-sided; make the normal face the camera.
	if normal.dot(direction) > 0.0:
		normal = -normal
	hit.cake_normal = normal.normalized()
	hit.local_position = hit.cake_position - Vector3(0.0, model.tier_base_y(hit.tier_id), 0.0)
	hit.world_position = spin_root.global_transform * hit.cake_position
	hit.world_normal = (spin_root.global_transform.basis * hit.cake_normal).normalized()
	hit.ray_origin = origin
	hit.ray_direction = direction
	return hit


## Where the mouse ray meets the horizontal plane at height `y` (cake frame),
## or null if it points away from it.
func plane_point(screen_position: Vector2, y: float) -> Variant:
	var ray: Array = ray_in_cake_frame(screen_position)
	var origin: Vector3 = ray[0]
	var direction: Vector3 = ray[1]
	if absf(direction.y) < 0.0001:
		return null
	var t: float = (y - origin.y) / direction.y
	if t <= 0.0:
		return null
	return origin + direction * t


## Converts a point from the cake frame to world space.
func to_world(cake_point: Vector3) -> Vector3:
	return spin_root.global_transform * cake_point
