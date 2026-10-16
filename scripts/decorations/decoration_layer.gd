class_name DecorationLayer
extends Node3D
## Shows the decorations on one tier (or on the stand's plate).
##
## Pieces of the same kind share one MultiMesh, so a thousand sprinkles are
## one draw call; each piece's colour and a random number ride along in the
## instance custom data (see decoration.gdshader). Drips, signs and pieces
## with a hand-made scene are built one by one. Candles get flames (one
## MultiMesh) and the tier gets one gently flickering warm light.
##
## Changes are collected and applied once per frame (or right away with
## `flush()`), so adding a whole sprinkle drag rebuilds each MultiMesh once.

const FLAME_SHADER: Shader = preload("res://art/shaders/candle_flame.gdshader")
## Flame quad size at decoration size 1, in game units.
const FLAME_SIZE := Vector2(0.075, 0.16)
const MAX_LIGHT_ENERGY: float = 1.6


class Group:
	var definition: DecorationDefinition
	var node: MultiMeshInstance3D
	## decoration id -> DecorationData
	var items: Dictionary = {}
	var dirty: bool = false


var tier_id: int = 0
## Used to look up the tier's size for pieces built to fit it (drips).
var model: CakeModel

var _groups: Dictionary = {}
var _unique: Dictionary = {}
var _flames: MultiMeshInstance3D
var _flames_dirty: bool = false
var _light: OmniLight3D
var _light_energy: float = 0.0
var _time: float = 0.0


func setup(new_tier_id: int, new_model: CakeModel) -> void:
	tier_id = new_tier_id
	model = new_model
	name = "Decorations"


func add(decoration: DecorationData) -> void:
	var definition := Content.decoration(decoration.def_id) as DecorationDefinition
	if definition == null:
		push_warning("Unknown decoration '%s'" % decoration.def_id)
		return
	if definition.scene_override != null or (definition.builder != null and definition.builder.is_unique()):
		_add_unique(definition, decoration)
	else:
		var group: Group = _group(definition)
		group.items[decoration.id] = decoration
		group.dirty = true
	if _has_flame(definition):
		_flames_dirty = true


func remove(decoration: DecorationData) -> void:
	var node: Node3D = _unique.get(decoration.id)
	if node != null:
		_unique.erase(decoration.id)
		node.queue_free()
	var group: Group = _groups.get(decoration.def_id)
	if group != null and group.items.has(decoration.id):
		group.items.erase(decoration.id)
		group.dirty = true
		if _has_flame(group.definition):
			_flames_dirty = true


func clear() -> void:
	for group: Group in _groups.values():
		group.node.queue_free()
	_groups.clear()
	for node: Node3D in _unique.values():
		node.queue_free()
	_unique.clear()
	_flames_dirty = true


func piece_count() -> int:
	var total: int = _unique.size()
	for group: Group in _groups.values():
		total += group.items.size()
	return total


## Applies all pending changes now.
func flush() -> void:
	for group: Group in _groups.values():
		if group.dirty:
			_rebuild(group)
	if _flames_dirty:
		_rebuild_flames()


func _process(delta: float) -> void:
	flush()
	if _light != null and _light.visible:
		_time += delta
		var flicker: float = 0.88 + 0.07 * sin(_time * 11.0) + 0.05 * sin(_time * 17.3 + 1.1)
		_light.light_energy = _light_energy * flicker


func _group(definition: DecorationDefinition) -> Group:
	var group: Group = _groups.get(definition.id)
	if group == null:
		group = Group.new()
		group.definition = definition
		group.node = MultiMeshInstance3D.new()
		group.node.name = String(definition.id)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = definition.mesh()
		group.node.multimesh = multimesh
		group.node.material_override = definition.material()
		group.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if definition.casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(group.node)
		_groups[definition.id] = group
	return group


func _rebuild(group: Group) -> void:
	group.dirty = false
	var multimesh: MultiMesh = group.node.multimesh
	multimesh.instance_count = group.items.size()
	var i: int = 0
	for decoration: DecorationData in group.items.values():
		multimesh.set_instance_transform(i, decoration.transform)
		multimesh.set_instance_custom_data(i, Color(decoration.color.r, decoration.color.g, decoration.color.b, _random01(decoration.rng_seed)))
		i += 1


func _add_unique(definition: DecorationDefinition, decoration: DecorationData) -> void:
	remove(decoration)
	var node: Node3D
	if definition.scene_override != null:
		node = definition.scene_override.instantiate() as Node3D
	else:
		node = Node3D.new()
		var tier: TierData = model.tier_by_id(tier_id) if model != null else null
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = definition.builder.build_unique(decoration, tier).to_mesh(definition.material())
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if definition.casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mesh_instance)
		definition.builder.add_extras(node, decoration)
	node.name = "%s%d" % [definition.id, decoration.id]
	node.transform = decoration.transform
	add_child(node)
	_unique[decoration.id] = node


static func _has_flame(definition: DecorationDefinition) -> bool:
	return definition.builder != null and definition.builder.flame_offset() != Vector3.ZERO


func _rebuild_flames() -> void:
	_flames_dirty = false
	var transforms: Array[Transform3D] = []
	var seeds: Array[float] = []
	for group: Group in _groups.values():
		if not _has_flame(group.definition):
			continue
		var offset: Vector3 = group.definition.builder.flame_offset()
		for decoration: DecorationData in group.items.values():
			var scale: float = decoration.transform.basis.get_scale().y
			var position_now: Vector3 = decoration.transform * offset
			# Flames always stand straight up, whatever the candle's lean.
			transforms.append(Transform3D(Basis.from_scale(Vector3(FLAME_SIZE.x * scale, FLAME_SIZE.y * scale, 1.0)), position_now))
			seeds.append(_random01(decoration.rng_seed))
	if transforms.is_empty():
		if _flames != null:
			_flames.visible = false
			_light.visible = false
		return
	if _flames == null:
		_build_flame_nodes()
	_flames.visible = true
	var multimesh: MultiMesh = _flames.multimesh
	multimesh.instance_count = transforms.size()
	var center := Vector3.ZERO
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, seeds[i]))
		center += transforms[i].origin
	center /= float(transforms.size())
	# One warm light for all the candles on this tier, a bit above them.
	_light.visible = true
	_light.position = center + Vector3(0.0, 0.25, 0.0)
	_light_energy = minf(0.45 * sqrt(float(transforms.size())), MAX_LIGHT_ENERGY)
	_light.light_energy = _light_energy


func _build_flame_nodes() -> void:
	_flames = MultiMeshInstance3D.new()
	_flames.name = "Flames"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	_flames.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	_flames.material_override = material
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The flames move in the shader; give them room so they are never culled.
	_flames.extra_cull_margin = 0.3
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.name = "CandleGlow"
	_light.light_color = Color(1.0, 0.72, 0.42)
	_light.omni_range = 3.0
	_light.omni_attenuation = 1.6
	_light.light_specular = 0.4
	_light.shadow_enabled = false
	add_child(_light)


## A stable random number in 0..1 for a piece (its own sparkle or flicker).
static func _random01(seed_value: int) -> float:
	return float(absi(hash(seed_value)) % 10007) / 10007.0
