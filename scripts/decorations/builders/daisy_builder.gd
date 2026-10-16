@tool
class_name DaisyBuilder
extends DecorationBuilder
## A sugar daisy: a ring of slim, slightly cupped petals in the picked colour
## around a domed sunny middle that keeps its own colour.

@export_range(5, 24) var petals: int = 14
## Petal length, in game units.
@export_range(0.02, 0.2) var petal_length: float = 0.085
@export var center_color: Color = Color(0.98, 0.8, 0.3)


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var petal := MeshArrays.new()
	add_sphere(petal, Vector3(0.0, 0.0, petal_length * 0.5), 1.0, TINTABLE, 6, 10, Vector3(petal_length * 0.14, petal_length * 0.05, petal_length * 0.5))
	for i in range(petals):
		var a: float = TAU * float(i) / float(petals) + (0.06 if i % 2 == 0 else -0.06)
		var tilt: float = -0.16 if i % 2 == 0 else -0.08
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt)
		add_transformed(out, petal, Transform3D(basis, Vector3(0.0, petal_length * 0.07 + float(i % 2) * 0.003, 0.0)))
	var middle := Color(center_color.r, center_color.g, center_color.b, 0.0)
	add_sphere(out, Vector3(0.0, petal_length * 0.12, 0.0), petal_length * 0.27, middle, 7, 14, Vector3(1.0, 0.55, 1.0))
	return out


func radius() -> float:
	return petal_length
