class_name UiIcons
extends RefCounted
## Small hand-drawn style icons, drawn with code so the interface needs no
## image files. Each icon is designed in a 1x1 box and scaled to `rect`.


static func draw(ci: CanvasItem, id: StringName, rect: Rect2, color: Color, accent: Color = UiTheme.ACCENT) -> void:
	var s: float = minf(rect.size.x, rect.size.y)
	var o: Vector2 = rect.position + (rect.size - Vector2(s, s)) * 0.5
	var w: float = maxf(s * 0.075, 1.6)
	match id:
		&"pipe":
			# Piping bag: a soft cone with a twisted top and a nozzle.
			var bag := PackedVector2Array([pt(o, s, 0.28, 0.12), pt(o, s, 0.72, 0.12), pt(o, s, 0.6, 0.62), pt(o, s, 0.4, 0.62)])
			ci.draw_colored_polygon(bag, Color(accent, 0.35))
			ci.draw_polyline(_closed(bag), color, w, true)
			ci.draw_line(pt(o, s, 0.38, 0.12), pt(o, s, 0.62, 0.12), color, w * 1.4, true)
			var nozzle := PackedVector2Array([pt(o, s, 0.42, 0.62), pt(o, s, 0.58, 0.62), pt(o, s, 0.53, 0.8), pt(o, s, 0.47, 0.8)])
			ci.draw_colored_polygon(nozzle, color)
			ci.draw_circle(pt(o, s, 0.5, 0.9), s * 0.05, accent)
		&"coat":
			# Cake with a fresh swoosh of frosting.
			_cake(ci, o, s, 0.18, 0.82, 0.42, 0.85, color, w, Color(accent, 0.35))
			var swoosh := PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				swoosh.append(pt(o, s, 0.22 + t * 0.56, 0.42 - sin(t * PI) * 0.16))
			ci.draw_polyline(swoosh, accent, w * 1.6, true)
		&"spatula":
			# Bench scraper.
			var blade := Rect2(pt(o, s, 0.2, 0.42), Vector2(s * 0.6, s * 0.4))
			ci.draw_rect(blade, Color(color, 0.12), true)
			ci.draw_rect(blade, color, false, w)
			ci.draw_line(pt(o, s, 0.22, 0.32), pt(o, s, 0.78, 0.32), color, w * 2.6, true)
			for i in range(3):
				var y: float = 0.52 + float(i) * 0.09
				ci.draw_line(pt(o, s, 0.3, y), pt(o, s, 0.7, y), Color(accent, 0.8), w * 0.7, true)
		&"decorate":
			# Sprinkles in different colours.
			var bits: Array = [[0.25, 0.3, 0.6, Color(0.95, 0.55, 0.62)], [0.6, 0.25, -0.5, Color(0.55, 0.75, 0.92)],
				[0.45, 0.55, 0.2, Color(0.98, 0.8, 0.35)], [0.72, 0.62, 1.1, Color(0.6, 0.82, 0.62)],
				[0.3, 0.72, -1.0, Color(0.78, 0.66, 0.92)]]
			for bit: Array in bits:
				var c: Vector2 = pt(o, s, bit[0], bit[1])
				var d: Vector2 = Vector2(cos(bit[2]), sin(bit[2])) * s * 0.1
				ci.draw_line(c - d, c + d, bit[3], s * 0.09, true)
			ci.draw_circle(pt(o, s, 0.55, 0.42), s * 0.05, color)
			ci.draw_circle(pt(o, s, 0.18, 0.52), s * 0.04, color)
		&"dust":
			# A soft round brush with a little cloud of sparkle.
			ci.draw_line(pt(o, s, 0.78, 0.12), pt(o, s, 0.5, 0.5), color, w * 1.3, true)
			var ferrule := PackedVector2Array([pt(o, s, 0.47, 0.44), pt(o, s, 0.56, 0.53), pt(o, s, 0.5, 0.6), pt(o, s, 0.41, 0.51)])
			ci.draw_colored_polygon(ferrule, color)
			ci.draw_circle(pt(o, s, 0.38, 0.64), s * 0.14, Color(accent, 0.45))
			ci.draw_arc(pt(o, s, 0.38, 0.64), s * 0.14, 0.0, TAU, 20, color, w, true)
			for spark: Vector2 in [Vector2(0.16, 0.78), Vector2(0.26, 0.9), Vector2(0.12, 0.6), Vector2(0.62, 0.84)]:
				var c: Vector2 = pt(o, s, spark.x, spark.y)
				ci.draw_line(c - Vector2(s * 0.045, 0.0), c + Vector2(s * 0.045, 0.0), accent, w * 0.8, true)
				ci.draw_line(c - Vector2(0.0, s * 0.045), c + Vector2(0.0, s * 0.045), accent, w * 0.8, true)
		&"tiers":
			_cake(ci, o, s, 0.12, 0.88, 0.58, 0.9, color, w, Color(accent, 0.3))
			_cake(ci, o, s, 0.27, 0.73, 0.3, 0.58, color, w, Color(accent, 0.45))
			ci.draw_line(pt(o, s, 0.5, 0.3), pt(o, s, 0.5, 0.15), color, w, true)
			ci.draw_circle(pt(o, s, 0.5, 0.13), s * 0.04, accent)
		&"photo":
			var body := Rect2(pt(o, s, 0.14, 0.3), Vector2(s * 0.72, s * 0.5))
			ci.draw_rect(body, Color(accent, 0.25), true)
			ci.draw_rect(body, color, false, w)
			ci.draw_rect(Rect2(pt(o, s, 0.36, 0.2), Vector2(s * 0.28, s * 0.1)), color, true)
			ci.draw_arc(pt(o, s, 0.5, 0.55), s * 0.14, 0.0, TAU, 24, color, w, true)
		&"undo", &"redo":
			var flip: float = -1.0 if id == &"redo" else 1.0
			var arc := PackedVector2Array()
			for i in range(13):
				var a: float = lerpf(-PI * 0.95, PI * 0.25, float(i) / 12.0)
				arc.append(_mirror(pt(o, s, 0.52 + cos(a) * 0.26, 0.55 + sin(a) * 0.26), o, s, flip))
			ci.draw_polyline(arc, color, w * 1.2, true)
			var tip: Vector2 = _mirror(pt(o, s, 0.27, 0.5), o, s, flip)
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.1 * flip, -s * 0.12), tip + Vector2(s * 0.13 * flip, -s * 0.03), tip + Vector2(-s * 0.02 * flip, s * 0.12)]), color)
		&"clear":
			# A little brush sweeping crumbs away.
			ci.draw_line(pt(o, s, 0.68, 0.14), pt(o, s, 0.45, 0.55), color, w * 1.2, true)
			var head := PackedVector2Array([pt(o, s, 0.34, 0.5), pt(o, s, 0.58, 0.62), pt(o, s, 0.48, 0.86), pt(o, s, 0.18, 0.74)])
			ci.draw_colored_polygon(head, Color(accent, 0.4))
			ci.draw_polyline(_closed(head), color, w, true)
			ci.draw_circle(pt(o, s, 0.74, 0.8), s * 0.04, color)
			ci.draw_circle(pt(o, s, 0.84, 0.68), s * 0.03, color)
		&"save":
			# A recipe card with a heart.
			var card := Rect2(pt(o, s, 0.2, 0.16), Vector2(s * 0.6, s * 0.7))
			ci.draw_rect(card, Color(accent, 0.18), true)
			ci.draw_rect(card, color, false, w)
			_heart(ci, pt(o, s, 0.5, 0.48), s * 0.2, accent)
		&"open":
			# A recipe book.
			var left := PackedVector2Array([pt(o, s, 0.5, 0.28), pt(o, s, 0.14, 0.2), pt(o, s, 0.14, 0.78), pt(o, s, 0.5, 0.86)])
			var right := PackedVector2Array([pt(o, s, 0.5, 0.28), pt(o, s, 0.86, 0.2), pt(o, s, 0.86, 0.78), pt(o, s, 0.5, 0.86)])
			ci.draw_colored_polygon(left, Color(accent, 0.2))
			ci.draw_colored_polygon(right, Color(accent, 0.35))
			ci.draw_polyline(_closed(left), color, w, true)
			ci.draw_polyline(_closed(right), color, w, true)
		&"help":
			ci.draw_arc(pt(o, s, 0.5, 0.5), s * 0.36, 0.0, TAU, 32, color, w, true)
			var hook := PackedVector2Array()
			for i in range(10):
				var a: float = lerpf(-PI, PI * 0.45, float(i) / 9.0)
				hook.append(pt(o, s, 0.5 + cos(a) * 0.12, 0.4 + sin(a) * 0.11))
			hook.append(pt(o, s, 0.5, 0.6))
			ci.draw_polyline(hook, color, w * 1.1, true)
			ci.draw_circle(pt(o, s, 0.5, 0.72), s * 0.045, color)
		&"spin":
			for k in range(2):
				var arc2 := PackedVector2Array()
				var start: float = float(k) * PI + 0.3
				for i in range(9):
					var a: float = start + float(i) / 8.0 * (PI - 0.6)
					arc2.append(pt(o, s, 0.5 + cos(a) * 0.3, 0.5 + sin(a) * 0.3))
				ci.draw_polyline(arc2, color, w * 1.1, true)
				var end: Vector2 = arc2[arc2.size() - 1]
				var dir: Vector2 = (end - arc2[arc2.size() - 2]).normalized()
				var n := Vector2(-dir.y, dir.x)
				ci.draw_colored_polygon(PackedVector2Array([end + dir * s * 0.09, end + n * s * 0.08, end - n * s * 0.08]), color)
		&"plus":
			ci.draw_line(pt(o, s, 0.5, 0.22), pt(o, s, 0.5, 0.78), color, w * 1.3, true)
			ci.draw_line(pt(o, s, 0.22, 0.5), pt(o, s, 0.78, 0.5), color, w * 1.3, true)
		&"minus":
			ci.draw_line(pt(o, s, 0.22, 0.5), pt(o, s, 0.78, 0.5), color, w * 1.3, true)
		_:
			ci.draw_circle(rect.get_center(), s * 0.3, color)


## Point in the icon's 1x1 design box.
static func pt(origin: Vector2, size: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * size


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out


static func _mirror(p: Vector2, origin: Vector2, size: float, flip: float) -> Vector2:
	if flip > 0.0:
		return p
	return Vector2(origin.x + size - (p.x - origin.x), p.y)


static func _cake(ci: CanvasItem, o: Vector2, s: float, x0: float, x1: float, y0: float, y1: float, color: Color, w: float, fill: Color) -> void:
	var rect := Rect2(pt(o, s, x0, y0), Vector2((x1 - x0) * s, (y1 - y0) * s))
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = color
	box.set_border_width_all(int(maxf(w, 1.0)))
	box.set_corner_radius_all(int(s * 0.06))
	box.anti_aliasing_size = 1.0
	ci.draw_style_box(box, rect)


static func _heart(ci: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(28):
		var t: float = TAU * float(i) / 28.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * size / 17.0)
	ci.draw_colored_polygon(points, color)
