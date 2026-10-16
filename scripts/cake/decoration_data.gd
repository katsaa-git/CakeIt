class_name DecorationData
extends RefCounted
## One placed decoration as plain data: which definition, where it sits on its
## tier, its colour and a random seed for variation. Meshes are never saved.
##
## `transform` is in the tier's local space and includes rotation and scale.
## `path` is only used by path decorations such as ganache drips: it holds the
## rim angles (radians) the player dragged along.

var id: int = 0
var def_id: StringName = &""
var tier_id: int = 0
var transform := Transform3D.IDENTITY
var color: Color = Color.WHITE
var rng_seed: int = 0
var path := PackedFloat32Array()
## Words on a topper sign (empty for everything else).
var text: String = ""


func duplicate_data() -> DecorationData:
	var copy := DecorationData.new()
	copy.id = id
	copy.def_id = def_id
	copy.tier_id = tier_id
	copy.transform = transform
	copy.color = color
	copy.rng_seed = rng_seed
	copy.path = path.duplicate()
	copy.text = text
	return copy


func to_dict() -> Dictionary:
	var data := {
		"id": id,
		"def": String(def_id),
		"tier": tier_id,
		"xform": SaveMath.pack_transform(transform),
		"color": color.to_html(false),
		"seed": rng_seed,
	}
	if not path.is_empty():
		data["path"] = SaveMath.pack_floats(path, 0.0001)
	if not text.is_empty():
		data["text"] = text
	return data


static func from_dict(data: Dictionary) -> DecorationData:
	var deco := DecorationData.new()
	deco.id = int(data.get("id", 0))
	deco.def_id = StringName(data.get("def", ""))
	deco.tier_id = int(data.get("tier", 0))
	deco.transform = SaveMath.unpack_transform(data.get("xform", []))
	deco.color = Color.from_string(String(data.get("color", "ffffff")), Color.WHITE)
	deco.rng_seed = int(data.get("seed", 0))
	deco.path = SaveMath.unpack_floats(data.get("path", []))
	deco.text = String(data.get("text", ""))
	return deco
