class_name Finish
extends RefCounted
## How a colour is finished: plain (buttercream, sugar, fondant) or shiny
## metallic paint like gold leaf. Stored per item as `shine` (0 = plain,
## 1 = metallic; pearl sits in between) and handed to the shaders in
## vertex-colour alpha, so merged piping keeps each stroke's own finish:
## alpha 1 is plain and alpha 0 fully metallic.
##
## Lustre dust is different: it is painted onto a tier with the dust brush
## and lives in the tier's shimmer mask (see ShimmerMask).


## `color` with the finish stored in alpha, for vertex colours.
static func tone(color: Color, shine: float) -> Color:
	return Color(color.r, color.g, color.b, 1.0 - clampf(shine, 0.0, 1.0))


## Shine of a vertex colour made by `tone`.
static func shine_of(vertex_color: Color) -> float:
	return 1.0 - vertex_color.a
