@tool
class_name CurlBuilder
extends DecorationBuilder
## A chocolate curl: a thin sheet of chocolate rolled up into a loose
## spiral, lying on its side.

## Length of the roll, in game units.
@export_range(0.03, 0.5) var length: float = 0.14
@export_range(0.5, 3.0) var turns: float = 1.6
@export_range(0.002, 0.03) var start_radius: float = 0.007
## How fast the spiral opens up per turn, in game units.
@export_range(0.002, 0.05) var growth: float = 0.014


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var loop := PackedVector2Array()
	for j in range(16):
		var a: float = TAU * float(j) / 16.0
		var c: float = cos(a)
		var s: float = sin(a)
		loop.append(Vector2(signf(c) * pow(absf(c), 0.3), signf(s) * pow(absf(s), 0.3) * 0.06))
	var profile := ProfileShape.from_points(TipProfile.counter_clockwise(loop))
	var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, TINTABLE, 0.0)
	var outer: float = start_radius + growth * turns
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var steps: int = int(turns * 20.0)
	for i in range(steps + 1):
		var theta: float = TAU * turns * float(i) / float(steps)
		var r: float = start_radius + growth * theta / TAU
		var radial := Vector3(cos(theta), sin(theta), 0.0)
		centers.append(radial * r + Vector3(0.0, outer, 0.0))
		ups.append(radial)
		scales.append(length * 0.5)
	TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)
	return out


func radius() -> float:
	return length * 0.5
