class_name PipingStroke
extends MeshInstance3D
## One piped line or dot of frosting.
##
## The raw mouse samples (a point on the cake surface plus the surface normal)
## are kept in `points` and `normals`. The visible mesh is rebuilt from them
## whenever a sample is added: the path is resampled evenly, lightly smoothed,
## and swept with a round or star-shaped cross-section, with rounded ends.

enum Tip { ROUND, STAR }

const ROUND_SIDES: int = 14
const STAR_SIDES: int = 32
const STAR_RIDGES: int = 8
const DOT_RINGS: int = 8
## How far the bead's centre sits above the surface, as a fraction of its radius.
const LIFT: float = 0.5

var tip: int = Tip.ROUND
var radius: float = 0.07
var color: Color = Color(1.0, 0.96, 0.92)
var points := PackedVector3Array()
var normals := PackedVector3Array()


func setup(new_tip: int, new_radius: float, new_color: Color) -> void:
	tip = new_tip
	radius = new_radius
	color = new_color
	name = "PipingStroke"
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.metallic_specular = 0.25
	material.rim_enabled = true
	material.rim = 0.2
	material.rim_tint = 0.6
	material_override = material


func add_sample(point: Vector3, normal: Vector3) -> void:
	points.append(point)
	normals.append(normal.normalized())
	rebuild()


func rebuild() -> void:
	if points.is_empty():
		mesh = null
		return
	if _raw_length() < radius * 0.8:
		mesh = _build_dot(points[0], normals[0])
		return
	var resampled: Dictionary = _resample(radius * 0.3)
	var pts: PackedVector3Array = resampled["points"]
	var nrm: PackedVector3Array = resampled["normals"]
	if pts.size() < 3:
		mesh = _build_dot(points[0], normals[0])
		return
	pts = _smooth(pts, 2)

	var arc := PackedFloat32Array()
	arc.append(0.0)
	for i in range(1, pts.size()):
		arc.append(arc[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total: float = arc[arc.size() - 1]

	var centers := PackedVector3Array()
	var scales := PackedFloat32Array()
	for i in range(pts.size()):
		centers.append(pts[i] + nrm[i] * radius * LIFT)
		var from_start: float = clampf(arc[i] / radius, 0.0, 1.0)
		var from_end: float = clampf((total - arc[i]) / radius, 0.0, 1.0)
		scales.append(minf(_dome(from_start), _dome(from_end)))
	mesh = _build_tube(centers, nrm, scales)


# Quarter-circle profile: 0 at the very tip of a rounded end, 1 once fully round.
func _dome(t: float) -> float:
	return maxf(sqrt(maxf(1.0 - (1.0 - t) * (1.0 - t), 0.0)), 0.05)


func _raw_length() -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


# Evenly spaced samples along the raw path, with interpolated normals.
func _resample(spacing: float) -> Dictionary:
	var out_points := PackedVector3Array()
	var out_normals := PackedVector3Array()
	out_points.append(points[0])
	out_normals.append(normals[0])
	var carry: float = spacing
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var seg: float = a.distance_to(b)
		if seg < 0.000001:
			continue
		var d: float = carry
		while d <= seg:
			var t: float = d / seg
			out_points.append(a.lerp(b, t))
			out_normals.append(normals[i - 1].lerp(normals[i], t).normalized())
			d += spacing
		carry = d - seg
	var last: int = points.size() - 1
	if out_points[out_points.size() - 1].distance_to(points[last]) > spacing * 0.25:
		out_points.append(points[last])
		out_normals.append(normals[last])
	return {"points": out_points, "normals": out_normals}


func _smooth(source: PackedVector3Array, iterations: int) -> PackedVector3Array:
	var current: PackedVector3Array = source
	for iteration in range(iterations):
		var next: PackedVector3Array = current.duplicate()
		for i in range(1, current.size() - 1):
			next[i] = (current[i - 1] + current[i] * 2.0 + current[i + 1]) * 0.25
		current = next
	return current


# Cross-section radius multiplier at angle theta around the stroke.
func _section(theta: float) -> float:
	if tip == Tip.STAR:
		# Pointed ridges and rounded valleys, like a star piping tip.
		return 1.0 - 0.28 * pow(absf(cos(float(STAR_RIDGES) * 0.5 * theta)), 0.7)
	return 1.0


# A rounded dome of frosting, for a single click.
func _build_dot(point: Vector3, normal: Vector3) -> ArrayMesh:
	var perp: Vector3 = normal.cross(Vector3.RIGHT)
	if perp.length() < 0.1:
		perp = normal.cross(Vector3.FORWARD)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(DOT_RINGS + 1):
		var phi: float = (PI * 0.5) * float(k) / float(DOT_RINGS)
		centers.append(point + normal * radius * (-0.1 + 0.95 * sin(phi)))
		ups.append(perp)
		scales.append(maxf(cos(phi), 0.05))
	return _build_tube(centers, ups, scales)


# Sweeps the cross-section along the centre line. `ups` gives the preferred
# "up" direction at each ring (the surface normal for strokes).
func _build_tube(centers: PackedVector3Array, ups: PackedVector3Array, scales: PackedFloat32Array) -> ArrayMesh:
	var ring_count: int = centers.size()
	if ring_count < 2:
		return null
	var sides: int = STAR_SIDES if tip == Tip.STAR else ROUND_SIDES
	var rings: Array[PackedVector3Array] = []
	for k in range(ring_count):
		var t: Vector3
		if k == 0:
			t = centers[1] - centers[0]
		elif k == ring_count - 1:
			t = centers[k] - centers[k - 1]
		else:
			t = centers[k + 1] - centers[k - 1]
		t = t.normalized()
		var u: Vector3 = ups[k] - t * t.dot(ups[k])
		if u.length() < 0.0001:
			u = t.cross(Vector3.RIGHT)
			if u.length() < 0.1:
				u = t.cross(Vector3.FORWARD)
		u = u.normalized()
		var s: Vector3 = t.cross(u)
		var ring := PackedVector3Array()
		for j in range(sides):
			var theta: float = TAU * float(j) / float(sides)
			var rr: float = radius * scales[k] * _section(theta)
			ring.append(centers[k] + (s * cos(theta) + u * sin(theta)) * rr)
		ring.append(ring[0])
		rings.append(ring)

	# Indexed mesh; each ring repeats its first vertex at the end so it closes
	# cleanly. Normals come from the neighbouring vertices, which keeps the star
	# ridges crisp and the round tube smooth.
	var stride: int = sides + 1
	var verts := PackedVector3Array()
	verts.resize(ring_count * stride)
	var norms := PackedVector3Array()
	norms.resize(ring_count * stride)
	for k in range(ring_count):
		var ring: PackedVector3Array = rings[k]
		for j in range(stride):
			verts[k * stride + j] = ring[j]
	for k in range(ring_count):
		var k0: int = maxi(k - 1, 0)
		var k1: int = mini(k + 1, ring_count - 1)
		for j in range(stride):
			var j_prev: int = (j - 1 + sides) % sides
			var j_next: int = (j + 1) % sides
			var around: Vector3 = verts[k * stride + j_next] - verts[k * stride + j_prev]
			var along: Vector3 = verts[k1 * stride + j] - verts[k0 * stride + j]
			var n: Vector3 = around.cross(along)
			norms[k * stride + j] = n.normalized() if n.length_squared() > 0.0000000001 else ups[k]
	var indices := PackedInt32Array()
	indices.resize((ring_count - 1) * sides * 6)
	var w: int = 0
	for k in range(ring_count - 1):
		for j in range(sides):
			var a: int = k * stride + j
			var b: int = a + 1
			var c: int = a + stride
			var d: int = c + 1
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = c
			indices[w + 3] = b
			indices[w + 4] = d
			indices[w + 5] = c
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
