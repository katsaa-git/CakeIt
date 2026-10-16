@tool
class_name PearlBuilder
extends DecorationBuilder
## A round sweet: sugar pearls, metallic dragées, blueberries' little cousins.

## Radius in game units (0.03 = a 6 mm pearl).
@export_range(0.005, 0.2) var size: float = 0.03
## Below 1 the ball sits a little flatter.
@export_range(0.5, 1.0) var squash: float = 1.0


func build() -> MeshArrays:
	var out := MeshArrays.new()
	add_sphere(out, Vector3(0.0, size * squash, 0.0), size, TINTABLE, 10, 16, Vector3(1.0, squash, 1.0))
	return out


func radius() -> float:
	return size
