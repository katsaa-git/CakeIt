@tool
class_name TipProfile
extends Resource
## Base class for a piping tip's cross-section. Subclasses describe a shape
## with a few friendly numbers; `build()` turns it into a ProfileShape.
## All sizes are in units of the tip radius.

## How many points go around the loop. More looks smoother but costs more.
@export_range(6, 96) var sides: int = 24


## Override: the closed loop of points, counter-clockwise.
func make_loop(count: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		loop.append(Vector2(cos(a), sin(a)))
	return loop


## Override for ruffled shapes: sideways offset per point (empty = none).
func make_wave(_loop: PackedVector2Array) -> PackedVector2Array:
	return PackedVector2Array()


func build() -> ProfileShape:
	var loop: PackedVector2Array = make_loop(sides)
	return ProfileShape.from_points(loop, make_wave(loop))
