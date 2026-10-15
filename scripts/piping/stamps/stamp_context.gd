class_name StampContext
extends RefCounted
## Everything a StampShape needs to place one stamp.

## Point on the cake surface.
var origin := Vector3.ZERO
## Surface normal (unit length).
var normal := Vector3.UP
## Drag direction along the surface (unit length, perpendicular to normal).
var forward := Vector3.FORWARD
## Tip radius times the current pressure, in game units.
var radius: float = 0.07
var color := Color.WHITE
var shape: ProfileShape
var tip: TipDefinition
var rng: RandomNumberGenerator


func side() -> Vector3:
	return normal.cross(forward).normalized()
