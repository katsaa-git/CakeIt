@tool
class_name SpikyFlowerStamp
extends StampShape
## A chrysanthemum tip: one squeeze sprays rows of slim, pointed, gently
## cupped petals out from the middle; the outer ones lie low and droop, the
## inner ones stand up round a small domed centre.
##
## Sizes are in tip radii.

@export_range(1, 6) var rows: int = 4
## Petals in the outer row (inner rows have fewer).
@export_range(4, 32) var petals: int = 16
## Length of an outer petal.
@export_range(0.5, 4.0) var length: float = 1.9
## Width of a petal at its widest.
@export_range(0.05, 1.0) var petal_width: float = 0.34
## How far the outer petals droop at their tips.
@export_range(0.0, 1.0) var droop: float = 0.3
## Angle of the outer row above the cake, and of the inner row, in degrees.
@export_range(0.0, 90.0) var outer_angle: float = 12.0
@export_range(0.0, 90.0) var inner_angle: float = 72.0
## The centre is tinted toward this colour by `center_tint_amount`.
@export var center_tint: Color = Color(0.98, 0.86, 0.5)
@export_range(0.0, 1.0) var center_tint_amount: float = 0.25

const RINGS: int = 5

var _petal: ProfileShape
var _dot: ProfileShape


func shows_alone() -> bool:
	return true


func emit(out: MeshArrays, context: StampContext) -> void:
	if _petal == null:
		# Cupped upward (a little channel down each petal).
		_petal = PetalFlowerStamp.cupped_profile(-0.35, 0.3, 8)
	var r: float = context.radius
	var side: Vector3 = context.side()
	var turn: float = context.rng.randf() * TAU
	for row in range(rows):
		var f: float = float(row) / float(maxi(rows - 1, 1))
		var count: int = maxi(int(round(float(petals) * lerpf(1.0, 0.5, f))), 3)
		var elevation: float = deg_to_rad(lerpf(outer_angle, inner_angle, f))
		var petal_length: float = length * r * lerpf(1.0, 0.45, f)
		var tone: Color = context.color.darkened(0.08 * f)
		var stripe: Color = context.stripe.darkened(0.08 * f) if context.stripe.a > 0.0 else context.stripe
		var colors: PackedColorArray = TubeBuilder.bag_colors(_petal, tone, stripe, 0.0)
		for i in range(count):
			var a: float = turn + TAU * (float(i) + 0.5 * float(row % 2)) / float(count) + context.rng.randf_range(-0.07, 0.07)
			var outward: Vector3 = context.forward * cos(a) + side * sin(a)
			var tilt: float = elevation + context.rng.randf_range(-0.08, 0.08)
			var along: Vector3 = outward * cos(tilt) + context.normal * sin(tilt)
			var sky: Vector3 = context.normal * cos(tilt) - outward * sin(tilt)
			var base: Vector3 = context.origin + outward * r * lerpf(0.35, 0.12, f) + context.normal * r * lerpf(0.15, 0.45, f)
			var sag: float = droop * (1.0 - f)
			var centers := PackedVector3Array()
			var ups := PackedVector3Array()
			var scales := PackedFloat32Array()
			for k in range(RINGS + 1):
				var t: float = float(k) / float(RINGS)
				centers.append(base + along * petal_length * t - context.normal * sag * petal_length * t * t)
				ups.append(sky)
				var shape: float = sin(minf(t / 0.35, 1.0) * PI * 0.5) if t < 0.35 else 1.0 - (t - 0.35) / 0.65 * 0.55
				scales.append(maxf(petal_width * r * 0.5 * lerpf(0.45, 1.0, shape) * (1.0 if t < 0.35 else shape), r * 0.01))
			TubeBuilder.sweep(out, _petal, colors, centers, ups, scales, PackedFloat32Array(), true, true)
	_add_center(out, context)


func _add_center(out: MeshArrays, context: StampContext) -> void:
	if _dot == null:
		_dot = ProfileShape.circle(12, 1.0)
	var r: float = context.radius * 0.38
	var tint: Color = context.color.lerp(center_tint, center_tint_amount)
	tint.a = context.color.a
	var colors: PackedColorArray = TubeBuilder.shaded_colors(_dot, tint, 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(9):
		var phi: float = -PI * 0.5 + PI * float(k) / 8.0
		centers.append(context.origin + context.normal * (context.radius * 0.5 + sin(phi) * r * 0.9))
		ups.append(context.forward)
		scales.append(maxf(cos(phi) * r, r * 0.02))
	TubeBuilder.sweep(out, _dot, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func collision_extent(context: StampContext) -> Array:
	var reach: float = context.radius * length * cos(deg_to_rad(outer_angle))
	return [0.0, reach, reach, context.radius * length * 0.6]
