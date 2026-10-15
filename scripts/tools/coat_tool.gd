class_name CoatTool
extends DecoratingTool
## Click a tier to cover its top and sides with a fresh coat of frosting in
## the chosen colour. The new coat spreads from the top centre down the sides.
## With "naked" selected it scrapes back to the semi-naked sponge look.

signal coat_applied(world_position: Vector3, color: Color)

var _hover_id: int = 0


func _init() -> void:
	tool_id = &"coat"


func deactivate() -> void:
	_set_hover(0)


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	if hit == null or hit.tier_id == CakeModel.BOARD_ID:
		return false
	var tier: TierData = context.model.tier_by_id(hit.tier_id)
	if tier == null:
		return false
	var coated: bool = not context.coat_naked
	if tier.coated == coated and tier.coat_color.is_equal_approx(context.color):
		context.toast("That tier already has this coat")
		return true
	# A fresh coat starts with soft spatula marks; the spatula smooths it.
	context.commands.run(TierCommands.CoatTier.new(context.model, tier.id, context.color, coated, 0.45))
	coat_applied.emit(hit.world_position, context.color)
	return true


func update(_delta: float, hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	_set_hover(hit.tier_id if hit != null else 0)


func _set_hover(tier_id: int) -> void:
	if tier_id == _hover_id:
		return
	var old: TierView = context.view.view_for(_hover_id) if _hover_id != 0 else null
	if old != null:
		old.set_highlight(0.0)
	_hover_id = tier_id
	var view: TierView = context.view.view_for(tier_id) if tier_id != 0 else null
	if view != null:
		view.set_highlight(0.3)
