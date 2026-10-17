@tool
class_name RosetteStamp
extends StampShape
## A big open-star swirl, like a 1M tip: the bag starts in the middle, circles
## outward a turn and a bit, and finishes with a soft tail tucked against the
## side. One squeeze is a rosette; dragging pipes a row of them.
##
## The swirl uses the tip's own profile (an open star with wide ridges).

## How many times the bag goes round.
@export_range(0.5, 3.0) var turns: float = 1.3
## Outer radius of the swirl's centre line, in tip radii.
@export_range(0.5, 4.0) var reach: float = 1.25
## How much higher the middle stands, in tip radii.
@export_range(0.0, 2.0) var crown: float = 0.5
## Turn of the ridges from start to end, in radians.
@export_range(0.0, 4.0) var twist: float = 1.4

const RINGS_PER_TURN: int = 34


func shows_alone() -> bool:
	return true


func emit(out: MeshArrays, context: StampContext) -> void:
	var r: float = context.radius
	var colors: PackedColorArray = context.colors_for(context.shape)
	var side: Vector3 = context.side()
	var start: float = context.rng.randf() * TAU
	var steps: int = maxi(int(turns * float(RINGS_PER_TURN)), 8)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var twists := PackedFloat32Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var theta: float = start + t * turns * TAU
		# Out from the middle to the full reach by 80%, then round at the edge
		# while the tail thins out.
		var grow: float = minf(t / 0.8, 1.0)
		var rho: float = r * lerpf(0.62, reach, pow(grow, 0.9))
		var height: float = r * (0.5 + crown * (1.0 - grow))
		var thickness: float = lerpf(0.55, 1.0, smoothstep(0.0, 0.3, t))
		if t > 0.78:
			thickness *= lerpf(1.0, 0.22, pow((t - 0.78) / 0.22, 1.2))
			height -= r * 0.25 * (t - 0.78) / 0.22
		var radial: Vector3 = context.forward * cos(theta) + side * sin(theta)
		centers.append(context.origin + radial * rho + context.normal * height)
		ups.append(context.normal)
		scales.append(maxf(r * thickness, r * 0.03))
		twists.append(t * twist)
	TubeBuilder.sweep(out, context.shape, colors, centers, ups, scales, twists, true, true)


func collision_extent(context: StampContext) -> Array:
	var size: float = context.radius * (reach + 1.0)
	return [0.0, size, size, context.radius * (1.4 + crown)]
