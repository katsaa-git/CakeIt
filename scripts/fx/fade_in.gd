class_name FadeIn
extends CanvasLayer
## A short cream fade at launch. Behind it, a few warm-up pieces (sprinkles,
## sugar lace, fondant letters, a candle, a dot of piping, a puff of sugar)
## are drawn right in front of the camera, so the GPU prepares their shaders
## now instead of stuttering the first time you use them. The fade lifts
## once frames come steadily (or after a few seconds at most).

## Shortest and longest time the cream screen stays up, in seconds.
const MIN_HOLD: float = 0.6
const MAX_HOLD: float = 4.0
## Frames in a row that must be quicker than this (ms) before fading.
const STEADY_FRAMES: int = 6
const STEADY_MS: float = 34.0
const FADE_TIME: float = 0.7

var _rect: ColorRect
var _warm: Node3D
var _held: float = 0.0
var _steady: int = 0
var _fading: bool = false


func start(main: Node3D) -> void:
	name = "FadeIn"
	layer = 100
	_rect = ColorRect.new()
	_rect.color = UiTheme.PANEL_SOLID
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Clicks wait until the cake is showing.
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)
	_warm = _build_warmup(main)


func _process(delta: float) -> void:
	if _fading:
		return
	_held += delta
	_steady = _steady + 1 if delta * 1000.0 < STEADY_MS else 0
	if (_held >= MIN_HOLD and _steady >= STEADY_FRAMES) or _held >= MAX_HOLD:
		_fading = true
		if is_instance_valid(_warm):
			_warm.queue_free()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween: Tween = create_tween()
		tween.tween_property(_rect, "color:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(queue_free)


## A little cluster of the game's materials just in front of the camera.
func _build_warmup(main: Node3D) -> Node3D:
	var camera: Camera3D = main.get("camera")
	var root := Node3D.new()
	root.name = "ShaderWarmup"
	main.add_child(root)
	root.global_transform = camera.global_transform.translated_local(Vector3(0.0, 0.0, -1.5))
	var model := CakeModel.new()
	model.make_default()
	var layer := DecorationLayer.new()
	layer.setup(model.tiers[0].id, model)
	root.add_child(layer)
	var picks: Array[StringName] = [&"rainbow_sprinkles", &"lace_trim", &"fondant_letters", &"candle", &"gold_dragees"]
	for i in range(picks.size()):
		var definition := Content.decoration(picks[i]) as DecorationDefinition
		if definition == null:
			continue
		var piece := DecorationData.new()
		piece.id = i + 1
		piece.def_id = definition.id
		piece.color = Color.WHITE
		piece.shine = 1.0 if i % 2 == 0 else 0.0
		piece.text = "A"
		piece.path = PackedFloat32Array([0.0, 1.0])
		piece.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 0.4), Vector3((float(i) - 2.0) * 0.12, 0.0, 0.0))
		layer.add(piece)
	layer.flush()
	# A dot of piping in its own material, and a puff of sugar.
	var dot := StrokeBuilder.new(Content.tips()[0], 0.05, Color.WHITE, 1)
	dot.add_sample(Vector3.ZERO, Vector3.BACK, 1.0)
	dot.finish()
	var mesh := MeshInstance3D.new()
	var all := MeshArrays.new()
	for piece in dot.pieces:
		all.append(piece)
	mesh.mesh = all.to_mesh(Materials.buttercream())
	mesh.position = Vector3(0.0, -0.12, 0.0)
	root.add_child(mesh)
	var juice := main.get_node_or_null("Juice") as Juice
	if juice != null:
		juice.puff(root.global_position + Vector3(0.0, 0.1, 0.0), Color.WHITE, 4)
	return root
