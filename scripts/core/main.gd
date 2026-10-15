extends Node3D
## Placeholder main scene. It only confirms the project opens and runs:
## one pink "cake tier", a camera and a light. Replaced by the real
## decorating scene in the first prototype milestone.


func _ready() -> void:
	$Tier.position.y = 0.2
	var camera: Camera3D = $Camera3D
	camera.position = Vector3(0.0, 0.8, 1.6)
	camera.look_at(Vector3(0.0, 0.2, 0.0))
	var sun: DirectionalLight3D = $Sun
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	print("CakeGame project loaded OK")
