@tool
class_name SprinkleBuilder
extends DecorationBuilder
## Tiny sprinkles: rods (jimmies), flat confetti discs, round nonpareils,
## jewel-like pomegranate seeds (GEM) or faceted sugar crystals (CRYSTAL).

enum Shape { ROD, DISC, BALL, GEM, CRYSTAL }

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
		Shape.GEM:
			# A plump, slightly faceted kernel, a bit pointed at one end.
			add_sphere(out, Vector3(0.0, thickness * 0.5, 0.0), 1.0, TINTABLE, 4, 7, Vector3(thickness * 0.5, thickness * 0.5, length * 0.5))
		Shape.CRYSTAL:
			_crystal(out)
		Shape.BALL:
			add_sphere(out, Vector3(0.0, length * 0.45, 0.0), length * 0.5, TINTABLE, 5, 8)
	return out


func radius() -> float:
	return length * 0.5


## A sugar crystal: a little cube with flat, sharp faces that glint.
func _crystal(out: MeshArrays) -> void:
	var h: float = length * 0.5
	var faces: Array = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for n: Vector3 in faces:
		var u: Vector3 = TubeBuilder.any_perpendicular(n)
		var v: Vector3 = n.cross(u)
		var start: int = out.vertex_count()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			out.add_vertex((n + u * corner.x + v * corner.y) * h + Vector3(0.0, h * 0.8, 0.0), n, TINTABLE, corner)
		out.add_triangle(start, start + 2, start + 1)
		out.add_triangle(start, start + 3, start + 2)
