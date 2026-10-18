extends RefCounted
## Decorations: every definition is valid, every piece has sound geometry,
## pieces built one by one fit their tier, and the layer shows exactly what
## the model holds.

var runner: Object


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


func _definitions() -> Array[DecorationDefinition]:
	var out: Array[DecorationDefinition] = []
	for res in Content.decorations():
		out.append(res as DecorationDefinition)
	return out


func test_definitions_are_valid() -> void:
	var definitions: Array[DecorationDefinition] = _definitions()
	check(definitions.size() >= 60, "at least 60 decorations (found %d)" % definitions.size())
	var ids: Dictionary = {}
	for definition in definitions:
		var problems: PackedStringArray = definition.validate()
		check(problems.is_empty(), "%s is valid %s" % [definition.id, problems])
		check(not ids.has(definition.id), "decoration id %s is unique" % definition.id)
		ids[definition.id] = true
	for entry: Array in DecorationDefinition.CATEGORIES:
		var found: bool = false
		for definition in definitions:
			found = found or definition.category == entry[0]
		check(found, "the %s tab has something in it" % entry[1])


## Empty when faces agree with their normals and nothing is broken.
static func geometry_problems(mesh: MeshArrays) -> String:
	if mesh.vertex_count() == 0 or mesh.indices.is_empty():
		return "no geometry"
	for i in range(mesh.verts.size()):
		if not mesh.verts[i].is_finite() or not mesh.normals[i].is_finite() or absf(mesh.normals[i].length() - 1.0) > 0.02:
			return "broken vertex %d" % i
	var outward: int = 0
	var counted: int = 0
	for i in range(0, mesh.indices.size(), 3):
		var a: Vector3 = mesh.verts[mesh.indices[i]]
		var b: Vector3 = mesh.verts[mesh.indices[i + 1]]
		var c: Vector3 = mesh.verts[mesh.indices[i + 2]]
		var face: Vector3 = (c - a).cross(b - a)
		if face.length_squared() < 1e-18:
			continue
		var n: Vector3 = mesh.normals[mesh.indices[i]] + mesh.normals[mesh.indices[i + 1]] + mesh.normals[mesh.indices[i + 2]]
		counted += 1
		if face.dot(n) > 0.0:
			outward += 1
	var ratio: float = float(outward) / float(maxi(counted, 1))
	if ratio < 0.95:
		return "only %.1f%% of faces point outward" % (ratio * 100.0)
	return ""


func test_every_piece_has_sound_geometry() -> void:
	var tier := TierData.new()
	tier.id = 1
	for definition in _definitions():
		var mesh: MeshArrays
		if definition.builder.is_unique():
			var decoration := DecorationData.new()
			decoration.def_id = definition.id
			decoration.color = Color(0.5, 0.3, 0.2)
			decoration.rng_seed = 4
			decoration.path = PackedFloat32Array([0.0, 2.0])
			mesh = definition.builder.build_unique(decoration, tier)
		else:
			mesh = definition.arrays()
		var problems: String = geometry_problems(mesh)
		check(problems.is_empty(), "%s: sound geometry %s" % [definition.id, problems])
		if not definition.builder.is_unique():
			var bottom: float = mesh.bounds().position.y
			check(bottom > -definition.radius() * 0.5, "%s sits on the surface, not inside it (bottom %.3f)" % [definition.id, bottom])
		# Every shape in a mix is sound too.
		for variant in range(1, definition.variant_count()):
			var problems_v: String = geometry_problems(definition.arrays(variant))
			check(problems_v.is_empty(), "%s shape %d: sound geometry %s" % [definition.id, variant, problems_v])


func test_mixes_use_every_shape() -> void:
	var definition := Content.decoration(&"festive_medley") as DecorationDefinition
	var seen: Dictionary = {}
	for s in range(60):
		seen[definition.variant_for(s * 7919)] = true
	check(seen.size() == definition.variant_count(), "a medley uses all %d of its shapes (%d)" % [definition.variant_count(), seen.size()])


## Words lie flat on top and bend round the side so every letter sits flush.
func test_letters_bend_round_the_side() -> void:
	var definition := Content.decoration(&"fondant_letters") as DecorationDefinition
	var tier := TierData.new()
	tier.radius = 1.0
	tier.height = 1.0
	var on_top := DecorationData.new()
	on_top.text = "HAPPY"
	on_top.color = Color.WHITE
	var flat: AABB = definition.builder.build_unique(on_top, tier).bounds()
	var on_side := on_top.duplicate_data()
	# Standing out from the side (+Y = outward), its top pointing up (+Z = up).
	on_side.transform = Transform3D(Basis(Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)), Vector3(1.0, 0.5, 0.0))
	var bent: AABB = definition.builder.build_unique(on_side, tier).bounds()
	check(flat.size.x > 0.5 and flat.position.y > -0.01, "a word lies flat (%.2f wide)" % flat.size.x)
	check(bent.position.y < -0.02, "on the side it curves back round the cake (%.3f)" % bent.position.y)
	check(geometry_problems(definition.builder.build_unique(on_side, tier)).is_empty(), "the bent word is sound geometry")


## A ribbon at the base stays at the base when the tier gets taller; one in
## the middle stays in the middle.
func test_ribbons_keep_their_place_on_resize() -> void:
	var model := CakeModel.new()
	model.make_default()
	var stack := CommandStack.new(model)
	var tier: TierData = model.tiers[0]
	var def := Content.decoration(&"satin_ribbon") as DecorationDefinition
	var base := DecorationData.new()
	base.id = model.new_id()
	base.def_id = def.id
	base.tier_id = tier.id
	base.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, def.radius(), 0.0))
	base.path = PackedFloat32Array([0.0, TAU])
	var middle: DecorationData = base.duplicate_data()
	middle.id = model.new_id()
	middle.transform.origin.y = tier.height * 0.5
	stack.run(AddDecorationsCommand.new([base, middle] as Array[DecorationData]))
	var before: String = CommandTests.snapshot(model)
	stack.run(TierCommands.ResizeTier.new(model, tier.id, tier.radius, tier.height * 1.5))
	var moved: Array[DecorationData] = model.decorations_on(tier.id)
	check(is_equal_approx(moved[0].transform.origin.y, def.radius()), "the base ribbon stays at the base (%.3f)" % moved[0].transform.origin.y)
	check(absf(moved[1].transform.origin.y - model.tiers[0].height * 0.5) < 0.001, "the middle ribbon stays in the middle")
	var ribbon: MeshArrays = def.builder.build_unique(moved[0], model.tiers[0])
	check(absf(ribbon.bounds().size.x - (model.tiers[0].radius + 0.01) * 2.0) < 0.06, "the ribbon wraps the tier (%.2f)" % ribbon.bounds().size.x)
	stack.undo()
	check(CommandTests.snapshot(model) == before, "undo puts both ribbons back")


func test_drip_follows_its_tier() -> void:
	var definition := Content.decoration(&"ganache_drip") as DecorationDefinition
	var decoration := DecorationData.new()
	decoration.def_id = definition.id
	decoration.path = PackedFloat32Array([0.0, TAU])
	var small := TierData.new()
	small.radius = 1.0
	small.height = 0.8
	var large := TierData.new()
	large.radius = 1.6
	large.height = 1.4
	var a: AABB = definition.builder.build_unique(decoration, small).bounds()
	var b: AABB = definition.builder.build_unique(decoration, large).bounds()
	check(absf(a.size.x - 2.0) < 0.15 and absf(b.size.x - 3.2) < 0.15, "a full drip ring wraps its tier (%.2f, %.2f)" % [a.size.x, b.size.x])
	check(absf(a.end.y - small.height) < 0.06 and absf(b.end.y - large.height) < 0.06, "the drip sits on the top edge (%.3f, %.3f)" % [a.end.y, b.end.y])


func test_layer_shows_the_model() -> void:
	var model := CakeModel.new()
	model.make_default()
	var stack := CommandStack.new(model)
	var layer := DecorationLayer.new()
	layer.setup(model.tiers[0].id, model)
	model.decoration_added.connect(layer.add)
	model.decoration_removed.connect(layer.remove)
	var batch: Array[DecorationData] = []
	for i in range(30):
		var decoration := DecorationData.new()
		decoration.id = model.new_id()
		decoration.def_id = &"rainbow_sprinkles" if i % 3 != 0 else &"cherry"
		decoration.tier_id = model.tiers[0].id
		decoration.transform = Transform3D(Basis.IDENTITY, Vector3(float(i) * 0.03, model.tiers[0].height, 0.0))
		batch.append(decoration)
	var before: String = CommandTests.snapshot(model)
	stack.run(AddDecorationsCommand.new(batch, "Sprinkles"))
	layer.flush()
	check(layer.piece_count() == 30, "the layer shows all 30 pieces (%d)" % layer.piece_count())
	var after: String = CommandTests.snapshot(model)
	stack.undo()
	layer.flush()
	check(layer.piece_count() == 0 and CommandTests.snapshot(model) == before, "one undo takes the whole drag back")
	stack.redo()
	check(CommandTests.snapshot(model) == after, "redo puts it back exactly")
	layer.free()


func test_decorations_follow_a_resized_tier() -> void:
	var model := CakeModel.new()
	model.make_default()
	var stack := CommandStack.new(model)
	var tier: TierData = model.tiers[0]
	var on_side := DecorationData.new()
	on_side.id = model.new_id()
	on_side.def_id = &"sugar_pearls"
	on_side.tier_id = tier.id
	# Standing out from the side: its +Y (the surface normal) points along +X.
	on_side.transform = Transform3D(Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), Vector3(tier.radius, tier.height * 0.5, 0.0))
	stack.run(AddDecorationsCommand.new([on_side] as Array[DecorationData]))
	stack.run(TierCommands.ResizeTier.new(model, tier.id, 1.6, tier.height))
	var moved: DecorationData = model.decorations_on(tier.id)[0]
	check(absf(moved.transform.origin.x - 1.6) < 0.01, "a pearl on the side moves out with it (x %.3f)" % moved.transform.origin.x)
	var loaded: DecorationData = DecorationData.from_dict(JSON.parse_string(JSON.stringify(moved.to_dict())))
	check(loaded.def_id == moved.def_id and loaded.transform.origin.is_equal_approx(moved.transform.origin), "a decoration survives saving and loading")
