class_name CommandTests
extends RefCounted
## Undo and redo: every command restores the cake exactly, in any order.

var runner: Object


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


## A plain-data fingerprint of the whole cake, for exact comparisons.
static func snapshot(model: CakeModel) -> String:
	var tiers: Array = []
	for tier in model.tiers:
		tiers.append(tier.to_dict())
	var strokes: Array = []
	for stroke in model.strokes:
		strokes.append(stroke.to_dict())
	var decorations: Array = []
	for decoration in model.decorations:
		decorations.append(decoration.to_dict())
	return JSON.stringify({"tiers": tiers, "strokes": strokes, "decorations": decorations})


func _make_cake() -> CakeModel:
	var model := CakeModel.new()
	model.make_default()
	return model


func _side_stroke(model: CakeModel, tier: TierData) -> StrokeData:
	return DemoCake.side_ring(model, tier, tier.height * 0.5, &"round", 1, Color(0.9, 0.6, 0.7), 0.0, 0, 0.3)


func test_add_stroke_undo_redo() -> void:
	var model := _make_cake()
	var stack := CommandStack.new(model)
	var empty: String = snapshot(model)
	stack.run(AddStrokeCommand.new(_side_stroke(model, model.tiers[0])))
	var with_stroke: String = snapshot(model)
	check(model.strokes.size() == 1, "stroke added")
	stack.undo()
	check(snapshot(model) == empty, "undo removes it exactly")
	stack.redo()
	check(snapshot(model) == with_stroke, "redo restores it exactly")


func test_tier_add_remove_resize_coat() -> void:
	var model := _make_cake()
	var stack := CommandStack.new(model)
	var bottom: TierData = model.tiers[0]
	stack.run(AddStrokeCommand.new(_side_stroke(model, bottom)))
	var states: Array[String] = [snapshot(model)]

	var top := TierData.new()
	top.id = model.new_id()
	top.radius = 1.0
	top.height = 1.0
	stack.run(TierCommands.AddTier.new(top, 1))
	states.append(snapshot(model))
	stack.run(AddStrokeCommand.new(_side_stroke(model, top)))
	states.append(snapshot(model))
	check(model.tiers.size() == 2 and model.tier_base_y(top.id) == bottom.height, "new tier stacks on top")

	stack.run(TierCommands.ResizeTier.new(model, bottom.id, 1.6, 1.4))
	states.append(snapshot(model))
	check(is_equal_approx(model.tier_base_y(top.id), 1.4), "upper tier restacks when the lower one gets taller")
	var moved: StrokeData = model.strokes_on(bottom.id)[0]
	var p: Vector3 = moved.points[0]
	check(absf(Vector2(p.x, p.z).length() - 1.6) < 0.001, "piping follows the resized side")
	check(absf(p.y - 1.4 * 0.5) < 0.001, "piping keeps its relative height")

	stack.run(TierCommands.CoatTier.new(model, top.id, Color(0.7, 0.9, 0.8), false, 0.2))
	states.append(snapshot(model))
	stack.run(TierCommands.RemoveTier.new(model, bottom.id))
	states.append(snapshot(model))
	check(model.tiers.size() == 1 and model.strokes_on(bottom.id).is_empty(), "removing a tier removes its piping")
	check(model.tier_base_y(top.id) == 0.0, "remaining tier drops onto the stand")

	for i in range(states.size() - 2, -1, -1):
		stack.undo()
		check(snapshot(model) == states[i], "undo step %d restores the cake exactly" % i)
	for i in range(1, states.size()):
		stack.redo()
		check(snapshot(model) == states[i], "redo step %d restores the cake exactly" % i)


func test_clear_all_is_undoable() -> void:
	var model := _make_cake()
	var stack := CommandStack.new(model)
	for i in range(3):
		stack.run(AddStrokeCommand.new(_side_stroke(model, model.tiers[0])))
	var before: String = snapshot(model)
	stack.run(TierCommands.ClearAll.new(model))
	check(model.strokes.is_empty() and model.tiers.size() == 1, "clear all removes piping, keeps tiers")
	stack.undo()
	check(snapshot(model) == before, "undo brings everything back")


func test_new_command_clears_redo() -> void:
	var model := _make_cake()
	var stack := CommandStack.new(model)
	stack.run(AddStrokeCommand.new(_side_stroke(model, model.tiers[0])))
	stack.undo()
	check(stack.can_redo(), "redo available after undo")
	stack.run(AddStrokeCommand.new(_side_stroke(model, model.tiers[0])))
	check(not stack.can_redo(), "a new action clears the redo history")
