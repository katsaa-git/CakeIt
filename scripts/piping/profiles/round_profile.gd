@tool
class_name RoundProfile
extends TipProfile
## A plain round tip: lines, dots and pearls.

## Below 1 the bead settles a little flatter, like soft buttercream does.
@export_range(0.5, 1.2) var squash: float = 0.9


func make_loop(count: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		loop.append(Vector2(cos(a), sin(a) * squash))
	return loop
