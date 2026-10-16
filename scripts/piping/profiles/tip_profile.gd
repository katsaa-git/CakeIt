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


## Returns the loop counter-clockwise (reversed if it was drawn the other way),
## which is what ProfileShape expects for outward normals.
static func counter_clockwise(loop: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	for j in range(loop.size()):
		var a: Vector2 = loop[j]
		var b: Vector2 = loop[(j + 1) % loop.size()]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return loop
	var reversed := PackedVector2Array()
	for j in range(loop.size() - 1, -1, -1):
		reversed.append(loop[j])
	return reversed
