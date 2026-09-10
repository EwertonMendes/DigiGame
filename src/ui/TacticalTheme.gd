extends RefCounted
class_name TacticalTheme

# Minimal battle palette. Strong colors are reserved for meaning instead of
# decorating every control: amber = focus/current action, red = enemy/danger,
# green = HP/success and blue = SP/information.
const CYAN: Color = Color(0.96, 0.68, 0.18, 1.0)
const BLUE: Color = Color(0.30, 0.60, 0.96, 1.0)
const RED: Color = Color(0.94, 0.28, 0.30, 1.0)
const ORANGE: Color = Color(0.96, 0.68, 0.18, 1.0)
const PURPLE: Color = Color(0.96, 0.68, 0.18, 1.0)
const GREEN: Color = Color(0.28, 0.80, 0.48, 1.0)
const GOLD: Color = Color(0.96, 0.68, 0.18, 1.0)
const TEXT: Color = Color(0.96, 0.96, 0.94, 1.0)
const MUTED: Color = Color(0.70, 0.72, 0.72, 1.0)
const SUBTLE: Color = Color(0.47, 0.49, 0.50, 1.0)
const BASE: Color = Color(0.035, 0.040, 0.045, 0.94)
const BASE_SOFT: Color = Color(0.060, 0.066, 0.072, 0.96)
const DISABLED: Color = Color(0.30, 0.32, 0.34, 1.0)

# Rajdhani is intentionally no longer applied to battle UI. Godot's default
# sans-serif font is substantially easier to read at small physical sizes and
# stays consistent in Web exports without adding another runtime dependency.
static func body_font() -> Font:
	return null


static func heading_font() -> Font:
	return null


static func apply_body_font(_control: Control) -> void:
	pass


static func apply_heading_font(_control: Control) -> void:
	pass


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


static func panel(accent: Color = CYAN, fill_alpha: float = 0.94, border_alpha: float = 0.28, radius: int = 10, shadow: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := BASE
	bg.a = fill_alpha
	var border := accent
	border.a = minf(border_alpha, 0.38)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = mini(shadow, 5)
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func panel_strong(accent: Color = CYAN, radius: int = 10) -> StyleBoxFlat:
	var style := panel(accent, 0.97, 0.58, radius, 4)
	style.set_border_width_all(2)
	return style


static func pill(accent: Color, alpha: float = 0.10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := accent
	bg.a = alpha
	var border := accent
	border.a = 0.34
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
	var style := StyleBoxFlat.new()
	var bg := BASE_SOFT
	var border := Color(0.72, 0.74, 0.75, 0.18)
	var border_width := 1
	match state:
		"hover":
			bg = BASE_SOFT.lightened(0.06)
			border = Color(accent.r, accent.g, accent.b, 0.56)
		"pressed", "selected":
			bg = BASE_SOFT.lerp(accent, 0.13)
			border = Color(accent.r, accent.g, accent.b, 0.90)
			border_width = 2
		"disabled":
			bg = Color(BASE_SOFT.r, BASE_SOFT.g, BASE_SOFT.b, 0.62)
			border = Color(0.50, 0.52, 0.53, 0.10)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func separator(accent: Color = CYAN, alpha: float = 0.18) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)


static func rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return BLUE
		"champion": return GREEN
		"ultimate": return Color(0.66, 0.48, 0.90, 1.0)
		"mega": return GOLD
		"ultra": return RED
		"in-training", "training": return Color(0.58, 0.70, 0.88, 1.0)
		"fresh": return MUTED
	return MUTED
