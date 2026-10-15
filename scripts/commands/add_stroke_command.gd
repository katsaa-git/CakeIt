class_name AddStrokeCommand
extends CakeCommand
## Adds one piped stroke.

var stroke: StrokeData


func _init(new_stroke: StrokeData) -> void:
	stroke = new_stroke
	label = "Piping"


func execute(model: CakeModel) -> void:
	model.add_stroke(stroke)


func revert(model: CakeModel) -> void:
	model.remove_stroke(stroke.id)
