@tool
class_name CutoutBuilder
extends DecorationBuilder
## A fondant cut-out: a soft-edged heart, star or blossom pressed flat onto
## the cake.

enum Shape { HEART, STAR, BLOSSOM }

@export var shape: Shape = Shape.HEART
## Half the width, in game units.
@export_range(0.03, 0.4) var size: float = 0.11
@export_range(0.005, 0.06) var thickness: float = 0.022


func build() -> MeshArrays:
	return extrude(outline(), thickness, TINTABLE)


## The shape's outline (x across, y = top), counter-clockwise like a lathe.
func outline() -> PackedVector2Array:
	var loop := PackedVector2Array()
	var count: int = 72
	for k in range(count):
		var a: float = TAU * float(k) / float(count)
		var p: Vector2
		match shape:
			Shape.HEART:
				# The classic heart curve, centred and scaled to fit.
				var t: float = -a
				p = Vector2(16.0 * pow(sin(t), 3.0), 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) / 17.0
				p.y += 0.12
			Shape.STAR:
				var r: float = 0.52 + 0.48 * pow(0.5 + 0.5 * cos(5.0 * (a - PI * 0.5)), 1.6)
				p = Vector2(cos(a), sin(a)) * r
			Shape.BLOSSOM:
				var r: float = 0.6 + 0.4 * pow(absf(cos(2.5 * (a - PI * 0.5))), 0.55)
				p = Vector2(cos(a), sin(a)) * r
		loop.append(p * size)
	return loop


func radius() -> float:
	return size
