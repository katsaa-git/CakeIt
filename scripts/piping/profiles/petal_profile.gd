@tool
class_name PetalProfile
extends TipProfile
## A petal tip: a teardrop-shaped opening held at a slant, thick and round at
## the end touching the cake, thin at the end that stands out. A ruffle is the
## same opening with `frill` above 0: its thin edge waves back and forth as
## the line goes along (the tip's wave_amplitude and wave_length).

## How steeply the petal stands up from the cake, in degrees.
@export_range(0.0, 85.0) var tilt_degrees: float = 55.0
## From the thick end to the thin end, in tip radii.
@export_range(0.8, 3.0) var length: float = 1.9
## Radius of the round thick end, in tip radii.
@export_range(0.1, 0.6) var thick_end: float = 0.3
## Radius of the thin end, in tip radii.
@export_range(0.01, 0.2) var thin_end: float = 0.035
## How much of the thin edge waves for ruffles (0 = a plain petal).
@export_range(0.0, 1.0) var frill: float = 0.0


func _axis() -> Array:
	var d := Vector2(cos(deg_to_rad(tilt_degrees)), sin(deg_to_rad(tilt_degrees)))
	# The ring's centre sits a third of the way up from the thick end.
	var a: Vector2 = -d * length * 0.32
	return [a, d]


func make_loop(count: int) -> PackedVector2Array:
	var axis: Array = _axis()
	var a: Vector2 = axis[0]
	var d: Vector2 = axis[1]
	var n := Vector2(-d.y, d.x)
	var b: Vector2 = a + d * length
	var side_count: int = maxi(int(count * 0.3), 3)
	var thin_cap: int = maxi(int(count * 0.12), 3)
	var thick_cap: int = maxi(count - side_count * 2 - thin_cap, 4)
	var loop := PackedVector2Array()
	# One side from the thick end to the thin end (slightly bellied)...
	for k in range(side_count):
		var s: float = float(k) / float(side_count)
		var w: float = lerpf(thick_end, thin_end, pow(s, 0.85))
		loop.append(a + d * length * s + n * w)
	# ...round the thin end...
	for k in range(thin_cap):
		var angle: float = PI * 0.5 - PI * float(k) / float(thin_cap)
		loop.append(b + (d * cos(angle) + n * sin(angle)) * thin_end)
	# ...back down the other side...
	for k in range(side_count):
		var s: float = 1.0 - float(k) / float(side_count)
		var w: float = lerpf(thick_end, thin_end, pow(s, 0.85))
		loop.append(a + d * length * s - n * w)
	# ...and round the thick end.
	for k in range(thick_cap):
		var angle: float = -PI * 0.5 - PI * float(k) / float(thick_cap)
		loop.append(a + (d * cos(angle) + n * sin(angle)) * thick_end)
	return counter_clockwise(loop)


func make_wave(loop: PackedVector2Array) -> PackedVector2Array:
	if frill <= 0.0:
		return PackedVector2Array()
	var axis: Array = _axis()
	var a: Vector2 = axis[0]
	var d: Vector2 = axis[1]
	var n := Vector2(-d.y, d.x)
	var out := PackedVector2Array()
	for p in loop:
		# The thick end stays put on the cake; the thin edge rises and dips
		# along the petal and leans across it a little: soft fabric folds.
		var s: float = clampf((p - a).dot(d) / length, 0.0, 1.0)
		var weight: float = smoothstep(0.3, 1.0, s) * frill
		out.append((d * 0.85 + n * 0.25) * weight)
	return out
