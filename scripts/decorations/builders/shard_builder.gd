@tool
class_name ShardBuilder
extends DecorationBuilder
## A chocolate shard: a thin, jagged sheet of tempered chocolate stood up in
## the top of the cake. `shape_seed` gives each variant its own outline, so a
## few builders in a decoration's `variants` make a natural-looking mix.

## Height of the shard, in game units (0.5 = 5 cm).
@export_range(0.1, 1.2) var height: float = 0.5
@export_range(0.05, 0.8) var width: float = 0.3
@export_range(0.005, 0.06) var thickness: float = 0.022
@export var shape_seed: int = 1

## How far below its origin it starts (the decoration's `sink` pushes it in).
const SINK: float = 0.0


func radius() -> float:
	return width * 0.5


func build() -> MeshArrays:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	# A broken outline: a broad foot in the cake, straight snapped edges
	# stepping in at odd angles, and a sharp point off to one side.
	var w: float = width * 0.5
	var tip_x: float = rng.randf_range(-0.35, 0.35) * w
	var outline := PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0)])
	var right: Array = [[1.0, 0.18], [0.78, 0.36], [0.86, 0.5], [0.5, 0.7], [0.42, 0.83]]
	for corner: Array in right:
		outline.append(Vector2(float(corner[0]) * w * rng.randf_range(0.82, 1.0), float(corner[1]) * height * rng.randf_range(0.9, 1.1)))
	outline.append(Vector2(tip_x, height))
	var left: Array = [[-0.36, 0.86], [-0.55, 0.64], [-0.72, 0.58], [-0.8, 0.38], [-1.0, 0.2]]
	for corner: Array in left:
		outline.append(Vector2(float(corner[0]) * w * rng.randf_range(0.82, 1.0), float(corner[1]) * height * rng.randf_range(0.9, 1.1)))
	var slab: MeshArrays = extrude(outline, thickness, TINTABLE, true)
	# Stand it up: the outline's top points up, its face looks toward +Z.
	var stand := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0))
	var out := MeshArrays.new()
	add_transformed(out, slab, Transform3D(stand, Vector3(0.0, -SINK, thickness * 0.5)))
	return out
