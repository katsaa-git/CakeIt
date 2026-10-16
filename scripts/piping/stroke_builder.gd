class_name StrokeBuilder
extends RefCounted
## Turns a stroke's samples into frosting geometry, incrementally.
##
## Pipeline for continuous tips:
##   raw samples -> evenly resampled path -> smoothed path -> rings -> mesh
## Each stage only looks a few points ahead, so once a ring is a few points
## behind the cursor it can never change. Those rings are committed into
## `pieces` (sealed chunks) and never rebuilt; only the short tail near the
## cursor and the end cap are rebuilt each frame by `preview()`.
##
## Rebuilding from saved data feeds the same samples through the same code,
## so the finished stroke is identical to what the player saw while piping.
##
## The last raw sample is "open": while the player holds still its pressure
## keeps growing (a blob forms). It is frozen when the next sample arrives.

## Half-width of the path smoothing window, in resampled points.
const SMOOTH_HALF: int = 5
## Rings per sealed chunk while piping.
const CHUNK_RINGS: int = 20
## Stamps are gathered into pieces of about this many vertices.
const STAMP_CHUNK_VERTS: int = 6000
const CAP_RINGS: int = 6
const END_RINGS: int = 8
## Shorter strokes than this (in tip radii) become a single dot or kiss.
const DOLLOP_LENGTH: float = 0.7
## Rings are only placed where they are needed: when the path turns or tilts
## by more than this (radians), when the thickness changes by more than
## RING_MAX_SCALE_CHANGE, or at least every RING_MAX_GAP tip radii. Gentle
## curves need far fewer rings than tight ones, and look the same.
const RING_MAX_TURN: float = 0.07
const RING_MAX_SCALE_CHANGE: float = 0.025
const RING_MAX_GAP: float = 1.1

var tip: TipDefinition
var radius: float = 0.07
var color := Color.WHITE
var rng_seed: int = 0
## Stamp direction for a single click, when there is no drag to follow.
var fallback_forward := Vector3.FORWARD

## Finished geometry, oldest first. Grows while piping; never rewritten.
var pieces: Array[MeshArrays] = []
## Collision triangles for `pieces` (a low-detail copy of the stroke).
var collision_faces := PackedVector3Array()
var finished: bool = false

var _shape: ProfileShape
var _colors: PackedColorArray
var _spacing: float = 0.02
var _weights := PackedFloat32Array()

# Raw samples. The last one is open (its pressure may still change).
var _raw_p := PackedVector3Array()
var _raw_n := PackedVector3Array()
var _raw_w := PackedFloat32Array()
var _raw_arc := PackedFloat32Array()
var _segments_done: int = 0
var _to_next: float = 0.0

# Evenly resampled path.
var _rp := PackedVector3Array()
var _rn := PackedVector3Array()
var _rw := PackedFloat32Array()

# Smoothed path; everything here is final.
var _sp := PackedVector3Array()
var _sn := PackedVector3Array()
var _sw := PackedFloat32Array()
var _sa := PackedFloat32Array()

# Ring emission state for committed rings.
var _rings_done: int = 0
var _open := MeshArrays.new()
var _open_rings: int = 0
var _last_ring: Array = []
var _prev_tangent := Vector3.ZERO
var _prev_up := Vector3.ZERO
var _coarse_prev := PackedVector3Array()

var _stamps_done: int = 0


func _init(new_tip: TipDefinition, new_radius: float, new_color: Color, new_seed: int = 0) -> void:
	tip = new_tip
	radius = new_radius
	color = new_color
	rng_seed = new_seed
	_shape = tip.shape()
	_colors = TubeBuilder.shaded_colors(_shape, color)
	_spacing = radius * tip.ring_spacing
	_to_next = _spacing
	var sigma: float = float(SMOOTH_HALF) * 0.5
	for i in range(-SMOOTH_HALF, SMOOTH_HALF + 1):
		_weights.append(exp(-float(i * i) / (2.0 * sigma * sigma)))


## Builds the finished geometry for saved stroke data.
static func build_stroke(stroke: StrokeData, stroke_tip: TipDefinition) -> StrokeBuilder:
	var builder := for_stroke(stroke, stroke_tip)
	for i in range(stroke.points.size()):
		builder.add_sample(stroke.points[i], stroke.normals[i], stroke.pressures[i])
	builder.finish()
	return builder


## An empty builder set up like the one that piped `stroke` (same size,
## colour, seed and click direction), ready to be fed its samples.
static func for_stroke(stroke: StrokeData, stroke_tip: TipDefinition) -> StrokeBuilder:
	var builder := StrokeBuilder.new(stroke_tip, stroke.radius, stroke.color, stroke.rng_seed)
	if stroke.forward != Vector3.ZERO:
		builder.fallback_forward = stroke.forward
	return builder


func is_stamp() -> bool:
	return tip.behavior == TipDefinition.Behavior.STAMP and tip.stamp != null


func sample_count() -> int:
	return _raw_p.size()


func raw_length() -> float:
	return _raw_arc[_raw_arc.size() - 1] if not _raw_arc.is_empty() else 0.0


func last_point() -> Vector3:
	return _raw_p[_raw_p.size() - 1]


## Adds a point on the surface (tier-local), its normal and the pressure there.
## Returns false if it was too close to the previous point to matter (the
## pressure still updates, so holding still keeps the blob growing).
func add_sample(point: Vector3, normal: Vector3, pressure: float) -> bool:
	if not _raw_p.is_empty() and point.distance_to(last_point()) < 0.00001:
		_raw_w[_raw_w.size() - 1] = pressure
		return false
	var arc: float = 0.0
	if not _raw_p.is_empty():
		arc = raw_length() + point.distance_to(last_point())
	_raw_p.append(point)
	_raw_n.append(normal.normalized())
	_raw_w.append(pressure)
	_raw_arc.append(arc)
	if is_stamp():
		_commit_stamps(false)
	else:
		_commit_segments()
		_commit_smoothed()
		_emit_committed_rings()
	return true


## Updates the pressure of the newest sample (the player is holding still).
func set_open_pressure(pressure: float) -> void:
	if not _raw_w.is_empty():
		_raw_w[_raw_w.size() - 1] = pressure


## Geometry for everything not yet in `pieces`: the open chunk, the tail near
## the cursor and the end cap. Rebuild this every frame while piping.
func preview() -> MeshArrays:
	if _raw_p.is_empty():
		return MeshArrays.new()
	var tail: MeshArrays = _pending_stamps() if is_stamp() else _build_tail()
	if _open.is_empty():
		return tail
	var combined: MeshArrays = _open.duplicate_arrays()
	combined.append(tail)
	return combined


## Commits everything that is left. After this, `pieces` is the whole stroke.
func finish() -> void:
	if finished:
		return
	finished = true
	if _raw_p.is_empty():
		return
	if is_stamp():
		_commit_stamps(true)
		if not _open.is_empty():
			pieces.append(_open)
			_open = MeshArrays.new()
		return
	var tail: MeshArrays = _build_tail()
	var last: MeshArrays = _open
	last.append(tail)
	_open = MeshArrays.new()
	if not last.is_empty():
		pieces.append(last)
	TubeBuilder.triangles_for_collision(tail, collision_faces)


## Copies the raw samples (with their final pressures) into stroke data.
func export_samples(stroke: StrokeData) -> void:
	stroke.points = _raw_p.duplicate()
	stroke.normals = _raw_n.duplicate()
	stroke.pressures = _raw_w.duplicate()


func vertex_total() -> int:
	var total: int = 0
	for piece in pieces:
		total += piece.vertex_count()
	return total


# --- Resampling and smoothing ---------------------------------------------------

func _commit_segments() -> void:
	# The segment ending at the open sample stays uncommitted.
	while _segments_done < _raw_p.size() - 2:
		if _rp.is_empty():
			_rp.append(_raw_p[0])
			_rn.append(_raw_n[0])
			_rw.append(_raw_w[0])
		_to_next = _resample_segment(_segments_done, _to_next, _rp, _rn, _rw)
		_segments_done += 1


func _resample_segment(i: int, to_next: float, out_p: PackedVector3Array, out_n: PackedVector3Array, out_w: PackedFloat32Array) -> float:
	var a: Vector3 = _raw_p[i]
	var b: Vector3 = _raw_p[i + 1]
	var length: float = a.distance_to(b)
	if length < 0.0000001:
		return to_next
	var pos: float = to_next
	while pos <= length:
		var t: float = pos / length
		out_p.append(a.lerp(b, t))
		out_n.append(_raw_n[i].lerp(_raw_n[i + 1], t).normalized())
		out_w.append(lerpf(_raw_w[i], _raw_w[i + 1], t))
		pos += _spacing
	return pos - length


func _commit_smoothed() -> void:
	while _sp.size() + SMOOTH_HALF < _rp.size():
		var k: int = _sp.size()
		_smooth_into(k, _rp, _rn, _rw, 0, false, _sp, _sn, _sw)
		_sa.append(0.0 if k == 0 else _sa[k - 1] + _sp[k].distance_to(_sp[k - 1]))


## Gaussian-smooths point `k` (global index) of a path stored from global
## index `base` on. The start is mirrored so the first point stays put; the
## end is mirrored only when `mirror_end` (the provisional tail).
func _smooth_into(k: int, p: PackedVector3Array, n: PackedVector3Array, w: PackedFloat32Array, base: int, mirror_end: bool,
		out_p: PackedVector3Array, out_n: PackedVector3Array, out_w: PackedFloat32Array) -> void:
	var last: int = p.size() - 1
	var sum_p := Vector3.ZERO
	var sum_n := Vector3.ZERO
	var sum_w: float = 0.0
	var total: float = 0.0
	for i in range(-SMOOTH_HALF, SMOOTH_HALF + 1):
		var g: int = k + i
		var weight: float = _weights[i + SMOOTH_HALF]
		var local: int = g - base
		var pp: Vector3
		if g < 0:
			# Mirror around the very first point (only reachable when base == 0).
			pp = p[0] * 2.0 - p[mini(-g, last)]
		elif local > last:
			pp = p[last] * 2.0 - p[maxi(2 * last - local, 0)] if mirror_end else p[last]
		else:
			pp = p[maxi(local, 0)]
		var clamped: int = clampi(local, 0, last)
		sum_p += pp * weight
		sum_n += n[clamped] * weight
		sum_w += w[clamped] * weight
		total += weight
	out_p.append(sum_p / total)
	out_n.append((sum_n / total).normalized())
	out_w.append(sum_w / total)


# --- Rings ---------------------------------------------------------------------

func _emit_committed_rings() -> void:
	# A ring needs its neighbour on each side for its direction.
	while _rings_done < _sp.size() - 1:
		var k: int = _rings_done
		var args: Array = _ring_args(k, _sp, _sn, _sw, _sa, 0, _prev_tangent, _prev_up)
		_prev_tangent = args[3]
		_prev_up = args[2]
		_rings_done += 1
		if k > 0 and not _ring_needed(args, _last_ring):
			continue
		_emit_ring_with_caps(_open, k, args)
		_last_ring = args
		_open_rings += 1
		_emit_coarse(args)
		if _open_rings >= CHUNK_RINGS:
			_seal_chunk()


## True if this ring differs enough from the last one placed to be worth adding.
func _ring_needed(args: Array, last: Array) -> bool:
	if last.is_empty() or tip.wave_amplitude > 0.0 or tip.twist_rate != 0.0:
		return true
	var last_scale: float = last[4]
	if (args[0] as Vector3).distance_to(last[0]) > radius * RING_MAX_GAP:
		return true
	if absf(float(args[4]) - last_scale) > last_scale * RING_MAX_SCALE_CHANGE:
		return true
	var limit: float = cos(RING_MAX_TURN)
	return (args[3] as Vector3).dot(last[3]) < limit or (args[2] as Vector3).dot(last[2]) < limit


func _seal_chunk() -> void:
	pieces.append(_open)
	_open = MeshArrays.new()
	# Repeat the last ring so the next chunk joins seamlessly.
	_emit_ring_args(_open, _last_ring)
	_open_rings = 1


## Ring parameters for smoothed point `k` (global index) of a path stored
## from `base` on: [center, side, up, tangent, scale, dscale, twist, u, wave, wave_slope].
func _ring_args(k: int, p: PackedVector3Array, n: PackedVector3Array, w: PackedFloat32Array, a: PackedFloat32Array,
		base: int, prev_tangent: Vector3, prev_up: Vector3) -> Array:
	var local: int = k - base
	var last: int = p.size() - 1
	var k0: int = maxi(local - 1, 0)
	var k1: int = mini(local + 1, last)
	var delta: Vector3 = p[k1] - p[k0]
	var tangent: Vector3 = delta.normalized() if delta.length_squared() > 1e-14 else prev_tangent
	if tangent == Vector3.ZERO:
		tangent = TubeBuilder.any_perpendicular(n[local])
	var up: Vector3 = n[local] - tangent * tangent.dot(n[local])
	if up.length_squared() < 1e-10:
		up = prev_up if prev_up != Vector3.ZERO else TubeBuilder.any_perpendicular(tangent)
	up = up.normalized()
	var side: Vector3 = up.cross(tangent).normalized()
	var pressure: float = w[local]
	var scale: float = radius * pressure
	var span: float = maxf(a[k1] - a[k0], 1e-6)
	var dscale: float = clampf(radius * (w[k1] - w[k0]) / span, -25.0, 25.0)
	var arc: float = a[local]
	var center: Vector3 = p[local] + n[local] * radius * tip.lift * pressure
	var twist: float = arc / radius * tip.twist_rate
	var wave: float = 0.0
	var wave_slope: float = 0.0
	if tip.wave_amplitude > 0.0:
		var wave_length: float = tip.wave_length * radius
		var phase: float = TAU * arc / wave_length
		wave = tip.wave_amplitude * scale * sin(phase)
		wave_slope = tip.wave_amplitude * scale * cos(phase) * TAU / wave_length
	return [center, side, up, tangent, scale, dscale, twist, arc / radius, wave, wave_slope]


func _emit_ring_with_caps(out: MeshArrays, k: int, args: Array) -> void:
	if k == 0:
		_emit_start_cap(out, args)
	_emit_ring_args(out, args)
	if out.vertex_count() > _shape.size():
		TubeBuilder.bridge_last(out, _shape.size())


func _emit_ring_args(out: MeshArrays, args: Array) -> void:
	TubeBuilder.emit_ring(out, _shape, _colors, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])


## Rounded start: a half-dome behind the first ring, closed with a point.
func _emit_start_cap(out: MeshArrays, args: Array) -> void:
	var center: Vector3 = args[0]
	var side: Vector3 = args[1]
	var up: Vector3 = args[2]
	var tangent: Vector3 = args[3]
	var scale: float = args[4]
	var cap_length: float = 0.85
	var ring_size: int = _shape.size()
	var pole: int = TubeBuilder.add_pole_vertex(out, center - tangent * scale * cap_length, -tangent, _colors[0], args[7] - 1.0)
	for i in range(CAP_RINGS):
		var phi: float = (PI * 0.5) * float(i + 1) / float(CAP_RINGS + 1)
		var c: Vector3 = center - tangent * scale * cos(phi) * cap_length
		var dscale: float = clampf(cos(phi) / (sin(phi) * cap_length), -25.0, 25.0)
		var ring0: int = out.vertex_count()
		TubeBuilder.emit_ring(out, _shape, _colors, c, side, up, tangent, scale * sin(phi), dscale, args[6], args[7] - cos(phi), args[8] * sin(phi), args[9])
		if i == 0:
			TubeBuilder.fan(out, pole, ring0, ring_size, true)
		else:
			TubeBuilder.bridge_last(out, ring_size)


func _emit_end_cap(out: MeshArrays, args: Array) -> void:
	var center: Vector3 = args[0]
	var side: Vector3 = args[1]
	var up: Vector3 = args[2]
	var tangent: Vector3 = args[3]
	var scale: float = args[4]
	var centers := PackedVector3Array()
	var scales := PackedFloat32Array()
	var pole: Vector3
	match tip.end_style:
		TipDefinition.EndStyle.PEAK:
			var length: float = tip.end_length * scale
			for i in range(1, END_RINGS + 1):
				var v: float = float(i) / float(END_RINGS + 1)
				centers.append(center + tangent * v * length + up * scale * 0.45 * v * v)
				scales.append(scale * pow(1.0 - v, 1.35) * (1.0 + 0.12 * sin(PI * v)))
			pole = center + tangent * length + up * scale * 0.45
		TipDefinition.EndStyle.POINT:
			var length: float = tip.end_length * scale
			for i in range(1, END_RINGS + 1):
				var v: float = float(i) / float(END_RINGS + 1)
				centers.append(center + tangent * v * length - up * scale * tip.lift * 0.7 * v)
				scales.append(scale * pow(1.0 - v, 0.85))
			pole = center + tangent * length - up * scale * tip.lift * 0.7
		_:
			var cap_length: float = 0.85
			for i in range(1, CAP_RINGS + 1):
				var phi: float = (PI * 0.5) * (1.0 - float(i) / float(CAP_RINGS + 1))
				centers.append(center + tangent * scale * cos(phi) * cap_length)
				scales.append(scale * sin(phi))
			pole = center + tangent * scale * cap_length
	var ring_size: int = _shape.size()
	var count: int = centers.size()
	var previous_center: Vector3 = center
	var previous_scale: float = scale
	for i in range(count):
		var next_center: Vector3 = pole if i == count - 1 else centers[i + 1]
		var next_scale: float = 0.0 if i == count - 1 else scales[i + 1]
		var span: float = maxf((next_center - previous_center).dot(tangent), 1e-6)
		var dscale: float = clampf((next_scale - previous_scale) / span, -25.0, 25.0)
		var fade: float = scales[i] / maxf(scale, 1e-6)
		TubeBuilder.emit_ring(out, _shape, _colors, centers[i], side, up, tangent, scales[i], dscale, args[6], args[7] + float(i + 1) * 0.2, args[8] * fade, args[9] * fade)
		TubeBuilder.bridge_last(out, ring_size)
		previous_center = centers[i]
		previous_scale = scales[i]
	var last_ring: int = out.vertex_count() - ring_size
	var pole_index: int = TubeBuilder.add_pole_vertex(out, pole, tangent, _colors[0], args[7] + float(count + 1) * 0.2)
	TubeBuilder.fan(out, pole_index, last_ring, ring_size, false)


## A single click: a dot, kiss or rosette rising straight off the surface (or,
## for tips with a click_length, a short leaf, petal or bar).
func _emit_dollop(out: MeshArrays) -> void:
	if tip.click_length > 0.0:
		_emit_click_piece(out)
		return
	var origin: Vector3 = _raw_p[0]
	var normal: Vector3 = _raw_n[0]
	var pressure: float = 0.0
	for w in _raw_w:
		pressure = maxf(pressure, w)
	var scale: float = radius * pressure
	var height: float = tip.dollop_height * scale
	var rings: int = 10
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	var twists := PackedFloat32Array()
	var reference: Vector3 = TubeBuilder.any_perpendicular(normal)
	var base: Vector3 = origin - normal * scale * 0.25
	for i in range(rings + 1):
		var v: float = float(i) / float(rings)
		var s: float
		var h: float
		if tip.end_style == TipDefinition.EndStyle.ROUND:
			var phi: float = v * PI * 0.5
			h = sin(phi) * (height + scale * 0.25)
			s = cos(phi)
		else:
			h = v * (height + scale * 0.25)
			s = pow(1.0 - v, 0.8) * (1.0 + 0.14 * sin(PI * v))
		centers.append(base + normal * h)
		ups.append(reference)
		scales.append(maxf(s * scale, scale * 0.02))
		twists.append(v * tip.dollop_twist)
	TubeBuilder.sweep(out, _shape, _colors, centers, ups, scales, twists, false, true, 0.0, 1.0 / radius)


## A click with a leaf, petal or basketweave tip: a short piece laid along the
## surface the way the bag is held. Leaves swell then pull to a point; petals
## and bars have soft rounded ends.
func _emit_click_piece(out: MeshArrays) -> void:
	var origin: Vector3 = _raw_p[0]
	var normal: Vector3 = _raw_n[0]
	var pressure: float = 0.0
	for w in _raw_w:
		pressure = maxf(pressure, w)
	var scale: float = radius * pressure
	var forward: Vector3 = fallback_forward - normal * fallback_forward.dot(normal)
	if forward.length_squared() < 1e-10:
		forward = TubeBuilder.any_perpendicular(normal)
	forward = forward.normalized()
	var length: float = tip.click_length * scale
	var rings: int = 14
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var s: float
		if tip.end_style == TipDefinition.EndStyle.POINT:
			# Fat at the base, then drawn out to a point.
			s = pow(sin(minf(t / 0.3, 1.0) * PI * 0.5), 0.6) if t < 0.3 else pow(1.0 - (t - 0.3) / 0.7, 0.9)
		else:
			s = pow(sin(t * PI), 0.35)
		s = maxf(s, 0.02)
		centers.append(origin + forward * (t - 0.15) * length + normal * scale * tip.lift * s)
		ups.append(normal)
		scales.append(s * scale)
	TubeBuilder.sweep(out, _shape, _colors, centers, ups, scales, PackedFloat32Array(), true, true, 0.0, 1.0 / radius)


func _emit_coarse(args: Array) -> void:
	var center: Vector3 = args[0]
	var side: Vector3 = args[1]
	var up: Vector3 = args[2]
	var scale: float = args[4]
	var ring := PackedVector3Array()
	for q in _shape.coarse:
		ring.append(center + side * q.x * scale + up * q.y * scale)
	if _coarse_prev.size() == ring.size():
		var count: int = ring.size()
		for j in range(count):
			var j1: int = (j + 1) % count
			collision_faces.append(_coarse_prev[j])
			collision_faces.append(ring[j])
			collision_faces.append(_coarse_prev[j1])
			collision_faces.append(_coarse_prev[j1])
			collision_faces.append(ring[j])
			collision_faces.append(ring[j1])
	_coarse_prev = ring


## Everything after the committed rings, worked out provisionally.
func _build_tail() -> MeshArrays:
	var tail := MeshArrays.new()
	if raw_length() < DOLLOP_LENGTH * radius:
		_emit_dollop(tail)
		return tail

	# 1. Resampled path including the open segment and the cursor itself.
	var base: int = maxi(_rp.size() - (2 * SMOOTH_HALF + 2), 0)
	var p: PackedVector3Array = _rp.slice(base)
	var n: PackedVector3Array = _rn.slice(base)
	var w: PackedFloat32Array = _rw.slice(base)
	if _rp.is_empty():
		p.append(_raw_p[0])
		n.append(_raw_n[0])
		w.append(_raw_w[0])
	var to_next: float = _to_next
	for i in range(_segments_done, _raw_p.size() - 1):
		to_next = _resample_segment(i, to_next, p, n, w)
	var last_raw: int = _raw_p.size() - 1
	if p[p.size() - 1].distance_to(_raw_p[last_raw]) > _spacing * 0.25:
		p.append(_raw_p[last_raw])
		n.append(_raw_n[last_raw])
		w.append(_raw_w[last_raw])
	var total: int = base + p.size()

	# 2. Smoothed path: committed points plus provisional ones (end mirrored).
	var sbase: int = maxi(_rings_done - 1, 0)
	var sp: PackedVector3Array = _sp.slice(sbase)
	var sn: PackedVector3Array = _sn.slice(sbase)
	var sw: PackedFloat32Array = _sw.slice(sbase)
	var sa: PackedFloat32Array = _sa.slice(sbase)
	for k in range(_sp.size(), total):
		_smooth_into(k, p, n, w, base, true, sp, sn, sw)
		var previous: int = sp.size() - 2
		sa.append(0.0 if previous < 0 else sa[previous] + sp[previous + 1].distance_to(sp[previous]))
	if sp.size() < 2:
		tail.clear()
		_emit_dollop(tail)
		return tail

	# 3. Rings from the first one not yet committed, then the end cap.
	if not _last_ring.is_empty():
		_emit_ring_args(tail, _last_ring)
	var last_args: Array = _last_ring
	var tangent: Vector3 = _prev_tangent
	var up: Vector3 = _prev_up
	for k in range(_rings_done, total):
		var args: Array = _ring_args(k, sp, sn, sw, sa, sbase, tangent, up)
		tangent = args[3]
		up = args[2]
		# The very last ring is always placed: the end cap hangs off it.
		if k > 0 and k < total - 1 and not _ring_needed(args, last_args):
			continue
		_emit_ring_with_caps(tail, k, args)
		last_args = args
	if not last_args.is_empty():
		_emit_end_cap(tail, last_args)
	return tail


# --- Stamps ----------------------------------------------------------------------

func _stamp_spacing() -> float:
	return maxf(tip.stamp_spacing * radius, radius * 0.3)


## Commits stamps whose position and direction can no longer change.
func _commit_stamps(final: bool) -> void:
	var spacing: float = _stamp_spacing()
	var closed_length: float = _raw_arc[_raw_arc.size() - 2] if _raw_arc.size() >= 2 else 0.0
	var length: float = raw_length()
	while true:
		var s: float = float(_stamps_done) * spacing
		var ready: bool
		if final:
			ready = s <= length + 0.00001 or _stamps_done == 0
		else:
			ready = s + spacing * 0.5 <= closed_length
		if not ready:
			break
		var context: StampContext = _emit_stamp(_open, _stamps_done, s)
		# Picking only needs a rough shape: a low dome per stamp, not every
		# blade of grass.
		tip.stamp.add_collision(collision_faces, context)
		_stamps_done += 1
		if _open.vertex_count() >= STAMP_CHUNK_VERTS:
			pieces.append(_open)
			_open = MeshArrays.new()


## Geometry for stamps that are visible but not yet committed.
func _pending_stamps() -> MeshArrays:
	var out := MeshArrays.new()
	var spacing: float = _stamp_spacing()
	var length: float = raw_length()
	var index: int = _stamps_done
	while index == 0 or float(index) * spacing <= length + 0.00001:
		_emit_stamp(out, index, float(index) * spacing)
		index += 1
		if index > _stamps_done + 4:
			break
	return out


func _emit_stamp(out: MeshArrays, index: int, s: float) -> StampContext:
	var spacing: float = _stamp_spacing()
	var sample: Array = _raw_at(s)
	var context := StampContext.new()
	context.origin = sample[0]
	context.normal = sample[1]
	context.radius = radius * float(sample[2])
	context.color = color
	context.shape = _shape
	context.tip = tip
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = hash(Vector2i(rng_seed, index))
	var ahead: Vector3 = _raw_at(minf(s + spacing * 0.5, raw_length()))[0]
	var behind: Vector3 = _raw_at(maxf(s - spacing * 0.5, 0.0))[0]
	# A click (no real drag) points the way the bag was held instead of
	# following hand jitter.
	var forward: Vector3 = ahead - behind if raw_length() >= spacing * 0.5 else Vector3.ZERO
	forward -= context.normal * forward.dot(context.normal)
	if forward.length_squared() < 1e-10:
		forward = fallback_forward - context.normal * fallback_forward.dot(context.normal)
	if forward.length_squared() < 1e-10:
		forward = TubeBuilder.any_perpendicular(context.normal)
	context.forward = forward.normalized()
	tip.stamp.emit(out, context)
	return context


## Position, normal and pressure at arc length `s` along the raw path.
func _raw_at(s: float) -> Array:
	var count: int = _raw_p.size()
	if count == 1 or s <= 0.0:
		return [_raw_p[0], _raw_n[0], _raw_w[0]]
	for i in range(1, count):
		if _raw_arc[i] >= s:
			var seg: float = _raw_arc[i] - _raw_arc[i - 1]
			var t: float = (s - _raw_arc[i - 1]) / seg if seg > 0.0 else 0.0
			return [_raw_p[i - 1].lerp(_raw_p[i], t), _raw_n[i - 1].lerp(_raw_n[i], t).normalized(), lerpf(_raw_w[i - 1], _raw_w[i], t)]
	return [_raw_p[count - 1], _raw_n[count - 1], _raw_w[count - 1]]
