@tool
class_name RibbonProfile
extends TipProfile
## Basketweave / ribbon tip: a flat band, smooth underneath with fine ridges
## on top. Short bars side by side make a woven basket; long lines make
## ribbons and bows.

## Band thickness, as a fraction of its half-width.
@export_range(0.1, 0.6) var thickness: float = 0.26
## Number of ridges across the top.
@export_range(0, 8) var ridges: int = 4
## Ridge depth, as a fraction of the half-width.
@export_range(0.0, 0.2) var ridge_depth: float = 0.05
## Roundness of the band's corners (higher is squarer).
@export_range(2.0, 12.0) var squareness: float = 6.0


func make_loop(count: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	var e: float = 2.0 / squareness
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		var c: float = cos(a)
		var s: float = sin(a)
		# A rounded rectangle (superellipse), sitting mostly above the centre line.
		var x: float = signf(c) * pow(absf(c), e)
		var y: float = signf(s) * pow(absf(s), e) * thickness * 0.5 + thickness * 0.15
		if s > 0.0 and ridges > 0:
			var ridge: float = 0.5 - 0.5 * cos(x * PI * float(ridges))
			y -= ridge_depth * ridge * smoothstep(0.0, 0.6, s)
		loop.append(Vector2(x, y))
	return counter_clockwise(loop)
