extends RefCounted
## Lustre dust: the mask wraps the tier consistently, brushing adds (and
## brushing off removes) dust where it should, one press is one exact undo
## step, the dust survives resizing, saving and loading, and Clear all
## takes it away (undoably).

var runner: Object


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


func _cake() -> CakeModel:
	var model := CakeModel.new()
	model.make_default()
	return model


## Paints one press the way the dust tool does, as one command.
static func paint(model: CakeModel, stack: CommandStack, tier_id: int, points: PackedVector3Array, color: Color, strength: float, limit: float) -> void:
	var tier: TierData = model.tier_by_id(tier_id)
	var before: Image = tier.ensure_shimmer().image.duplicate() as Image
	var changed := Rect2i()
	for p in points:
		var rect: Rect2i = tier.shimmer.dab(p, 0.13, color, strength, limit, tier.radius, tier.height)
		if rect.has_area():
			changed = rect if not changed.has_area() else changed.merge(rect)
	if changed.has_area():
		stack.run(TierCommands.PaintShimmer.new(tier_id, changed, before.get_region(changed), tier.shimmer.region(changed), strength < 0.0))


func _amount_at(tier: TierData, p: Vector3) -> float:
	var uv: Vector2 = ShimmerMask.uv_of(p, tier.radius, tier.height)
	var x: int = clampi(int(uv.x * float(ShimmerMask.WIDTH)), 0, ShimmerMask.WIDTH - 1)
	var y: int = clampi(int(uv.y * float(ShimmerMask.HEIGHT)), 0, ShimmerMask.HEIGHT - 1)
	return tier.shimmer.image.get_pixel(x, y).a if tier.shimmer != null else 0.0


func test_mask_wraps_the_tier() -> void:
	var radius: float = 1.3
	var height: float = 1.05
	var worst: float = 0.0
	for p: Vector3 in [Vector3(radius, 0.4, 0.0), Vector3(0.0, 0.9, -radius), Vector3(0.5, height, 0.3), Vector3(-0.9, height, -0.2), Vector3(0.0, height, 0.01)]:
		var back: Vector3 = ShimmerMask.surface_point(ShimmerMask.uv_of(p, radius, height), radius, height)
		worst = maxf(worst, back.distance_to(p))
	check(worst < 0.001, "a point on the tier maps to the mask and back (worst %.4f)" % worst)
	var rim_side: Vector2 = ShimmerMask.uv_of(Vector3(radius, height, 0.0), radius, height)
	var rim_top: Vector2 = ShimmerMask.uv_of(Vector3(radius - 0.0001, height, 0.0), radius, height)
	check(absf(rim_side.y - rim_top.y) < 0.01, "side and top meet seamlessly at the rim")


func test_brushing_dusts_only_where_painted() -> void:
	var model := _cake()
	var stack := CommandStack.new(model)
	var tier: TierData = model.tiers[0]
	var spot := Vector3(tier.radius, tier.height * 0.5, 0.0)
	var far := Vector3(-tier.radius, tier.height * 0.5, 0.0)
	var before: String = CommandTests.snapshot(model)
	paint(model, stack, tier.id, PackedVector3Array([spot, spot, spot, spot]), Color(1.0, 0.8, 0.42), 0.3, 0.6)
	check(_amount_at(tier, spot) > 0.3, "dust builds up where brushed (%.2f)" % _amount_at(tier, spot))
	check(_amount_at(tier, spot) <= 0.61, "but never past the chosen strength (%.2f)" % _amount_at(tier, spot))
	check(_amount_at(tier, far) == 0.0, "the other side of the cake stays clean")
	check(tier.has_shimmer(), "the tier now has dust")
	var after: String = CommandTests.snapshot(model)
	stack.undo()
	check(CommandTests.snapshot(model) == before and not tier.has_shimmer(), "one undo takes the whole press back")
	stack.redo()
	check(CommandTests.snapshot(model) == after, "redo brings it back exactly")
	paint(model, stack, tier.id, PackedVector3Array([spot, spot, spot, spot, spot, spot]), Color.WHITE, -1.0, 1.0)
	check(_amount_at(tier, spot) < 0.05, "brushing off takes it away (%.2f)" % _amount_at(tier, spot))
	stack.undo()
	check(CommandTests.snapshot(model) == after, "and that is undoable too")


func test_dust_survives_resize_save_and_clear() -> void:
	var model := _cake()
	var stack := CommandStack.new(model)
	var tier: TierData = model.tiers[0]
	paint(model, stack, tier.id, PackedVector3Array([Vector3(0.3, tier.height, 0.2), Vector3(tier.radius, 0.5, 0.0)]), Color(0.97, 0.95, 0.92), 0.4, 0.6)
	var mask_before: PackedByteArray = tier.shimmer.image.get_data()
	stack.run(TierCommands.ResizeTier.new(model, tier.id, 1.6, 1.4))
	var resized: TierData = model.tier_by_id(tier.id)
	check(resized.shimmer != null and resized.shimmer.image.get_data() == mask_before, "the dust stretches with a resized tier")
	var loaded: TierData = TierData.from_dict(JSON.parse_string(JSON.stringify(resized.to_dict())))
	check(loaded.shimmer != null and loaded.shimmer.image.get_data() == mask_before, "the dust survives saving and loading")
	stack.undo()
	check(model.tier_by_id(tier.id).shimmer.image.get_data() == mask_before, "undoing the resize keeps the dust")
	var with_dust: String = CommandTests.snapshot(model)
	stack.run(TierCommands.ClearAll.new(model))
	check(not model.tiers[0].has_shimmer(), "Clear all brushes the dust off too")
	stack.undo()
	check(CommandTests.snapshot(model) == with_dust, "and undoing Clear all brings it back")


func test_finish_is_saved() -> void:
	var tier := TierData.new()
	tier.coat_shine = 1.0
	check(is_equal_approx(TierData.from_dict(tier.to_dict()).coat_shine, 1.0), "a gold coat stays gold after saving")
	var deco := DecorationData.new()
	deco.shine = 0.5
	check(is_equal_approx(DecorationData.from_dict(JSON.parse_string(JSON.stringify(deco.to_dict()))).shine, 0.5), "a pearl decoration stays pearl after saving")
	check(DecorationLayer.pack_finish(deco) >= 7.0 and DecorationLayer.pack_finish(deco) < 9.0, "a piece's finish is packed for the shader")
