class_name ShimmerMask
extends RefCounted
## Lustre dust on one tier: a small picture wrapped round the tier like a
## label, holding how much dust lies where and in what colour. Painting
## with the dust brush writes into it; the frosting, piping and decoration
## shaders read it (see art/shaders/shimmer.gdshaderinc).
##
## u goes round the tier (the angle); v goes up the side (0 to 0.5) and then
## in across the top to the middle (0.5 to 1). Because the picture is
## stretched over the tier, the dust stays put when the tier is resized.
##
## Pixels hold the dust colour in linear light, premultiplied by the amount
## (rgb), and the amount (a, 0..1; about 0.5 is a rich dusting, 1 is painted).

const WIDTH: int = 256
const HEIGHT: int = 128

var image: Image


func _init(source: Image = null) -> void:
	if source != null:
		image = source
	else:
		image = Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)


func duplicate_mask() -> ShimmerMask:
	return ShimmerMask.new(image.duplicate() as Image)


func is_empty() -> bool:
	return image.is_invisible()


## Where a tier-local point lands on the mask (the twin of `shimmer_uv` in
## the shader).
static func uv_of(p: Vector3, radius: float, height: float) -> Vector2:
	var r: float = Vector2(p.x, p.z).length()
	var u: float = atan2(p.z, p.x) / TAU + 0.5
	var side_gap: float = radius - r
	var top_gap: float = height - p.y
	var v: float
	if top_gap < side_gap:
		v = 0.5 + 0.5 * clampf(side_gap / radius, 0.0, 1.0)
	else:
		v = 0.5 * clampf(p.y / height, 0.0, 1.0)
	return Vector2(u, v)


## The point on the tier's surface under a mask position (u, v in 0..1).
static func surface_point(uv: Vector2, radius: float, height: float) -> Vector3:
	var angle: float = (uv.x - 0.5) * TAU
	var dir := Vector3(cos(angle), 0.0, sin(angle))
	if uv.y <= 0.5:
		return dir * radius + Vector3(0.0, uv.y * 2.0 * height, 0.0)
	return dir * radius * (1.0 - (uv.y - 0.5) * 2.0) + Vector3(0.0, height, 0.0)


## Dusts a soft round dab centred on tier-local `center`, `brush` units
## across (radius), adding up to `strength` of `color` (sRGB) and never more
## than `limit` in total. A negative strength brushes dust away. Returns the
## pixel rectangle that changed (empty if nothing did).
func dab(center: Vector3, brush: float, color: Color, strength: float, limit: float, radius: float, height: float) -> Rect2i:
	var uv: Vector2 = uv_of(center, radius, height)
	# How far the dab reaches in pixels, up/down and round.
	var reach_v: float = brush / maxf(minf(height, radius), 0.01) * 0.5 * float(HEIGHT) + 2.0
	var row0: int = clampi(int(floor(uv.y * float(HEIGHT) - reach_v)), 0, HEIGHT - 1)
	var row1: int = clampi(int(ceil(uv.y * float(HEIGHT) + reach_v)), 0, HEIGHT - 1)
	var ring: float = Vector2(center.x, center.z).length()
	var cols: int = WIDTH
	if ring > brush * 1.5:
		cols = mini(int(ceil(brush / ring / TAU * float(WIDTH) * 1.6)) * 2 + 4, WIDTH)
	var col_center: int = int(floor(uv.x * float(WIDTH)))
	var linear: Color = color.srgb_to_linear()
	var changed := Rect2i()
	var first: bool = true
	for row in range(row0, row1 + 1):
		var v: float = (float(row) + 0.5) / float(HEIGHT)
		for k in range(cols):
			var col: int = posmod(col_center - cols / 2 + k, WIDTH) if cols < WIDTH else k
			var point: Vector3 = surface_point(Vector2((float(col) + 0.5) / float(WIDTH), v), radius, height)
			var d: float = point.distance_to(center) / brush
			if d >= 1.0:
				continue
			# A soft brush: full in the middle, feathered at the edge.
			var weight: float = 1.0 - smoothstep(0.35, 1.0, d)
			var old: Color = image.get_pixel(col, row)
			var amount: float
			var rgb: Vector3
			if strength >= 0.0:
				amount = minf(old.a + strength * weight * (1.0 - old.a / maxf(limit, 0.001)), maxf(limit, old.a))
				# The new dust settles over the old: colours blend by how much is added.
				var added: float = maxf(amount - old.a, 0.0)
				rgb = Vector3(old.r, old.g, old.b) + Vector3(linear.r, linear.g, linear.b) * added
			else:
				amount = maxf(old.a + strength * weight, 0.0)
				var keep: float = amount / maxf(old.a, 0.0001)
				rgb = Vector3(old.r, old.g, old.b) * keep
			if is_equal_approx(amount, old.a):
				continue
			image.set_pixel(col, row, Color(minf(rgb.x, amount), minf(rgb.y, amount), minf(rgb.z, amount), amount))
			var cell := Rect2i(col, row, 1, 1)
			changed = cell if first else changed.merge(cell)
			first = false
	return changed


## A copy of part of the mask (for undo).
func region(rect: Rect2i) -> Image:
	return image.get_region(rect)


func put_region(rect: Rect2i, part: Image) -> void:
	image.blit_rect(part, Rect2i(Vector2i.ZERO, rect.size), rect.position)


## Saved as a small PNG in base64 (dust is mostly empty, so it packs well).
func to_base64() -> String:
	return Marshalls.raw_to_base64(image.save_png_to_buffer())


static func from_base64(text: String) -> ShimmerMask:
	var data: PackedByteArray = Marshalls.base64_to_raw(text)
	var loaded := Image.new()
	if data.is_empty() or loaded.load_png_from_buffer(data) != OK:
		return null
	loaded.convert(Image.FORMAT_RGBA8)
	if loaded.get_width() != WIDTH or loaded.get_height() != HEIGHT:
		loaded.resize(WIDTH, HEIGHT, Image.INTERPOLATE_BILINEAR)
	return ShimmerMask.new(loaded)
