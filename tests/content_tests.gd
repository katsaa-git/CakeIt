extends RefCounted
## Content files: every tip is valid, ids and shelf order are unique, and the
## full set of ten tips is there.

var runner: Object


func check(condition: bool, message: String) -> void:
	runner.check(condition, message)


func test_all_tips_are_valid() -> void:
	var tips: Array[TipDefinition] = Content.tips()
	check(tips.size() == 21, "twenty-one piping tips (found %d)" % tips.size())
	var ids: Dictionary = {}
	var orders: Dictionary = {}
	for tip in tips:
		var problems: PackedStringArray = tip.validate()
		check(problems.is_empty(), "%s is valid %s" % [tip.id, problems])
		check(not ids.has(tip.id), "tip id %s is unique" % tip.id)
		check(not orders.has(tip.sort_order), "%s has its own shelf position" % tip.id)
		ids[tip.id] = true
		orders[tip.sort_order] = true
		check(tip.shape().size() >= 6, "%s has a cross-section" % tip.id)


func test_profiles_are_counter_clockwise() -> void:
	for tip in Content.tips():
		var loop: PackedVector2Array = tip.shape().points
		var area: float = 0.0
		for j in range(loop.size()):
			var a: Vector2 = loop[j]
			var b: Vector2 = loop[(j + 1) % loop.size()]
			area += a.x * b.y - b.x * a.y
		check(area > 0.0, "%s profile winds counter-clockwise" % tip.id)
