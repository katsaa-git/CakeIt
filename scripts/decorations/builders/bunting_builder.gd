@tool
class_name BuntingBuilder
extends DecorationBuilder
## A cake bunting topper: two wooden sticks with a string swagged between
## them and little triangular flags hanging from it, alternating the picked
## colour with cream.

@export_range(0.2, 1.5) var width: float = 0.66
## How high the string's ends stand above the cake.
@export_range(0.1, 1.2) var height: float = 0.62
@export_range(3, 12) var flags: int = 7
@export var stick_color: Color = Color(0.8, 0.64, 0.45)
@export var cream: Color = Color(1.0, 0.97, 0.9)

const STICK_SINK: float = 0.0


func radius() -> float:
	return width * 0.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var wood := Color(stick_color.r, stick_color.g, stick_color.b, 0.0)
	var half: float = width * 0.5
	for x in [-half, half]:
		var stick: Dictionary = LatheMesh.rounded_cylinder_profile(0.008, height + 0.03, 0.004, 2)
		add_transformed(out, LatheMesh.build_arrays(stick["points"], stick["normals"], 8, Callable(), 0, wood), Transform3D(Basis.IDENTITY, Vector3(x, -STICK_SINK, 0.0)))
		add_sphere(out, Vector3(x, height + 0.035, 0.0), 0.014, wood, 5, 8)
	# The string sags in a gentle curve.
	var sag: float = height * 0.13
	var string := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in range(13):
		var t: float = float(k) / 12.0
		string.append(Vector3(lerpf(-half, half, t), height - sag * sin(t * PI), 0.0))
		radii.append(0.004)
	add_tube(out, string, radii, Color(cream.r * 0.9, cream.g * 0.88, cream.b * 0.84, 0.0), 5)
	# Flags hanging from the string, facing +Z, alternating colours.
	var flag_width: float = width / float(flags) * 0.82
	for k in range(flags):
		var t: float = (float(k) + 0.5) / float(flags)
		var top := Vector3(lerpf(-half, half, t), height - sag * sin(t * PI) - 0.004, 0.006)
		var outline := PackedVector2Array([Vector2(-flag_width * 0.5, 0.0), Vector2(flag_width * 0.5, 0.0), Vector2(0.0, -flag_width * 1.25)])
		var flag: MeshArrays = extrude(outline, 0.008, TINTABLE if k % 2 == 0 else Color(cream.r, cream.g, cream.b, 0.0), true)
		# A slight swing, as if a breeze caught them.
		var swing: float = sin(float(k) * 1.7) * 0.12
		var stand := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
		add_transformed(out, flag, Transform3D(Basis(Vector3.BACK, swing) * stand, top))
	return out
