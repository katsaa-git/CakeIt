class_name CakeCommand
extends RefCounted
## One undoable change to the cake. Subclasses store everything they need to
## apply the change and to take it back, so undo and redo are always exact.

## Short player-facing name, e.g. "Piping" (shown in undo/redo toasts).
var label: String = ""


func execute(_model: CakeModel) -> void:
	pass


func revert(_model: CakeModel) -> void:
	pass
