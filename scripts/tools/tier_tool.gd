class_name TierTool
extends DecoratingTool
## Pick a tier to change its width or height, add a tier on top, or take one
## away. Hovered tiers glow softly; the selected tier glows a little more.
## Every change is undoable, and the cake restacks itself automatically.

signal tier_added(tier_id: int)
signal tier_removed
signal tier_resized(tier_id: int)

const HOVER_GLOW: float = 0.35
const SELECTED_GLOW: float = 0.7

var _hover_id: int = 0


func _init() -> void:
	tool_id = &"tiers"


func setup(new_context: EditorContext) -> void:
	super.setup(new_context)
	context.model.tiers_changed.connect(_on_tiers_changed)
	context.model.reset.connect(_on_tiers_changed)


func activate() -> void:
	if context.model.tier_by_id(context.selected_tier_id) == null and not context.model.tiers.is_empty():
		context.select_tier(context.model.tiers[context.model.tiers.size() - 1].id)
	_refresh_glow()


func deactivate() -> void:
	_hover_id = 0
	for view in context.view.tier_views():
		view.set_highlight(0.0)


func press(hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	if hit == null or hit.tier_id == CakeModel.BOARD_ID:
		return false
	context.select_tier(hit.tier_id)
	_refresh_glow()
	return true


func update(_delta: float, hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	var hover: int = 0
	if hit != null and hit.tier_id != CakeModel.BOARD_ID:
		hover = hit.tier_id
	if hover != _hover_id:
		_hover_id = hover
		_refresh_glow()


func selected_tier() -> TierData:
	return context.model.tier_by_id(context.selected_tier_id)


func set_width(radius: float) -> void:
	var tier: TierData = selected_tier()
	if tier == null or is_equal_approx(tier.radius, radius):
		return
	context.commands.run(TierCommands.ResizeTier.new(context.model, tier.id, radius, tier.height))
	tier_resized.emit(tier.id)


func set_height(height: float) -> void:
	var tier: TierData = selected_tier()
	if tier == null or is_equal_approx(tier.height, height):
		return
	context.commands.run(TierCommands.ResizeTier.new(context.model, tier.id, tier.radius, height))
	tier_resized.emit(tier.id)


## Adds a tier on top, a size smaller than the current top tier.
func add_tier() -> void:
	var model: CakeModel = context.model
	if not model.can_add_tier():
		context.toast("That's as tall as this stand can hold")
		return
	var top: TierData = model.tiers[model.tiers.size() - 1] if not model.tiers.is_empty() else null
	var tier := TierData.new()
	tier.id = model.new_id()
	tier.radius = _next_smaller_width(top.radius) if top != null else 1.3
	tier.height = top.height if top != null else 1.05
	if top != null:
		tier.coat_color = top.coat_color
		tier.coated = top.coated
		tier.smoothness = top.smoothness
	context.commands.run(TierCommands.AddTier.new(tier, model.tiers.size()))
	context.select_tier(tier.id)
	_refresh_glow()
	tier_added.emit(tier.id)


func remove_selected() -> void:
	var model: CakeModel = context.model
	var tier: TierData = selected_tier()
	if tier == null:
		return
	if model.tiers.size() <= 1:
		context.toast("Every cake needs at least one tier")
		return
	var index: int = model.tier_index(tier.id)
	context.commands.run(TierCommands.RemoveTier.new(model, tier.id))
	context.select_tier(model.tiers[clampi(index, 0, model.tiers.size() - 1)].id)
	_refresh_glow()
	tier_removed.emit()


func _next_smaller_width(radius: float) -> float:
	var best: float = maxf(radius * 0.75, 0.6)
	var widths: Array[float] = []
	for preset in Content.tier_presets():
		if preset is TierPreset and (preset as TierPreset).kind == TierPreset.Kind.WIDTH:
			widths.append((preset as TierPreset).value)
	widths.sort()
	for i in range(widths.size() - 1, -1, -1):
		if widths[i] < radius - 0.05:
			return widths[i]
	return best if widths.is_empty() else minf(widths[0], best)


func _on_tiers_changed() -> void:
	if context.model.tier_by_id(context.selected_tier_id) == null:
		context.select_tier(context.model.tiers[context.model.tiers.size() - 1].id if not context.model.tiers.is_empty() else 0)
	if context.tool_id == tool_id:
		_refresh_glow.call_deferred()


func _refresh_glow() -> void:
	if context.tool_id != tool_id:
		return
	for view in context.view.tier_views():
		var glow: float = 0.0
		if view.tier_id == context.selected_tier_id:
			glow = SELECTED_GLOW
		elif view.tier_id == _hover_id:
			glow = HOVER_GLOW
		view.set_highlight(glow)
