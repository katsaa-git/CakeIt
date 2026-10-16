@tool
class_name CherryBuilder
extends DecorationBuilder
## A glossy cherry with a little dimple on top and a curved stem.

## Radius of the cherry, in game units.
@export_range(0.02, 0.2) var size: float = 0.066
@export var stem_color: Color = Color(0.46, 0.4, 0.2)


func build() -> MeshArrays:
	var s: float = size
	var points := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.55 * s, 0.1 * s), Vector2(0.92 * s, 0.55 * s), Vector2(1.0 * s, 0.95 * s),
		Vector2(0.86 * s, 1.42 * s), Vector2(0.48 * s, 1.68 * s), Vector2(0.18 * s, 1.6 * s), Vector2(0.0, 1.52 * s),
	])
	var profile: Dictionary = LatheMesh.smooth_profile(points)
	var out: MeshArrays = LatheMesh.build_arrays(profile["points"], profile["normals"], 24, Callable(), 0, TINTABLE)
	var stem := ProfileShape.circle(6)
	var color := Color(stem_color.r, stem_color.g, stem_color.b, 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		centers.append(Vector3(sin(t * 1.4) * s * 0.7, s * (1.5 + t * 2.1), 0.0))
		ups.append(Vector3.FORWARD)
		scales.append(s * lerpf(0.1, 0.065, t))
	TubeBuilder.sweep(out, stem, TubeBuilder.shaded_colors(stem, color, 0.0), centers, ups, scales, PackedFloat32Array(), true, true)
	return out


func radius() -> float:
	return size
