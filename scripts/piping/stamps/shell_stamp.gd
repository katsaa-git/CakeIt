@tool
class_name ShellStamp
extends StampShape
## Shell: a fat, rounded head that tails off to a point in the direction the
## bag moves, with the star ridges fanning over it. Shells piped in a row
## overlap head-over-tail into the classic shell border.

## Head to tail, in tip radii.
@export_range(1.0, 5.0) var length: float = 2.7
## How high the head stands, relative to its width.
@export_range(0.2, 1.5) var height: float = 0.7
## Where along the shell the head is widest (0..1).
@export_range(0.1, 0.6) var head_at: float = 0.28
## A slight turn of the ridges from head to tail, in radians.
@export_range(0.0, 1.5) var twist: float = 0.3

const RINGS: int = 16


func follows_direction() -> bool:
	return true


func emit(out: MeshArrays, context: StampContext) -> void:
	var r: float = context.radius
	var colors: PackedColorArray = TubeBuilder.shaded_colors(context.shape, context.color)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var twists := PackedFloat32Array()
	var total: float = length * r
	for ring in range(RINGS + 1):
		var t: float = float(ring) / float(RINGS)
		var s: float
		if t < head_at:
			s = pow(sin(t / head_at * PI * 0.5), 0.7)
		else:
			s = pow(1.0 - (t - head_at) / (1.0 - head_at), 1.9)
		var scale: float = maxf(s * r * 1.05, r * 0.03)
		# The centre line stays level through the head (a steep rise would fold
		# the rings into each other) and only sinks along the tail.
		var lift: float = r * 1.05 * height * (1.0 if t < head_at else s)
		centers.append(context.origin + context.forward * (t - head_at * 0.8) * total + context.normal * lift * 0.55)
		ups.append(context.normal)
		scales.append(scale)
		twists.append(t * twist)
	TubeBuilder.sweep(out, context.shape, colors, centers, ups, scales, twists, true, true)


func collision_extent(context: StampContext) -> Array:
	var total: float = length * context.radius
	return [total * (0.5 - head_at * 0.8), total * 0.5, context.radius, context.radius * (height + 0.5)]
