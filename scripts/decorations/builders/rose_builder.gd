@tool
class_name RoseBuilder
extends DecorationBuilder
## Layered sugar flowers made of rings of thin, cupped petals: a rose (a
## tight bud wrapped by petals that open out and roll back), a peony (many
## broad, ruffled petals round a golden heart) or a tulip (a few tall,
## pointed petals). Petals are thin sheets with two sides.
##
## Rings go from the middle out. Sizes are in units of `size`.

## Overall radius of the open flower, in game units.
@export_range(0.03, 0.4) var size: float = 0.15
## Petals in each ring.
@export var ring_petals: PackedInt32Array = PackedInt32Array([3, 4, 5, 6, 7])
## Distance of each ring from the middle.
@export var ring_radius: PackedFloat32Array = PackedFloat32Array([0.04, 0.17, 0.32, 0.48, 0.62])
@export var ring_width: PackedFloat32Array = PackedFloat32Array([0.7, 0.85, 0.95, 1.0, 1.05])
@export var ring_height: PackedFloat32Array = PackedFloat32Array([0.8, 0.8, 0.74, 0.66, 0.56])
## Outward lean of each ring, in radians.
@export var ring_tilt: PackedFloat32Array = PackedFloat32Array([0.0, 0.1, 0.24, 0.4, 0.6])
## Wavy, frilled petal edges (peonies), 0 = smooth.
@export_range(0.0, 1.0) var ruffle: float = 0.0
## 0 = round petal tips, 1 = pointed (tulips).
@export_range(0.0, 1.0) var pointed: float = 0.0
## How much the outer petals' tops roll back outward.
@export_range(0.0, 1.5) var roll: float = 1.0
## Inner petals this much deeper in colour.
@export_range(0.0, 0.4) var inner_shade: float = 0.18
## A cluster of golden stamens in the middle (peonies).
@export var stamens: bool = false
@export var stamen_color: Color = Color(0.98, 0.8, 0.36)

const U_STEPS: int = 7
## Extra steps across a ruffled petal so its waves stay smooth.
const RUFFLE_STEPS: int = 6
const V_STEPS: int = 6


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var rings: int = mini(ring_petals.size(), mini(ring_radius.size(), mini(ring_width.size(), mini(ring_height.size(), ring_tilt.size()))))
	for r in range(rings):
		var count: int = ring_petals[r]
		var shade: float = lerpf(1.0 - inner_shade, 1.0, float(r) / float(maxi(rings - 1, 1)))
		var color := Color(shade, shade, shade, 1.0)
		for i in range(count):
			var a: float = TAU * float(i) / float(count) + float(r) * 0.7
			_add_petal(out, a, ring_radius[r] * size, ring_width[r] * size, ring_height[r] * size, ring_tilt[r], color, r * 31 + i)
	if stamens:
		var gold := Color(stamen_color.r, stamen_color.g, stamen_color.b, 0.0)
		for k in range(14):
			var a: float = float(k) * 2.39996
			var d: float = sqrt(float(k) / 14.0) * size * 0.12
			add_sphere(out, Vector3(cos(a) * d, size * 0.32 + size * 0.04 * (1.0 - d / (size * 0.12)), sin(a) * d), size * 0.03, gold, 4, 6)
	return out


func _add_petal(out: MeshArrays, angle: float, ring_radius_value: float, width: float, height: float, tilt: float, color: Color, petal_seed: int) -> void:
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var across: Vector3 = Vector3.UP.cross(outward)
	var up: Vector3 = Vector3.UP * cos(tilt) + outward * sin(tilt)
	var out_dir: Vector3 = across.cross(up)
	var origin: Vector3 = outward * ring_radius_value
	var u_steps: int = U_STEPS + int(round(ruffle * float(RUFFLE_STEPS)))
	var v_steps: int = V_STEPS + (2 if ruffle > 0.0 else 0)
	var sheet := PackedVector3Array()
	for v in range(v_steps + 1):
		var fv: float = float(v) / float(v_steps)
		for u in range(u_steps + 1):
			var fu: float = float(u) / float(u_steps) * 2.0 - 1.0
			# Narrow at the base, broad and round at the top like a real petal
			# (or drawn to a point for tulips).
			var half: float = width * 0.5 * (0.4 + 0.6 * sin(minf(fv * 1.6, 1.0) * PI * 0.5))
			var round_top: float = 1.0 - 0.32 * fu * fu
			var point_top: float = 1.0 - 0.6 * absf(fu)
			var y: float = fv * height * lerpf(round_top, point_top, pointed * smoothstep(0.4, 1.0, fv))
			# Cupped round the bud; the outer, more open petals roll their top
			# edge back outward.
			var z: float = -fu * fu * width * 0.38 + pow(fv, 3.0) * height * 0.4 * minf(tilt * 1.4, 1.0) * roll
			if ruffle > 0.0:
				# Frilled edges: waves that grow toward the rim of the petal.
				z += sin(fu * 6.0 + float(petal_seed) * 1.7) * width * 0.07 * ruffle * fv * fv
				y += cos(fu * 7.0 + float(petal_seed)) * height * 0.05 * ruffle * fv
			sheet.append(origin + across * fu * half + up * y + out_dir * z)
	var thickness: float = size * 0.02
	for side in [1.0, -1.0]:
		var start: int = out.vertex_count()
		for k in range(sheet.size()):
			out.add_vertex(sheet[k] - out_dir * thickness * (0.5 - 0.5 * side), out_dir * side, color, Vector2.ZERO)
		for v in range(v_steps):
			for u in range(u_steps):
				var a: int = start + v * (u_steps + 1) + u
				var b: int = a + 1
				var c: int = a + u_steps + 1
				var d: int = c + 1
				if side > 0.0:
					out.add_triangle(a, c, b)
					out.add_triangle(b, c, d)
				else:
					out.add_triangle(a, b, c)
					out.add_triangle(b, d, c)
		smooth_normals(out, start)


func radius() -> float:
	return size
