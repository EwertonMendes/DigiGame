extends RefCounted
class_name TacticalTheme

const CYAN: Color = Color(0.12, 0.88, 1.0, 1.0)
const BLUE: Color = Color(0.18, 0.48, 1.0, 1.0)
const RED: Color = Color(1.0, 0.28, 0.24, 1.0)
const ORANGE: Color = Color(1.0, 0.48, 0.18, 1.0)
const PURPLE: Color = Color(0.64, 0.34, 1.0, 1.0)
const GREEN: Color = Color(0.20, 0.92, 0.62, 1.0)
const GOLD: Color = Color(1.0, 0.76, 0.18, 1.0)
const TEXT: Color = Color(0.96, 0.985, 1.0, 1.0)
const MUTED: Color = Color(0.66, 0.78, 0.86, 1.0)
const SUBTLE: Color = Color(0.44, 0.60, 0.70, 1.0)
const BASE: Color = Color(0.007, 0.024, 0.045, 0.965)
const BASE_SOFT: Color = Color(0.014, 0.045, 0.074, 0.94)
const DISABLED: Color = Color(0.30, 0.38, 0.44, 1.0)

const FONT_REGULAR_PATH := "res://assets/ui/fonts/Rajdhani-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/ui/fonts/Rajdhani-SemiBold.ttf"


static func uses_physical_touch_scale() -> bool:
	return DisplayServer.is_touchscreen_available()


static func ui_scale(viewport: Viewport) -> float:
	if viewport == null or not uses_physical_touch_scale():
		return 1.0
	var logical: Vector2 = viewport.get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return 1.0
	var scale_x: float = logical.x / maxf(float(window_size.x), 1.0)
	var scale_y: float = logical.y / maxf(float(window_size.y), 1.0)
	return maxf(1.0, maxf(scale_x, scale_y))


static func physical_window_size(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2(1280.0, 720.0)
	if not uses_physical_touch_scale():
		return viewport.get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(float(window_size.x), float(window_size.y))
	return viewport.get_visible_rect().size


static func is_compact(viewport: Viewport, width_breakpoint: float = 760.0) -> bool:
	var physical: Vector2 = physical_window_size(viewport)
	return physical.x < width_breakpoint or physical.y < 560.0


static func is_laptop(viewport: Viewport) -> bool:
	var physical: Vector2 = physical_window_size(viewport)
	return not is_compact(viewport) and physical.y < 780.0


static func px(viewport: Viewport, value: float) -> float:
	return value * ui_scale(viewport)


static func font_px(viewport: Viewport, value: float) -> int:
	return maxi(1, int(round(value * ui_scale(viewport))))


static func body_font() -> Font:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		return load(FONT_REGULAR_PATH) as Font
	return null


static func heading_font() -> Font:
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		return load(FONT_SEMIBOLD_PATH) as Font
	return body_font()


static func apply_body_font(control: Control) -> void:
	var font: Font = body_font()
	if font != null:
		control.add_theme_font_override("font", font)


static func apply_heading_font(control: Control) -> void:
	var font: Font = heading_font()
	if font != null:
		control.add_theme_font_override("font", font)


static func panel(accent: Color = CYAN, fill_alpha: float = 0.92, border_alpha: float = 0.48, radius: int = 10, shadow: int = 8) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = BASE
	bg.a = fill_alpha
	var border: Color = accent
	border.a = border_alpha
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


static func panel_strong(accent: Color = CYAN, radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel(accent, 0.975, 0.86, radius, 11)
	style.set_border_width_all(2)
	return style


static func pill(accent: Color, alpha: float = 0.12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = accent
	bg.a = alpha
	var border: Color = accent
	border.a = 0.54
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func action_style(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var working_accent: Color = accent
	var alpha: float = 0.11
	var border_alpha: float = 0.48
	var border_width: int = 1
	var shadow: int = 3
	match state:
		"hover":
			alpha = 0.22
			border_alpha = 0.92
			border_width = 2
			shadow = 7
		"pressed", "selected":
			alpha = 0.32
			border_alpha = 1.0
			border_width = 2
			shadow = 9
		"disabled":
			working_accent = DISABLED
			alpha = 0.07
			border_alpha = 0.22
			shadow = 0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg: Color = BASE_SOFT.lerp(working_accent, alpha)
	bg.a = 0.965
	var border: Color = working_accent
	border.a = border_alpha
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(working_accent.r, working_accent.g, working_accent.b, 0.24)
	style.shadow_size = shadow
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


static func separator(accent: Color = CYAN, alpha: float = 0.24) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)


static func rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return Color(0.24, 0.90, 1.0, 1.0)
		"champion": return Color(0.28, 0.88, 0.58, 1.0)
		"ultimate": return Color(0.78, 0.50, 1.0, 1.0)
		"mega": return Color(1.0, 0.72, 0.20, 1.0)
		"ultra": return Color(1.0, 0.34, 0.36, 1.0)
		"in-training", "training": return Color(0.58, 0.84, 1.0, 1.0)
		"fresh": return Color(0.76, 0.86, 0.94, 1.0)
	return CYAN
