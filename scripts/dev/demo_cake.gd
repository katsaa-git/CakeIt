class_name DemoCake
extends RefCounted
## Generates piping along classic cake patterns (borders, swags, rings, dots)
## directly as stroke data. Used by the screenshot and benchmark runs, and
## handy for tests. Paths are sampled as densely as the piping tool would.


static func _new_stroke(model: CakeModel, tier: TierData, tip_id: StringName, size_index: int, color: Color) -> StrokeData:
	var stroke := StrokeData.new()
	stroke.id = model.new_id()
	stroke.tier_id = tier.id if tier != null else CakeModel.BOARD_ID
	stroke.tip_id = tip_id
	stroke.size_index = size_index
	stroke.radius = Content.tip(tip_id).preset_size(size_index)
	stroke.color = color
	stroke.rng_seed = stroke.id * 7919
	return stroke


## A full ring around the side at height `y` (tier-local), with an optional
## gentle wave. `turns` > 1 overlaps the start for seamless borders.
static func side_ring(model: CakeModel, tier: TierData, y: float, tip_id: StringName, size_index: int, color: Color,
		wave: float = 0.0, waves: int = 0, turns: float = 1.0) -> StrokeData:
	var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
	var step: float = stroke.radius * 0.25 / tier.radius
	var total: float = TAU * turns
	var a: float = 0.0
	while a <= total:
		var h: float = y + wave * sin(a * float(waves))
		stroke.add_sample(Vector3(cos(a) * tier.radius, h, sin(a) * tier.radius), Vector3(cos(a), 0.0, sin(a)), 1.0)
		a += step
	return stroke


## A ring on the top surface at radius `r`.
static func top_ring(model: CakeModel, tier: TierData, r: float, tip_id: StringName, size_index: int, color: Color, turns: float = 1.0) -> StrokeData:
	var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
	var step: float = stroke.radius * 0.25 / r
	var a: float = 0.0
	while a <= TAU * turns:
		stroke.add_sample(Vector3(cos(a) * r, tier.height, sin(a) * r), Vector3.UP, 1.0)
		a += step
	return stroke


## Swags: hanging arcs around the side, starting `top_offset` below the rim.
static func swags(model: CakeModel, tier: TierData, count: int, depth: float, top_offset: float, tip_id: StringName, size_index: int, color: Color) -> Array[StrokeData]:
	var out: Array[StrokeData] = []
	for i in range(count):
		var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
		var a0: float = TAU * float(i) / float(count)
		var a1: float = TAU * float(i + 1) / float(count)
		var steps: int = int((a1 - a0) * tier.radius / (stroke.radius * 0.25))
		for s in range(steps + 1):
			var t: float = float(s) / float(steps)
			var a: float = lerpf(a0, a1, t)
			var y: float = tier.height - top_offset - depth * sin(PI * t)
			stroke.add_sample(Vector3(cos(a) * tier.radius, y, sin(a) * tier.radius), Vector3(cos(a), 0.0, sin(a)), 1.0)
		out.append(stroke)
	return out


## Single-click dots/kisses at evenly spaced angles on the side.
static func side_dots(model: CakeModel, tier: TierData, count: int, y: float, tip_id: StringName, size_index: int, color: Color, pressure: float = 1.2) -> Array[StrokeData]:
	var out: Array[StrokeData] = []
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
		stroke.add_sample(Vector3(cos(a) * tier.radius, y, sin(a) * tier.radius), Vector3(cos(a), 0.0, sin(a)), pressure)
		out.append(stroke)
	return out


## Single-click kisses on the top, in a ring.
static func top_dots(model: CakeModel, tier: TierData, count: int, r: float, tip_id: StringName, size_index: int, color: Color, pressure: float = 1.3) -> Array[StrokeData]:
	var out: Array[StrokeData] = []
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
		stroke.add_sample(Vector3(cos(a) * r, tier.height, sin(a) * r), Vector3.UP, pressure)
		out.append(stroke)
	return out


## A rosette swirl on the top at `center` (tier-local, on the top surface).
static func rosette(model: CakeModel, tier: TierData, center: Vector3, tip_id: StringName, size_index: int, color: Color) -> StrokeData:
	var stroke: StrokeData = _new_stroke(model, tier, tip_id, size_index, color)
	var radius: float = stroke.radius * 1.6
	var a: float = 0.0
	while a < TAU * 1.15:
		var r: float = radius * (0.15 + 0.85 * minf(a / PI, 1.0))
		stroke.add_sample(center + Vector3(cos(a) * r, 0.0, sin(a) * r), Vector3.UP, 1.0)
		a += 0.12
	return stroke
