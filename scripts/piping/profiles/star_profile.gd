@tool
class_name StarProfile
extends TipProfile
## A star tip: ridges around the outside. Open stars have soft shallow ridges;
## closed stars have more, deeper and tighter grooves. Also used for the
## lobed drop-flower shape.

@export_range(3, 16) var points: int = 8
## How deep the grooves cut in, as a fraction of the radius.
@export_range(0.0, 0.8) var depth: float = 0.25
## Above 1 makes the grooves narrow and the ridges broad and rounded.
@export_range(0.2, 4.0) var ridge_fullness: float = 1.0
## Below 1 the shape settles slightly flatter against the cake.
@export_range(0.5, 1.2) var squash: float = 0.95


func make_loop(count: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		# 1 on a ridge, 0 in a groove.
		var ridge: float = absf(cos(float(points) * 0.5 * a))
		ridge = 1.0 - pow(1.0 - ridge, ridge_fullness)
		var r: float = 1.0 - depth * (1.0 - ridge)
		loop.append(Vector2(cos(a) * r, sin(a) * r * squash))
	return loop
