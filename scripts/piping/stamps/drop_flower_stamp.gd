@tool
class_name DropFlowerStamp
extends StampShape
## Drop flower: the lobed opening is squeezed straight down while the bag
## turns a little, so the petals swirl as they rise; a small dot of a softer,
## sunnier shade finishes the middle.
##
## The petals use the tip's own profile (a star with few, round lobes).

## Height of the flower, in tip radii.
@export_range(0.3, 2.0) var height: float = 0.85
## How far the petals spread at their widest, relative to the opening.
@export_range(0.8, 2.0) var spread: float = 1.25
## Swirl from bottom to top, in radians.
@export_range(0.0, 3.0) var twist: float = 0.8
@export var center_dot: bool = true
## The middle is tinted toward this colour...
@export var center_tint: Color = Color(1.0, 0.86, 0.45)
## ...by this much (0 = same colour as the petals).
@export_range(0.0, 1.0) var center_tint_amount: float = 0.6

const RINGS: int = 10

var _dot: ProfileShape


func emit(out: MeshArrays, context: StampContext) -> void:
	var r: float = context.radius
	var colors: PackedColorArray = TubeBuilder.shaded_colors(context.shape, context.color)
	var turn: float = context.rng.randf() * TAU
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var twists := PackedFloat32Array()
	var reference: Vector3 = context.forward
	var top: float = height * r
	for ring in range(RINGS + 1):
		var t: float = float(ring) / float(RINGS)
		# Petals flare out from the base, are widest a little above the middle,
		# then curl in toward the centre.
		var s: float = lerpf(0.8, spread, sin(minf(t / 0.6, 1.0) * PI * 0.5))
		if t > 0.6:
			s = lerpf(spread, 0.3, pow((t - 0.6) / 0.4, 1.3))
		centers.append(context.origin + context.normal * (top * t - r * 0.15))
		ups.append(reference)
		scales.append(s * r)
		twists.append(turn + t * twist)
	TubeBuilder.sweep(out, context.shape, colors, centers, ups, scales, twists, true, true)
	if center_dot:
		_emit_center(out, context, top)


func _emit_center(out: MeshArrays, context: StampContext, top: float) -> void:
	if _dot == null:
		_dot = ProfileShape.circle(12, 1.0)
	var r: float = context.radius * 0.32
	var tint: Color = context.color.lerp(center_tint, center_tint_amount)
	var colors: PackedColorArray = TubeBuilder.shaded_colors(_dot, tint, 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for ring in range(7):
		var phi: float = PI * 0.5 * float(ring) / 6.0
		centers.append(context.origin + context.normal * (top - r * 0.6 + sin(phi) * r))
		ups.append(context.forward)
		scales.append(maxf(cos(phi) * r, r * 0.02))
	TubeBuilder.sweep(out, _dot, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func collision_extent(context: StampContext) -> Array:
	var reach: float = context.radius * spread
	return [0.0, reach, reach, context.radius * height]
