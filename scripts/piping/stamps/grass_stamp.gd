@tool
class_name GrassStamp
extends StampShape
## Grass tip: each squeeze pushes out a tuft of thin strands that taper to a
## point and flop over a little, leaning the way the bag moves. Strands come
## out of the opening in a sunflower spiral so the tuft looks full but never
## regular.

## Strands per tuft.
@export_range(3, 24) var strands: int = 11
## Strand length, in tip radii.
@export_range(0.5, 6.0) var length: float = 2.4
## Strand thickness at the root, in tip radii.
@export_range(0.04, 0.4) var thickness: float = 0.15
## How far strands splay outward from the middle of the tuft.
@export_range(0.0, 1.5) var splay: float = 0.55
## How much the tips flop over under their own weight.
@export_range(0.0, 1.5) var droop: float = 0.45
## How much the tuft leans toward the direction of the drag.
@export_range(0.0, 1.0) var lean: float = 0.3

const RINGS: int = 5

var _strand: ProfileShape


## Tufts lean the way the bag moves.
func follows_direction() -> bool:
	return true


func emit(out: MeshArrays, context: StampContext) -> void:
	if _strand == null:
		_strand = ProfileShape.circle(5)
	var rng: RandomNumberGenerator = context.rng
	var side: Vector3 = context.side()
	var r: float = context.radius
	for i in range(strands):
		var k: float = (float(i) + 0.5) / float(strands)
		var angle: float = float(i) * 2.39996 + rng.randf() * 0.4
		var outward: Vector3 = context.forward * cos(angle) + side * sin(angle)
		var base: Vector3 = context.origin + outward * sqrt(k) * r * 0.75 - context.normal * r * 0.12
		var jitter := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 0.15
		var direction: Vector3 = (context.normal + outward * splay * sqrt(k) + context.forward * lean + jitter).normalized()
		var flop: Vector3 = (outward * 0.6 + context.forward * lean - context.normal * 0.8).normalized()
		var strand_length: float = r * length * rng.randf_range(0.75, 1.15)
		var shade: float = rng.randf_range(0.0, 0.1)
		# A two-tone bag gives every other strand the second colour.
		var tone: Color = context.stripe if context.stripe.a > 0.0 and i % 2 == 1 else context.color
		tone = Color(tone.r, tone.g, tone.b, context.color.a).darkened(shade)
		var colors: PackedColorArray = TubeBuilder.shaded_colors(_strand, tone, 0.0)
		var centers := PackedVector3Array()
		var ups := PackedVector3Array()
		var scales := PackedFloat32Array()
		for ring in range(RINGS + 1):
			var t: float = float(ring) / float(RINGS)
			centers.append(base + direction * strand_length * t + flop * droop * strand_length * t * t * 0.5)
			ups.append(outward)
			scales.append(maxf(r * thickness * pow(1.0 - t, 0.8), r * 0.012))
		TubeBuilder.sweep(out, _strand, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func collision_extent(context: StampContext) -> Array:
	return [context.radius * lean * 0.5, context.radius * 1.2, context.radius * 1.2, context.radius * length * 0.6]
