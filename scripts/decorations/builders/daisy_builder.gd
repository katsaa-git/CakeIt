@tool
class_name DaisyBuilder
extends DecorationBuilder
## Open, flat-faced flowers: a ring (or two) of petals in the picked colour
## round a domed middle that keeps its own colour. A daisy has slim petals
## and a sunny middle; a sunflower two rows of pointed petals round a big
## brown seed head; a forget-me-not five round petals round a tiny eye.

@export_range(4, 32) var petals: int = 14
## Petal length, in game units.
@export_range(0.01, 0.3) var petal_length: float = 0.085
## Petal width, as a fraction of its length.
@export_range(0.05, 1.0) var petal_width: float = 0.28
## Rows of petals (2 = a second row tucked between the first).
@export_range(1, 2) var rows: int = 1
## Pointed petal tips (sunflowers) instead of rounded ones.
@export var pointed: bool = false
@export var center_color: Color = Color(0.98, 0.8, 0.3)
## Size of the middle, as a fraction of the petal length.
@export_range(0.1, 1.5) var center_size: float = 0.27
## A seed head of tiny florets in a sunflower spiral, instead of a smooth dome.
@export var seed_head: bool = false


func build() -> MeshArrays:
	var out := MeshArrays.new()
	var petal := MeshArrays.new()
	if pointed:
		_pointed_petal(petal)
	else:
		add_sphere(petal, Vector3(0.0, 0.0, petal_length * 0.5), 1.0, TINTABLE, 6, 10, Vector3(petal_length * petal_width * 0.5, petal_length * 0.05, petal_length * 0.5))
	var hub: float = petal_length * center_size * 0.75
	for row in range(rows):
		var shade: float = 1.0 - 0.1 * float(row)
		var tinted := MeshArrays.new()
		tinted.append(petal)
		for i in range(tinted.colors.size()):
			tinted.colors[i] = Color(shade, shade, shade, 1.0)
		for i in range(petals):
			var a: float = TAU * (float(i) + 0.5 * float(row)) / float(petals) + (0.06 if i % 2 == 0 else -0.06)
			var tilt: float = (-0.16 if i % 2 == 0 else -0.08) - 0.1 * float(row)
			var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt)
			add_transformed(out, tinted, Transform3D(basis, basis * Vector3(0.0, 0.0, hub * 0.8 if pointed else 0.0) + Vector3(0.0, petal_length * 0.07 + float(i % 2) * 0.003 - float(row) * 0.004, 0.0)))
	var middle := Color(center_color.r, center_color.g, center_color.b, 0.0)
	var center_radius: float = petal_length * center_size
	add_sphere(out, Vector3(0.0, petal_length * 0.12, 0.0), center_radius, middle, 7, 14, Vector3(1.0, 0.45 if seed_head else 0.55, 1.0))
	if seed_head:
		# Florets in a sunflower spiral, darker toward the middle.
		var count: int = 70
		for k in range(count):
			var f: float = sqrt((float(k) + 0.5) / float(count))
			var a: float = float(k) * 2.39996
			var d: float = f * center_radius * 0.92
			var h: float = petal_length * 0.12 + center_radius * 0.45 * sqrt(maxf(1.0 - f * f, 0.0))
			var tone: Color = middle.darkened(0.35 * (1.0 - f))
			tone.a = 0.0
			add_sphere(out, Vector3(cos(a) * d, h, sin(a) * d), center_radius * 0.085, tone, 3, 5)
	return out


## A slim petal drawn to a point, slightly cupped along its middle.
func _pointed_petal(out: MeshArrays) -> void:
	var profile: ProfileShape = PetalFlowerStamp.cupped_profile(-0.35, 0.16, 8)
	var colors: PackedColorArray = TubeBuilder.shaded_colors(profile, TINTABLE, 0.0)
	var centers := PackedVector3Array()
	var ups := PackedVector3Array()
	var scales := PackedFloat32Array()
	for k in range(7):
		var t: float = float(k) / 6.0
		centers.append(Vector3(0.0, petal_length * 0.05 * sin(t * PI), petal_length * t))
		ups.append(Vector3.UP)
		var shape: float = sin(minf(t / 0.4, 1.0) * PI * 0.5) if t < 0.4 else 1.0 - (t - 0.4) / 0.6
		scales.append(maxf(petal_length * petal_width * 0.5 * shape, petal_length * 0.01))
	TubeBuilder.sweep(out, profile, colors, centers, ups, scales, PackedFloat32Array(), true, true)


func radius() -> float:
	return petal_length * (1.0 + center_size * 0.6)
