@tool
class_name StampShape
extends Resource
## Base class for tips that place repeated shapes (drop flowers, shells, grass
## tufts) instead of a continuous line. Subclasses add geometry to `out` for
## one stamp, using the frame and size in `context`.


## Override: add one stamp's geometry.
func emit(_out: MeshArrays, _context: StampContext) -> void:
	pass


## Should the stamp turn to follow the drag direction (shells), or not care (flowers)?
func follows_direction() -> bool:
	return false


## Override: rough size of one stamp for picking, in game units:
## [centre offset along forward, half-length along forward, half-width, height].
func collision_extent(context: StampContext) -> Array:
	return [0.0, context.radius, context.radius, context.radius]


## Adds a low eight-sided dome around one stamp (24 triangles), so you can
## pipe and decorate on top of stamps without every tiny triangle becoming
## a collision face.
func add_collision(faces: PackedVector3Array, context: StampContext) -> void:
	var extent: Array = collision_extent(context)
	var side: Vector3 = context.side()
	var centre: Vector3 = context.origin + context.forward * float(extent[0])
	var top: Vector3 = centre + context.normal * float(extent[3])
	var ring := PackedVector3Array()
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		ring.append(centre + context.forward * cos(a) * float(extent[1]) + side * sin(a) * float(extent[2]) - context.normal * context.radius * 0.1)
	var mid := PackedVector3Array()
	for k in range(8):
		mid.append(ring[k].lerp(top, 0.45) + context.normal * float(extent[3]) * 0.2)
	for k in range(8):
		var k1: int = (k + 1) % 8
		faces.append_array(PackedVector3Array([ring[k], mid[k], ring[k1], ring[k1], mid[k], mid[k1], mid[k], top, mid[k1]]))
