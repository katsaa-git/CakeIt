class_name StampContext
extends RefCounted
## Everything a StampShape needs to place one stamp.

## Point on the cake surface (tier-local).
var origin := Vector3.ZERO
## Surface normal (unit length).
var normal := Vector3.UP
## Drag direction along the surface (unit length, perpendicular to normal).
var forward := Vector3.FORWARD
## Tip radius times the current pressure, in game units.
var radius: float = 0.07
## Distance between stamps along the drag, in game units (without pressure),
## so stamps that join up (scallops) meet exactly.
var spacing: float = 0.1
## Colour, with the finish in alpha (see Finish).
var color := Color.WHITE
## Second colour of a two-tone bag (alpha 0 = none).
var stripe := Color(0.0, 0.0, 0.0, 0.0)
var shape: ProfileShape
var tip: TipDefinition
var rng: RandomNumberGenerator


func side() -> Vector3:
	return normal.cross(forward).normalized()


## Vertex colours for `profile` in this stamp's colour (and stripe, if the
## bag is two-tone).
func colors_for(profile: ProfileShape, groove_darkening: float = 0.22) -> PackedColorArray:
	return TubeBuilder.bag_colors(profile, color, stripe, groove_darkening)
