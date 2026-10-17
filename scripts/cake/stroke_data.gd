class_name StrokeData
extends RefCounted
## One piped stroke as plain data: which tip, what size and colour, and the
## path it followed. The mesh is always rebuilt from this, never saved.
##
## Points and normals are in the tier's local space (origin at the centre of
## the tier's bottom face), so a stroke moves with its tier. `pressures` are
## thickness multipliers (1.0 = normal) recorded while piping.

var id: int = 0
var tier_id: int = 0
var tip_id: StringName = &"round"
## Which named size preset was used (0, 1, 2), or -1 for a fine-tuned size.
var size_index: int = 1
var radius: float = 0.07
var color: Color = Color(1.0, 0.96, 0.92)
## Second colour of a two-tone bag (alpha 0 = a plain bag).
var stripe := Color(0.0, 0.0, 0.0, 0.0)
## 0 = plain buttercream, 1 = metallic paint (see Finish).
var shine: float = 0.0
var rng_seed: int = 0
var points := PackedVector3Array()
var normals := PackedVector3Array()
var pressures := PackedFloat32Array()
## For a single click (one sample), the direction the shell, leaf or petal
## points along the surface (tier-local). Zero when the path itself says.
var forward := Vector3.ZERO


func sample_count() -> int:
	return points.size()


func add_sample(point: Vector3, normal: Vector3, pressure: float) -> void:
	points.append(point)
	normals.append(normal)
	pressures.append(pressure)


func duplicate_data() -> StrokeData:
	var copy := StrokeData.new()
	copy.id = id
	copy.tier_id = tier_id
	copy.tip_id = tip_id
	copy.size_index = size_index
	copy.radius = radius
	copy.color = color
	copy.stripe = stripe
	copy.shine = shine
	copy.rng_seed = rng_seed
	copy.points = points.duplicate()
	copy.normals = normals.duplicate()
	copy.pressures = pressures.duplicate()
	copy.forward = forward
	return copy


## Path length along the raw samples, in units.
func length() -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


func to_dict() -> Dictionary:
	var data := {
		"id": id,
		"tier": tier_id,
		"tip": String(tip_id),
		"size_index": size_index,
		"radius": snappedf(radius, 0.00001),
		"color": color.to_html(false),
		"seed": rng_seed,
		"points": SaveMath.pack_vec3(points, 0.0001),
		"normals": SaveMath.pack_vec3(normals, 0.001),
		"pressures": SaveMath.pack_floats(pressures, 0.001),
	}
	if forward != Vector3.ZERO:
		data["forward"] = SaveMath.pack_vec3(PackedVector3Array([forward]), 0.001)
	if stripe.a > 0.0:
		data["stripe"] = stripe.to_html(false)
	if shine > 0.0:
		data["shine"] = snappedf(shine, 0.01)
	return data


static func from_dict(data: Dictionary) -> StrokeData:
	var stroke := StrokeData.new()
	stroke.id = int(data.get("id", 0))
	stroke.tier_id = int(data.get("tier", 0))
	stroke.tip_id = StringName(data.get("tip", "round"))
	stroke.size_index = int(data.get("size_index", -1))
	stroke.radius = float(data.get("radius", 0.07))
	stroke.color = Color.from_string(String(data.get("color", "ffffff")), Color.WHITE)
	stroke.rng_seed = int(data.get("seed", 0))
	stroke.points = SaveMath.unpack_vec3(data.get("points", []))
	stroke.normals = SaveMath.unpack_vec3(data.get("normals", []))
	stroke.pressures = SaveMath.unpack_floats(data.get("pressures", []))
	var forward: PackedVector3Array = SaveMath.unpack_vec3(data.get("forward", []))
	if forward.size() == 1:
		stroke.forward = forward[0]
	if data.has("stripe"):
		stroke.stripe = Color.from_string(String(data["stripe"]), Color.WHITE)
	stroke.shine = clampf(float(data.get("shine", 0.0)), 0.0, 1.0)
	# Repair mismatched arrays from a hand-edited or damaged file.
	var count: int = mini(stroke.points.size(), stroke.normals.size())
	stroke.points.resize(count)
	stroke.normals.resize(count)
	if stroke.pressures.size() != count:
		var old: int = stroke.pressures.size()
		stroke.pressures.resize(count)
		for i in range(old, count):
			stroke.pressures[i] = 1.0
	return stroke
