class_name DecoratingTool
extends Node
## Base class for the decorating tools (piping, coat, decorations, tiers).
## The ToolController feeds each active tool the current pointer hit every
## frame and forwards left-button presses and releases.

var context: EditorContext
var tool_id: StringName = &""


func setup(new_context: EditorContext) -> void:
	context = new_context


func activate() -> void:
	pass


func deactivate() -> void:
	pass


## Left button pressed over the cake (hit may be null when over empty space).
## Return true if the tool started something.
func press(_hit: CakePicker.Hit, _screen_position: Vector2) -> bool:
	return false


func release() -> void:
	pass


## Called every frame while the tool is active.
func update(_delta: float, _hit: CakePicker.Hit, _screen_position: Vector2) -> void:
	pass


## True while a press is in progress (piping, scattering...).
func is_busy() -> bool:
	return false


## True when the tool draws its own cursor in 3D (the OS cursor is hidden).
func hides_cursor() -> bool:
	return false
