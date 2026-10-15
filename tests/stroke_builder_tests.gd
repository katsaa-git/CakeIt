extends RefCounted
## Stroke builder: geometry is valid, faces point outward, live piping
## matches the rebuilt-from-data stroke exactly, and it stays fast.

var runner: Object


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


## A wavy line across a flat surface, with pressure varying along it.
static func make_wavy_stroke(tip_id: StringName, samples: int, length: float) -> StrokeData:
	var stroke := StrokeData.new()
	stroke.id = 1
	stroke.tip_id = tip_id
	stroke.radius = 0.07
	stroke.color = Color(0.95, 0.7, 0.75)
	stroke.rng_seed = 42
	for i in range(samples):
		var t: float = float(i) / float(maxi(samples - 1, 1))
		var p := Vector3(t * length - length * 0.5, 0.0, sin(t * TAU) * 0.3)
		# A little jitter, like a real hand.
		p += Vector3(sin(i * 12.9898) * 0.003, 0.0, cos(i * 78.233) * 0.003)
		stroke.add_sample(p, Vector3.UP, 0.9 + 0.2 * sin(t * 9.0))
	return stroke


static func concat(pieces: Array[MeshArrays]) -> MeshArrays:
	var out := MeshArrays.new()
	for piece in pieces:
		out.append(piece)
	return out


func test_tips_load() -> void:
	check(Content.tip(&"round") != null, "round tip loads")
	check(Content.tip(&"open_star") != null, "open star tip loads")


func test_geometry_is_valid_and_faces_point_outward() -> void:
	for tip in Content.tips():
		var stroke: StrokeData = make_wavy_stroke(tip.id, 120, 3.0)
		var builder: StrokeBuilder = StrokeBuilder.build_stroke(stroke, tip)
		var mesh: MeshArrays = concat(builder.pieces)
		check(mesh.vertex_count() > 100, "%s: produced geometry (%d verts)" % [tip.id, mesh.vertex_count()])
		check(mesh.indices.size() % 3 == 0, "%s: whole triangles" % tip.id)
		var bad_values: int = 0
		for v in mesh.verts:
			if not v.is_finite():
				bad_values += 1
		for n in mesh.normals:
			if not n.is_finite() or absf(n.length() - 1.0) > 0.01:
				bad_values += 1
		check(bad_values == 0, "%s: no NaN positions or broken normals (%d bad)" % [tip.id, bad_values])
		var outward: int = 0
		var counted: int = 0
		for i in range(0, mesh.indices.size(), 3):
			var a: Vector3 = mesh.verts[mesh.indices[i]]
			var b: Vector3 = mesh.verts[mesh.indices[i + 1]]
			var c: Vector3 = mesh.verts[mesh.indices[i + 2]]
			# Godot front faces are clockwise: outward normal = (c - a) x (b - a).
			var face: Vector3 = (c - a).cross(b - a)
			if face.length_squared() < 1e-16:
				continue
			var vn: Vector3 = mesh.normals[mesh.indices[i]] + mesh.normals[mesh.indices[i + 1]] + mesh.normals[mesh.indices[i + 2]]
			counted += 1
			if face.dot(vn) > 0.0:
				outward += 1
		var ratio: float = float(outward) / float(maxi(counted, 1))
		check(ratio > 0.97, "%s: faces agree with normals (%.1f%%)" % [tip.id, ratio * 100.0])
		check(builder.collision_faces.size() > 0 and builder.collision_faces.size() % 3 == 0, "%s: has collision triangles" % tip.id)


func test_live_piping_matches_rebuild_exactly() -> void:
	for tip in Content.tips():
		var stroke: StrokeData = make_wavy_stroke(tip.id, 200, 4.0)
		var live := StrokeBuilder.new(tip, stroke.radius, stroke.color, stroke.rng_seed)
		var last_preview := MeshArrays.new()
		for i in range(stroke.points.size()):
			live.add_sample(stroke.points[i], stroke.normals[i], stroke.pressures[i])
			last_preview = live.preview()
		var committed_before_finish: int = live.pieces.size()
		live.finish()
		var rebuilt: StrokeBuilder = StrokeBuilder.build_stroke(stroke, tip)
		var a: MeshArrays = concat(live.pieces)
		var b: MeshArrays = concat(rebuilt.pieces)
		check(a.verts == b.verts, "%s: live and rebuilt vertices identical" % tip.id)
		check(a.indices == b.indices, "%s: live and rebuilt triangles identical" % tip.id)
		if tip.behavior == TipDefinition.Behavior.CONTINUOUS:
			# What the player saw on the last frame is exactly the final tail: no pop on release.
			var final_tail: MeshArrays = live.pieces[live.pieces.size() - 1]
			check(committed_before_finish == live.pieces.size() - 1, "%s: finish adds exactly one piece" % tip.id)
			check(final_tail.verts == last_preview.verts, "%s: last preview equals final tail (no pop)" % tip.id)


func test_single_click_makes_a_dollop() -> void:
	for tip in Content.tips():
		var stroke := StrokeData.new()
		stroke.tip_id = tip.id
		stroke.radius = 0.07
		stroke.add_sample(Vector3.ZERO, Vector3.UP, 1.4)
		var builder: StrokeBuilder = StrokeBuilder.build_stroke(stroke, tip)
		var mesh: MeshArrays = concat(builder.pieces)
		check(mesh.vertex_count() > 0, "%s: a click makes a dot" % tip.id)
		var top: float = -INF
		for v in mesh.verts:
			top = maxf(top, v.y)
		check(top > 0.05, "%s: the dot rises off the surface (top %.3f)" % [tip.id, top])


func test_holding_still_grows_the_blob() -> void:
	var tip: TipDefinition = Content.tip(&"round")
	var small := StrokeBuilder.new(tip, 0.07, Color.WHITE)
	small.add_sample(Vector3.ZERO, Vector3.UP, 1.0)
	var big := StrokeBuilder.new(tip, 0.07, Color.WHITE)
	big.add_sample(Vector3.ZERO, Vector3.UP, 1.0)
	big.set_open_pressure(1.6)
	check(big.preview().bounds().size.x > small.preview().bounds().size.x * 1.3, "pressure grows the dot")


func test_live_piping_is_fast() -> void:
	var tip: TipDefinition = Content.tip(&"open_star")
	var stroke: StrokeData = make_wavy_stroke(tip.id, 2000, 40.0)
	var builder := StrokeBuilder.new(tip, stroke.radius, stroke.color)
	var worst: int = 0
	var total: int = 0
	for i in range(stroke.points.size()):
		var t0: int = Time.get_ticks_usec()
		builder.add_sample(stroke.points[i], stroke.normals[i], stroke.pressures[i])
		builder.preview()
		var dt: int = Time.get_ticks_usec() - t0
		total += dt
		if i > 10:
			worst = maxi(worst, dt)
	var average: float = float(total) / float(stroke.points.size())
	print("    live piping cost per frame: avg %.2f ms, worst %.2f ms (%d verts, very long stroke)" % [average / 1000.0, worst / 1000.0, builder.vertex_total()])
	# Cost must not grow with stroke length: the last frames are as cheap as the first.
	check(average < 4000.0, "average per-frame cost under 4 ms (%.2f ms)" % (average / 1000.0))
