class_name CommandStack
extends RefCounted
## Runs commands against the cake model and keeps them for undo and redo.
## A new command clears the redo history, like every editor.

## Emitted after any run, undo or redo. `direction` is 1 for run/redo, -1 for undo.
signal changed(command: CakeCommand, direction: int)

const MAX_HISTORY: int = 500

var model: CakeModel

var _undo: Array[CakeCommand] = []
var _redo: Array[CakeCommand] = []


func _init(cake_model: CakeModel) -> void:
	model = cake_model


func run(command: CakeCommand) -> void:
	command.execute(model)
	_undo.append(command)
	if _undo.size() > MAX_HISTORY:
		_undo.pop_front()
	_redo.clear()
	changed.emit(command, 1)


func undo() -> CakeCommand:
	if _undo.is_empty():
		return null
	var command: CakeCommand = _undo.pop_back()
	command.revert(model)
	_redo.append(command)
	changed.emit(command, -1)
	return command


func redo() -> CakeCommand:
	if _redo.is_empty():
		return null
	var command: CakeCommand = _redo.pop_back()
	command.execute(model)
	_undo.append(command)
	changed.emit(command, 1)
	return command


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


## Forgets all history (after loading a different cake).
func clear_history() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit(null, 0)
