class_name TierData
extends RefCounted
## One tier of the cake as plain data (no meshes). Tiers are stacked bottom to
## top in CakeModel.tiers and centred automatically. Piping and decorations
## refer to their tier by `id`, so tiers can be resized or removed safely.
##
## Scale: 1 unit = 10 cm.

var id: int = 0
## Which TierShape builds this tier. Only "round" exists for now.
var shape_id: StringName = &"round"
var radius: float = 1.4
var height: float = 1.1
var coat_color: Color = Color(1.0, 0.96, 0.89)
## False shows the "semi-naked" sponge look; true is a full smooth coat.
var coated: bool = true
## 0 = rustic spatula marks, 1 = glass smooth.
var smoothness: float = 0.45


func duplicate_data() -> TierData:
	var copy := TierData.new()
	copy.id = id
	copy.shape_id = shape_id
	copy.radius = radius
	copy.height = height
	copy.coat_color = coat_color
	copy.coated = coated
	copy.smoothness = smoothness
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"shape": String(shape_id),
		"radius": snappedf(radius, 0.0001),
		"height": snappedf(height, 0.0001),
		"coat_color": coat_color.to_html(false),
		"coated": coated,
		"smoothness": snappedf(smoothness, 0.001),
	}


static func from_dict(data: Dictionary) -> TierData:
	var tier := TierData.new()
	tier.id = int(data.get("id", 0))
	tier.shape_id = StringName(data.get("shape", "round"))
	tier.radius = float(data.get("radius", 1.4))
	tier.height = float(data.get("height", 1.1))
	tier.coat_color = Color.from_string(String(data.get("coat_color", "fff5e3")), Color(1.0, 0.96, 0.89))
	tier.coated = bool(data.get("coated", true))
	tier.smoothness = float(data.get("smoothness", 0.45))
	return tier
