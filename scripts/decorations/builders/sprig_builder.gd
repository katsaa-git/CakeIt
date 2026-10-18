@tool
class_name SprigBuilder
extends DecorationBuilder
## A little sprig lying on the cake, its tip toward +Z:
##   LAVENDER      a slim stem with whorls of tiny buds along its top half;
##   BABYS_BREATH  a branching stem with clouds of tiny round florets.
## The buds and florets take the piece's colour; stems stay green.

enum Kind { LAVENDER, BABYS_BREATH }

@export var kind: Kind = Kind.LAVENDER
## Length of the sprig, in game units (0.45 = 4.5 cm).
@export_range(0.1, 1.0) var length: float = 0.45

const STEM := Color(0.47, 0.6, 0.4, 0.0)


func radius() -> float:
	return length * 0.5


func build() -> MeshArrays:
	var out := MeshArrays.new()
	if kind == Kind.LAVENDER:
		_lavender(out)
	else:
		_babys_breath(out)
	return out


func _lavender(out: MeshArrays) -> void:
	var y: float = length * 0.025
	var stem := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in range(6):
		var t: float = float(k) / 5.0
		stem.append(Vector3(sin(t * 2.0) * length * 0.03, y, (t - 0.5) * length))
		radii.append(length * lerpf(0.012, 0.007, t))
	add_tube(out, stem, radii, STEM, 6)
	# Whorls of buds, closer together and smaller toward the tip.
	var whorls: int = 10
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		var z: float = lerpf(0.0, 0.5, pow(t, 0.85)) * length
		var x: float = sin((z / length + 0.5) * 2.0) * length * 0.03
		var bud: float = length * lerpf(0.026, 0.017, t)
		var count: int = 5 if t < 0.8 else 3
		for k in range(count):
			var a: float = TAU * float(k) / float(count) + float(w) * 0.6
			var offset := Vector3(cos(a), sin(a) * 0.8 + 0.4, 0.0) * bud * 0.9
			var basis := Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, -0.5)
			var shade: float = lerpf(0.82, 1.0, float(k % 2))
			add_blob(out, Transform3D(basis, Vector3(x, y + bud * 0.4, z) + offset), 1.0, Color(shade, shade, shade, 1.0), Vector3(bud * 0.55, bud * 0.55, bud), 4, 6)
	# Two narrow leaves near the cut end.
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.UP, side * 0.5)
		add_blob(out, Transform3D(basis, Vector3(side * length * 0.05, y, -length * 0.36)), 1.0, STEM, Vector3(length * 0.022, length * 0.008, length * 0.11), 4, 8)


func _babys_breath(out: MeshArrays) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var y: float = length * 0.03
	var base := Vector3(0.0, y, -length * 0.5)
	var fork := Vector3(0.0, y * 1.3, -length * 0.1)
	add_tube(out, PackedVector3Array([base, (base + fork) * 0.5, fork]), PackedFloat32Array([length * 0.012, length * 0.01, length * 0.009]), STEM, 6)
	for b in range(5):
		var spread: float = (float(b) - 2.0) * 0.35 + rng.randf_range(-0.1, 0.1)
		var branch_end: Vector3 = fork + Vector3(sin(spread), 0.2, cos(spread)) * length * rng.randf_range(0.28, 0.4)
		add_tube(out, PackedVector3Array([fork, (fork + branch_end) * 0.5, branch_end]), PackedFloat32Array([length * 0.007, length * 0.006, length * 0.005]), STEM, 5)
		for k in range(4):
			var a: float = rng.randf() * TAU
			var tip: Vector3 = branch_end + Vector3(cos(a), 0.3, sin(a)) * length * rng.randf_range(0.03, 0.08)
			add_tube(out, PackedVector3Array([branch_end, tip]), PackedFloat32Array([length * 0.004, length * 0.003]), STEM, 4)
			# A floret: a few tiny puffs together.
			for p in range(3):
				var puff: Vector3 = tip + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(-1.0, 1.0)) * length * 0.012
				var shade: float = rng.randf_range(0.9, 1.0)
				add_sphere(out, puff, length * rng.randf_range(0.014, 0.019), Color(shade, shade, shade, 1.0), 4, 6)
