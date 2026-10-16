@tool
class_name SprinkleBuilder
extends DecorationBuilder
## Tiny sprinkles: rods (jimmies), flat confetti discs or round nonpareils.

enum Shape { ROD, DISC, BALL }

@export var shape: Shape = Shape.ROD
## Rod length, disc or ball diameter, in game units (1 = 10 cm).
@export_range(0.005, 0.2) var length: float = 0.06
## Rod thickness or disc thickness, in game units.
@export_range(0.002, 0.05) var thickness: float = 0.016


func build() -> MeshArrays:
	var out := MeshArrays.new()
	match shape:
		Shape.ROD:
			var profile := ProfileShape.circle(6)
			var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, TINTABLE, 0.0)
			var centers := PackedVector3Array()
			var ups := PackedVector3Array()
			var scales := PackedFloat32Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				centers.append(Vector3((t - 0.5) * length, thickness * 0.45, 0.0))
				ups.append(Vector3.UP)
				scales.append(thickness * 0.5 * maxf(pow(sin(PI * t), 0.3), 0.15))
			TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)
		Shape.DISC:
			var r: float = length * 0.5
			var profile: Dictionary = LatheMesh.rounded_cylinder_profile(r, thickness, thickness * 0.45, 2)
			out = LatheMesh.build_arrays(profile["points"], profile["normals"], 14, Callable(), 0, TINTABLE)
		Shape.BALL:
			add_sphere(out, Vector3(0.0, length * 0.45, 0.0), length * 0.5, TINTABLE, 5, 8)
	return out


func radius() -> float:
	return length * 0.5
