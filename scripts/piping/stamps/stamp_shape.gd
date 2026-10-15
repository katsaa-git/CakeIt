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
