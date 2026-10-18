@tool
class_name MacaronBuilder
extends DecorationBuilder
## A French macaron lying on its side... or rather on its back: two smooth
## domed shells in the picked colour, each with a ruffled "foot", sandwiching
## a layer of cream filling.

## Width of the macaron, in game units (0.34 = 3.4 cm).
@export_range(0.1, 0.8) var size: float = 0.34
@export var filling: Color = Color(1.0, 0.95, 0.86)


func radius() -> float:
	return size * 0.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var r: float = size * 0.5
	var shell: float = size * 0.2
	var foot: float = size * 0.06
	var cream: float = size * 0.11
	# Bottom shell, dome down, then its foot, the filling, the top foot and
	# the top shell, dome up.
	var dome := PackedVector2Array()
	for k in range(9):
		var a: float = PI * 0.5 * float(k) / 8.0
		dome.append(Vector2(sin(a) * r, (1.0 - cos(a)) * shell * 0.9))
	var bottom_dome := PackedVector2Array([Vector2(0.0, 0.0)])
	for k in range(1, dome.size()):
		bottom_dome.append(Vector2(dome[k].x, dome[k].y))
	add_lathe(out, bottom_dome, TINTABLE, 32)
	var base: float = shell * 0.9
	_foot(out, r, base, foot)
	var fill := PackedVector2Array([Vector2(r * 0.86, base + foot * 0.9), Vector2(r * 0.9, base + foot + cream * 0.5), Vector2(r * 0.86, base + foot + cream * 1.1)])
	add_lathe(out, fill, Color(filling.r, filling.g, filling.b, 0.0), 32)
	var top_base: float = base + foot + cream
	_foot(out, r, top_base, foot)
	var top := PackedVector2Array()
	for k in range(9):
		var a: float = PI * 0.5 * float(k) / 8.0
		top.append(Vector2(cos(a) * r, top_base + foot + sin(a) * shell))
	add_lathe(out, top, TINTABLE, 32)
	return out


## The frilly foot round a shell's rim: a band whose edge ripples.
func _foot(out: MeshArrays, r: float, y: float, height: float) -> void:
	var points := PackedVector2Array([Vector2(r * 0.97, y), Vector2(r * 1.02, y + height * 0.5), Vector2(r * 0.98, y + height)])
	var profile: Dictionary = LatheMesh.smooth_profile(points)
	var ripple := func(a: float) -> float: return 1.0 + 0.025 * sin(a * 37.0) * sin(a * 11.0 + 1.3)
	var piece: MeshArrays = LatheMesh.build_arrays(profile["points"], profile["normals"], 72, ripple, 0, Color(0.93, 0.93, 0.93, 1.0))
	out.append(piece)
