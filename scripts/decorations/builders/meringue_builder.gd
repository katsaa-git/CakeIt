@tool
class_name MeringueBuilder
extends DecorationBuilder
## A meringue kiss: crisp ridged meringue piped into a swirled cone with a
## curled peak, its ridges a shade lighter than its grooves, and a faint
## toasted blush at the base.

## Width at the base, in game units (0.26 = 2.6 cm).
@export_range(0.05, 0.6) var size: float = 0.26
@export_range(0.5, 2.0) var height: float = 1.15
@export_range(4, 12) var ridges: int = 8

const RINGS: int = 16


func radius() -> float:
	return size * 0.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var star := StarProfile.new()
	star.points = ridges
	star.depth = 0.28
	star.ridge_fullness = 1.4
	star.squash = 1.0
	star.sides = ridges * 6
	var shape: ProfileShape = star.build()
	var colors: PackedColorArray = TubeBuilder.shaded_colors(shape, TINTABLE, 0.3)
	var r: float = size * 0.5
	var top: float = size * height
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var twists := PackedFloat32Array()
	for k in range(RINGS + 1):
		var t: float = float(k) / float(RINGS)
		# Full at the bottom, drawn up into a peak that flops over a little.
		var s: float = r * (cos(t * PI * 0.5) * (1.0 - 0.15 * t)) if t < 0.92 else r * 0.06
		centers.append(Vector3(sin(t * PI * 0.5) * t * r * 0.35, t * top, 0.0))
		ups.append(Vector3.BACK)
		scales.append(maxf(s, r * 0.03))
		twists.append(t * 1.6)
	var start: int = out.vertex_count()
	TubeBuilder.sweep(out, shape, colors, centers, ups, scales, twists, true, true)
	# A faint golden blush where it sat in the oven, near the base.
	for i in range(start, out.vertex_count()):
		var lift: float = out.verts[i].y / top
		var c: Color = out.colors[i]
		var warm: float = (1.0 - smoothstep(0.0, 0.25, lift)) * 0.08
		out.colors[i] = Color(c.r, c.g * (1.0 - warm * 0.4), c.b * (1.0 - warm), c.a)
	return out
