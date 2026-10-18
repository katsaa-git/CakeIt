@tool
class_name BerryBuilder
extends DecorationBuilder
## Fresh berries: a raspberry (a dome of little round drupelets), a
## blackberry (taller, with more and glossier drupelets) or a blueberry (a
## slightly flattened ball with a star-shaped crown).

enum Kind { RASPBERRY, BLUEBERRY, BLACKBERRY }

@export var kind: Kind = Kind.RASPBERRY
## Height of the berry, in game units.
@export_range(0.03, 0.4) var size: float = 0.17


func build() -> MeshArrays:
	var out := MeshArrays.new()
	if kind == Kind.BLUEBERRY:
		var r: float = size * 0.5
		add_sphere(out, Vector3(0.0, r * 0.85, 0.0), r, TINTABLE, 10, 16, Vector3(1.0, 0.85, 1.0))
		var crown := Color(0.45, 0.42, 0.5, 1.0)
		for k in range(5):
			var a: float = TAU * float(k) / 5.0
			add_sphere(out, Vector3(cos(a) * r * 0.2, r * 1.68, sin(a) * r * 0.2), r * 0.13, crown, 4, 6)
		return out
	var blackberry: bool = kind == Kind.BLACKBERRY
	var stretch: float = 1.22 if blackberry else 1.0
	var bead: float = 0.088 if blackberry else 0.095
	var rows: int = 8 if blackberry else 6
	var core := Color(0.72, 0.72, 0.72, 1.0)
	add_sphere(out, Vector3(0.0, size * 0.48 * stretch, 0.0), size * 0.42, core, 8, 12, Vector3(0.82, 1.1 * stretch, 0.82))
	for row in range(rows + 1):
		var t: float = float(row) / float(rows)
		var y: float = size * (0.1 + 0.82 * t) * stretch
		var ring: float = size * 0.4 * sin(PI * (0.2 + 0.75 * t)) + size * 0.02
		var count: int = maxi(int(TAU * ring / (size * bead * 1.4)), 1)
		for k in range(count):
			var a: float = TAU * (float(k) + 0.5 * float(row % 2)) / float(count)
			var shade: float = 0.92 + 0.08 * sin(float(k * 7 + row * 3))
			add_sphere(out, Vector3(cos(a) * ring, y, sin(a) * ring), size * bead, Color(shade, shade, shade, 1.0), 5, 7)
	return out


func radius() -> float:
	return size * 0.45
