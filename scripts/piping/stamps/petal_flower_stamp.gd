@tool
class_name PetalFlowerStamp
extends StampShape
## A Russian-style flower tip: the opening is a ring of curved petal slits,
## so one squeeze pushes out a whole flower at once: rows of cupped petals
## round a little bud. With a few tall, upright, pointed petals the same
## shape is a tulip.
##
## Rows are listed outermost first. All sizes are in tip radii.

## Petals in each row.
@export var row_petals: PackedInt32Array = PackedInt32Array([8, 6, 5])
## Distance of each row's petal bases from the middle.
@export var row_radius: PackedFloat32Array = PackedFloat32Array([0.95, 0.62, 0.3])
## Petal height in each row.
@export var row_height: PackedFloat32Array = PackedFloat32Array([1.0, 1.2, 1.25])
## How far each row leans outward, in degrees (0 = straight up).
@export var row_lean: PackedFloat32Array = PackedFloat32Array([65.0, 38.0, 14.0])
## Petal width in each row.
@export var row_width: PackedFloat32Array = PackedFloat32Array([1.05, 0.9, 0.72])
## 0 = round petal tips, 1 = pointed like a tulip.
@export_range(0.0, 1.0) var pointed: float = 0.0
## How much each petal cups round the middle.
@export_range(0.0, 1.0) var cup: float = 0.5
## How far the petal tips curl in toward the middle (negative curls out).
@export_range(-1.0, 1.0) var curl: float = 0.1
## A round bud in the middle, and its size.
@export var bud: bool = true
@export_range(0.1, 1.0) var bud_size: float = 0.34
## Petal thickness, as a fraction of the petal width.
@export_range(0.05, 0.6) var thickness: float = 0.28
## Inner rows a little deeper in colour, like real petals in shadow.
@export_range(0.0, 0.4) var inner_shade: float = 0.1

const RINGS: int = 7

var _petal: ProfileShape
var _dot: ProfileShape


func shows_alone() -> bool:
	return true


## A curved, cupped petal cross-section: a thin crescent across x (-1..1),
## its edges bent toward -y by `amount` (negative bends them toward +y).
static func cupped_profile(amount: float, thickness: float, count: int = 14) -> ProfileShape:
	var half: int = count / 2
	var loop := PackedVector2Array()
	for k in range(half + 1):
		var s: float = -1.0 + 2.0 * float(k) / float(half)
		var c := Vector2(s, -amount * 0.6 * s * s)
		var n := Vector2(amount * 1.2 * s, 1.0).normalized()
		loop.append(c + n * thickness * 0.5 * (1.0 - 0.7 * pow(absf(s), 6.0)))
	for k in range(half - 1, 0, -1):
		var s: float = -1.0 + 2.0 * float(k) / float(half)
		var c := Vector2(s, -amount * 0.6 * s * s)
		var n := Vector2(amount * 1.2 * s, 1.0).normalized()
		loop.append(c - n * thickness * 0.5 * (1.0 - 0.7 * pow(absf(s), 6.0)))
	return ProfileShape.from_points(TipProfile.counter_clockwise(loop))


func emit(out: MeshArrays, context: StampContext) -> void:
	if _petal == null:
		_petal = cupped_profile(cup, thickness, 12)
	var side: Vector3 = context.side()
	var turn: float = context.rng.randf() * TAU
	var rows: int = mini(row_petals.size(), mini(row_radius.size(), mini(row_height.size(), mini(row_lean.size(), row_width.size()))))
	for row in range(rows):
		var count: int = maxi(row_petals[row], 1)
		var shade: float = inner_shade * float(row) / float(maxi(rows - 1, 1))
		var tone: Color = context.color.darkened(shade)
		var stripe: Color = context.stripe.darkened(shade) if context.stripe.a > 0.0 else context.stripe
		var colors: PackedColorArray = TubeBuilder.shaded_colors(_petal, tone, 0.0)
		for i in range(count):
			var a: float = turn + TAU * (float(i) + 0.5 * float(row % 2)) / float(count) + context.rng.randf_range(-0.08, 0.08)
			var outward: Vector3 = context.forward * cos(a) + side * sin(a)
			_add_petal(out, context, outward, row, colors, stripe)
	if bud:
		_add_bud(out, context)


func _add_petal(out: MeshArrays, context: StampContext, outward: Vector3, row: int, colors: PackedColorArray, stripe: Color) -> void:
	var r: float = context.radius
	var lean: float = deg_to_rad(row_lean[row])
	var height: float = row_height[row] * r * context.rng.randf_range(0.92, 1.06)
	var width: float = row_width[row] * r
	# The petal rises along `up_dir`; `face` is the side looking away from the middle.
	var up_dir: Vector3 = context.normal * cos(lean) + outward * sin(lean)
	var face: Vector3 = outward * cos(lean) - context.normal * sin(lean)
	var base: Vector3 = context.origin + outward * row_radius[row] * r - context.normal * r * 0.08
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(RINGS + 1):
		var t: float = float(k) / float(RINGS)
		var shape: float
		if t < 0.6:
			shape = lerpf(0.35, 1.0, sin(t / 0.6 * PI * 0.5))
		else:
			var u: float = (t - 0.6) / 0.4
			var round_top: float = sqrt(maxf(1.0 - u * u, 0.0))
			shape = lerpf(round_top, 1.0 - u, pointed)
		var p: Vector3 = base + up_dir * height * t - face * curl * r * t * t
		centers.append(p)
		ups.append((face + up_dir * curl * t * 0.6).normalized())
		scales.append(maxf(width * 0.5 * shape, r * 0.012))
	var first: int = out.vertex_count()
	TubeBuilder.sweep(out, _petal, colors, centers, ups, scales, PackedFloat32Array(), true, true)
	if stripe.a > 0.0:
		# A two-tone bag: each petal blushes into the second colour toward its edge.
		for v in range(first, out.vertex_count()):
			var along: float = clampf((out.verts[v] - base).dot(up_dir) / height, 0.0, 1.0)
			var c: Color = out.colors[v]
			out.colors[v] = Color(c.lerp(stripe, smoothstep(0.35, 0.95, along)), c.a)


func _add_bud(out: MeshArrays, context: StampContext) -> void:
	if _dot == null:
		_dot = ProfileShape.circle(12, 1.0)
	var r: float = context.radius * bud_size
	var lift: float = context.radius * 0.55
	var colors: PackedColorArray = TubeBuilder.shaded_colors(_dot, context.color.darkened(inner_shade * 1.3), 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(9):
		var phi: float = -PI * 0.5 + PI * float(k) / 8.0
		centers.append(context.origin + context.normal * (lift + sin(phi) * r * 1.2))
		ups.append(context.forward)
		scales.append(maxf(cos(phi) * r, r * 0.02))
	TubeBuilder.sweep(out, _dot, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func collision_extent(context: StampContext) -> Array:
	var reach: float = 0.0
	var top: float = 0.0
	for row in range(mini(row_radius.size(), mini(row_height.size(), row_lean.size()))):
		var lean: float = deg_to_rad(row_lean[row])
		reach = maxf(reach, row_radius[row] + row_height[row] * sin(lean))
		top = maxf(top, row_height[row] * cos(lean))
	return [0.0, context.radius * reach, context.radius * reach, context.radius * top]
