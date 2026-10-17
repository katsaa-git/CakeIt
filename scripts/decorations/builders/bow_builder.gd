@tool
class_name BowBuilder
extends DecorationBuilder
## A bow made from a flat ribbon: two plump loops gathered at a little knot,
## and two tails trailing down. Used for fondant bows and for the bow on a
## satin ribbon. The bow's front faces +Y and its top is +Z.

## Loop tip to loop tip, in game units (0.42 = 4.2 cm).
@export_range(0.1, 1.5) var span: float = 0.42
## Ribbon width, in game units.
@export_range(0.02, 0.4) var band: float = 0.1
## Ribbon thickness, in game units.
@export_range(0.003, 0.05) var thickness: float = 0.012
@export var tails: bool = true


func build() -> MeshArrays:
	return make(span, band, thickness, TINTABLE, tails)


func radius() -> float:
	return span * 0.5


## A flat band cross-section: x across the ribbon (-1..1), y its thickness
## as a fraction of the half-width, gently domed like satin.
static func band_profile(ratio: float, count: int = 14) -> ProfileShape:
	var loop := PackedVector2Array()
	for j in range(count):
		var a: float = TAU * float(j) / float(count)
		var c: float = cos(a)
		var s: float = sin(a)
		var x: float = signf(c) * pow(absf(c), 0.25)
		var y: float = signf(s) * pow(absf(s), 0.6) * ratio * (1.0 - 0.25 * x * x)
		loop.append(Vector2(x, y))
	return ProfileShape.from_points(TipProfile.counter_clockwise(loop))


static func make(bow_span: float, bow_band: float, bow_thickness: float, color: Color, with_tails: bool = true) -> MeshArrays:
	var out := MeshArrays.new()
	var profile: ProfileShape = band_profile(bow_thickness / (bow_band * 0.5))
	var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, color, 0.0)
	var half: float = bow_span * 0.5
	var puff: float = bow_span * 0.24
	for side in [-1.0, 1.0]:
		var centers := PackedVector3Array()
		var ups := PackedVector3Array()
		var scales := PackedFloat32Array()
		var steps: int = 30
		for i in range(steps + 1):
			var theta: float = TAU * float(i) / float(steps)
			var pinch: float = absf(sin(theta * 0.5))
			var out_x: float = half * 0.5 * (1.0 - cos(theta))
			var p := Vector3(side * out_x, puff * 0.5 + puff * 0.5 * sin(theta) * pinch + bow_thickness, bow_span * 0.09 * (1.0 - cos(theta)) * 0.5)
			centers.append(p)
			scales.append(bow_band * 0.5 * lerpf(0.45, 1.0, pinch))
		for i in range(centers.size()):
			var along: Vector3 = centers[mini(i + 1, centers.size() - 1)] - centers[maxi(i - 1, 0)]
			# The band lies flat round the loop: its thickness points away from the loop's middle.
			ups.append(Vector3(-along.y, along.x, 0.0).normalized() * -side if along.length_squared() > 1e-12 else Vector3.UP)
		TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), false, false)
	if with_tails:
		for side in [-1.0, 1.0]:
			var centers := PackedVector3Array()
			var ups := PackedVector3Array()
			var scales := PackedFloat32Array()
			var steps: int = 10
			for i in range(steps + 1):
				var t: float = float(i) / float(steps)
				centers.append(Vector3(side * (bow_span * 0.05 + bow_span * 0.28 * t + bow_span * 0.04 * sin(t * PI)), bow_thickness * (1.6 - 0.6 * t) + puff * 0.2 * (1.0 - t), -bow_span * 0.62 * t))
				ups.append(Vector3.UP)
				scales.append(bow_band * 0.5 * lerpf(0.55, 0.95, t))
			TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)
	# The knot where the loops are gathered.
	add_blob(out, Transform3D(Basis.IDENTITY, Vector3(0.0, puff * 0.5 + bow_thickness, 0.0)), 1.0, color, Vector3(bow_band * 0.36, puff * 0.62, bow_band * 0.55), 7, 12)
	return out
