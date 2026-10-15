class_name UiTheme
extends RefCounted
## The cozy look of the interface: warm cream panels with soft shadows,
## cocoa-brown text, a rose accent, and generous rounded corners. Built in
## code (no theme files) and shared by every panel.

const PANEL := Color(1.0, 0.978, 0.948, 0.94)
const PANEL_SOLID := Color(1.0, 0.978, 0.948, 1.0)
const PANEL_BORDER := Color(0.92, 0.85, 0.79, 1.0)
const TEXT := Color(0.36, 0.25, 0.21)
const TEXT_MUTED := Color(0.58, 0.47, 0.41)
const ACCENT := Color(0.89, 0.52, 0.6)
const ACCENT_SOFT := Color(0.99, 0.9, 0.91)
const HOVER := Color(0.98, 0.93, 0.89)
const SHADOW := Color(0.35, 0.2, 0.12, 0.16)
const RADIUS: int = 18

static var _theme: Theme
static var _font: SystemFont
static var _bold: SystemFont


static func font(bold: bool = false) -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Segoe UI Variable Text", "Segoe UI", "Arial"])
		_font.font_weight = 500
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font.hinting = TextServer.HINTING_LIGHT
		_bold = SystemFont.new()
		_bold.font_names = PackedStringArray(["Segoe UI Variable Display", "Segoe UI", "Arial"])
		_bold.font_weight = 650
		_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _bold if bold else _font


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 18

	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "TooltipPanel", tooltip_style())
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 16)

	theme.set_stylebox("normal", "Button", button_style(Color(1, 1, 1, 0.0), Color(0, 0, 0, 0)))
	theme.set_stylebox("hover", "Button", button_style(HOVER, Color(0, 0, 0, 0)))
	theme.set_stylebox("pressed", "Button", button_style(ACCENT_SOFT, ACCENT))
	theme.set_stylebox("hover_pressed", "Button", button_style(ACCENT_SOFT, ACCENT))
	theme.set_stylebox("disabled", "Button", button_style(Color(1, 1, 1, 0.0), Color(0, 0, 0, 0)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_MUTED, 0.5))
	theme.set_font("font", "Button", font(true))
	theme.set_font_size("font_size", "Button", 17)

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.93, 0.86, 0.81)
	slider_track.set_corner_radius_all(4)
	slider_track.content_margin_top = 3.0
	slider_track.content_margin_bottom = 3.0
	theme.set_stylebox("slider", "HSlider", slider_track)
	var slider_fill: StyleBoxFlat = slider_track.duplicate()
	slider_fill.bg_color = ACCENT
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	theme.set_icon("grabber", "HSlider", _dot_icon(22, Color.WHITE, ACCENT))
	theme.set_icon("grabber_highlight", "HSlider", _dot_icon(24, Color.WHITE, ACCENT))
	_theme = theme
	return theme


static func panel_style(radius: int = RADIUS, padding: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.shadow_color = SHADOW
	style.shadow_size = 14
	style.shadow_offset = Vector2(0.0, 4.0)
	style.anti_aliasing_size = 1.2
	return style


static func tooltip_style() -> StyleBoxFlat:
	var style := panel_style(12, 8.0)
	style.bg_color = PANEL_SOLID
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


static func button_style(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.anti_aliasing_size = 1.2
	return style


## A small "keycap" label showing a hotkey.
static func keycap(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font(true))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.9, 0.85)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 1.0
	label.add_theme_stylebox_override("normal", style)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func caption(text: String, muted: bool = true, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_MUTED if muted else TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _dot_icon(size: int, fill: Color, ring: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) - center, float(y) - center).length()
			var r: float = float(size) * 0.5 - 1.0
			var color := Color(0, 0, 0, 0)
			if d <= r:
				color = ring if d > r - 3.0 else fill
				color.a = clampf(r - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
