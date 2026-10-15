class_name AddDecorationsCommand
extends CakeCommand
## Adds a group of decorations as one undo step (a single placement, or a
## whole drag of the sprinkle brush).

var decorations: Array[DecorationData] = []


func _init(new_decorations: Array[DecorationData], new_label: String = "Decoration") -> void:
	decorations = new_decorations
	label = new_label


func execute(model: CakeModel) -> void:
	for decoration in decorations:
		model.add_decoration(decoration)


func revert(model: CakeModel) -> void:
	for i in range(decorations.size() - 1, -1, -1):
		model.remove_decoration(decorations[i].id)
