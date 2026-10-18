@tool
class_name CombProfile
extends TipProfile
## A true basketweave tip: a wide, flat slot with one smooth side and one
## serrated, toothed side, like a little comb. Piped, it leaves a flat band
## with crisp parallel ridges and sharp V-grooves along its top, and its
## edges come out notched. Short bars side by side make a woven basket.

## Teeth across the serrated side.
@export_range(3, 16) var teeth: int = 9
## Band thickness, as a fraction of its half-width.
@export_range(0.1, 0.8) var thickness: float = 0.3
## Groove depth between the teeth, as a fraction of the half-width.
@export_range(0.0, 0.3) var tooth_depth: float = 0.09
## How much of each tooth is a flat crest (0 = sharp peaks).
@export_range(0.0, 0.8) var crest: float = 0.3


func make_loop(count: int) -> PackedVector2Array:
	var bottom: float = -thickness * 0.35
	var top: float = thickness * 0.65
	var corner: float = thickness * 0.25
	var loop := PackedVector2Array()
	# The smooth underside, right to left, with softly rounded corners.
	for k in range(4):
		var a: float = PI * 0.5 * float(k) / 3.0
		loop.append(Vector2(1.0 - corner + sin(a) * corner, bottom + corner - cos(a) * corner))
	loop.reverse()
	var under := PackedVector2Array()
	for k in range(4):
		var a: float = PI * 0.5 * float(k) / 3.0
		under.append(Vector2(-1.0 + corner - sin(a) * corner, bottom + corner - cos(a) * corner))
	var outline := PackedVector2Array()
	outline.append_array(loop)
	for k in range(under.size()):
		outline.append(under[k])
	# Up the left side to the first groove.
	outline.append(Vector2(-1.0, top - tooth_depth - corner * 0.3))
	# The teeth, left to right: groove, up the flank, flat crest, down.
	var width: float = 2.0 / float(teeth)
	var per_tooth: int = maxi(count / teeth, 4)
	for t in range(teeth):
		var x0: float = -1.0 + width * float(t)
		var rise: float = width * (1.0 - crest) * 0.5
		var points: Array = [
			Vector2(x0 + width * 0.04, top - tooth_depth),
			Vector2(x0 + rise, top),
			Vector2(x0 + width - rise, top),
		]
		if per_tooth > 4:
			points.insert(2, Vector2(x0 + width * 0.5, top + tooth_depth * 0.06))
		for p: Vector2 in points:
			outline.append(p)
	outline.append(Vector2(1.0 - width * 0.04, top - tooth_depth))
	outline.append(Vector2(1.0, top - tooth_depth - corner * 0.3))
	return counter_clockwise(outline)
