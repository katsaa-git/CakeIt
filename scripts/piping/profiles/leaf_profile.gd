@tool
class_name LeafProfile
extends TipProfile
## A leaf tip: a wide, flat opening with pointed sides and a V-notch on top,
## so a piped leaf gets crisp edges and a vein down the middle.

## Thickness at the middle, as a fraction of the half-width.
@export_range(0.2, 1.0) var thickness: float = 0.42
## Depth of the centre vein, as a fraction of the thickness.
@export_range(0.0, 0.8) var vein_depth: float = 0.4
## Width of the vein, as a fraction of the half-width.
@export_range(0.02, 0.4) var vein_width: float = 0.13


func make_loop(count: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		var x: float = cos(a)
		# Pointed sides: the body thins to an edge at x = +-1.
		var body: float = pow(maxf(1.0 - x * x, 0.0), 0.65)
		var y: float
		if sin(a) >= 0.0:
			y = thickness * body * (1.0 - vein_depth * exp(-pow(x / vein_width, 2.0)))
		else:
			y = -thickness * 0.55 * body
		loop.append(Vector2(x, y))
	return counter_clockwise(loop)
