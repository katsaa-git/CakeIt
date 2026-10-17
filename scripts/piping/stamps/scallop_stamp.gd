@tool
class_name ScallopStamp
extends StampShape
## A lace scallop border: each stamp is a smooth half-moon arc laid on the
## cake, meeting the next one point to point, with a little lace motif (a
## few dots inside and a teardrop below). Along the side the scallops hang
## down; on top they bow out toward the edge.
##
## The width of one scallop is the tip's stamp spacing, so they always join.

## How deep the arc dips, as a fraction of its width.
@export_range(0.1, 1.0) var depth: float = 0.42
## Thickness of the lace line, as a fraction of the tip radius.
@export_range(0.1, 1.0) var line: float = 0.42
## Dots inside each scallop.
@export_range(0, 5) var dots: int = 3
## A teardrop hanging below the middle of each scallop.
@export var drop: bool = true

const RINGS: int = 18

var _round: ProfileShape


func follows_direction() -> bool:
	return true


func emit(out: MeshArrays, context: StampContext) -> void:
	if _round == null:
		_round = ProfileShape.circle(10, 0.9)
	var r: float = context.radius
	var w: float = context.spacing
	var bulge: Vector3 = _bulge(context)
	var lift: Vector3 = context.normal * r * line * 0.55
	var colors: PackedColorArray = context.colors_for(_round)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(RINGS + 1):
		var angle: float = PI * float(k) / float(RINGS)
		centers.append(context.origin - context.forward * cos(angle) * w * 0.5 + bulge * sin(angle) * w * depth + lift)
		ups.append(context.normal)
		scales.append(r * line * lerpf(0.55, 1.0, pow(sin(angle), 0.6)))
	TubeBuilder.sweep(out, _round, colors, centers, ups, scales, PackedFloat32Array(), true, true)
	# Lace dots in a little fan inside the arc.
	for i in range(dots):
		var f: float = 0.5 if dots == 1 else float(i) / float(dots - 1)
		var angle: float = lerpf(0.32, 0.68, f) * PI
		var reach: float = lerpf(0.5, 0.62, 1.0 - absf(f - 0.5) * 2.0)
		var spot: Vector3 = context.origin - context.forward * cos(angle) * w * 0.5 * reach + bulge * sin(angle) * w * depth * reach
		_add_dot(out, context, spot, r * line * (0.8 if i == dots / 2 else 0.62))
	if drop:
		_add_drop(out, context, context.origin + bulge * (w * depth + r * line * 3.2), bulge)


## Which way the scallop bows: down on the side of a tier, out toward the
## edge on top.
func _bulge(context: StampContext) -> Vector3:
	var top: float = smoothstep(0.35, 0.85, context.normal.y)
	var radial := Vector3(context.origin.x, 0.0, context.origin.z)
	radial = radial.normalized() if radial.length_squared() > 1e-8 else Vector3.ZERO
	var want: Vector3 = radial * top + Vector3.DOWN * (1.0 - top)
	var side: Vector3 = context.side()
	return side if side.dot(want) >= 0.0 else -side


func _add_dot(out: MeshArrays, context: StampContext, spot: Vector3, size: float) -> void:
	var colors: PackedColorArray = context.colors_for(_round)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(7):
		var phi: float = -PI * 0.5 + PI * float(k) / 6.0
		centers.append(spot + context.normal * (size * 0.35 + sin(phi) * size * 0.8))
		ups.append(context.forward)
		scales.append(maxf(cos(phi) * size, size * 0.03))
	TubeBuilder.sweep(out, _round, colors, centers, ups, scales, PackedFloat32Array(), true, true)


## A small teardrop: round at the bottom, drawn up to a point toward the arc.
func _add_drop(out: MeshArrays, context: StampContext, spot: Vector3, down: Vector3) -> void:
	var size: float = context.radius * line * 1.05
	var colors: PackedColorArray = context.colors_for(_round)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(9):
		var t: float = float(k) / 8.0
		centers.append(spot - down * size * 2.2 * t + context.normal * size * 0.5)
		ups.append(context.normal)
		var s: float = sin(minf(t / 0.3, 1.0) * PI * 0.5) if t < 0.3 else pow(1.0 - (t - 0.3) / 0.7, 1.1)
		scales.append(maxf(size * s, size * 0.03))
	TubeBuilder.sweep(out, _round, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func collision_extent(context: StampContext) -> Array:
	var w: float = context.spacing
	return [0.0, w * 0.5, w * depth + context.radius, context.radius * line * 1.4]
