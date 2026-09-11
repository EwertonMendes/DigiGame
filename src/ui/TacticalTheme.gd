extends RefCounted
class_name TacticalTheme

# Kenney-inspired dark-mode surfaces. Structural chrome stays dark and quiet;
# orange/gold is reserved for focused, selected or otherwise active UI states.
const CYAN: Color = Color(0.38, 0.79, 0.97, 1.0)
const BLUE: Color = Color(0.31, 0.47, 1.0, 1.0)
const RED: Color = Color(1.0, 0.40, 0.49, 1.0)
const ORANGE: Color = Color(1.0, 0.56, 0.32, 1.0)
const PURPLE: Color = Color(0.60, 0.49, 1.0, 1.0)
const GREEN: Color = Color(0.39, 0.86, 0.61, 1.0)
const GOLD: Color = Color(1.0, 0.69, 0.29, 1.0)
const TEXT: Color = Color(0.96, 0.97, 1.0, 1.0)
const MUTED: Color = Color(0.72, 0.73, 0.77, 1.0)
const SUBTLE: Color = Color(0.53, 0.54, 0.58, 1.0)
const BASE: Color = Color(0.015, 0.017, 0.022, 0.82)
const BASE_SOFT: Color = Color(0.028, 0.030, 0.038, 0.78)
const GLASS: Color = Color(0.018, 0.020, 0.026, 0.70)
const GLASS_LIGHT: Color = Color(0.11, 0.11, 0.12, 0.74)
const DISABLED: Color = Color(0.27, 0.28, 0.30, 1.0)
# Sampled from the normal dark Kenney panel presentation in the reference UI.
const FRAME_DARK: Color = Color(0.118, 0.149, 0.184, 1.0)


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


static func panel(_accent: Color = BLUE, fill_alpha: float = 0.76, border_alpha: float = 0.24, radius: int = 8, _shadow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BASE.r, BASE.g, BASE.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, minf(maxf(border_alpha, 0.28), 0.92))
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func glass_panel(_accent: Color = BLUE, fill_alpha: float = 0.70, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.88)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func ribbon(_accent: Color = GOLD, fill_alpha: float = 0.64) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BASE_SOFT.r, BASE_SOFT.g, BASE_SOFT.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.88)
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


static func panel_strong(_accent: Color = BLUE, radius: int = 9) -> StyleBoxFlat:
	var style := glass_panel(Color.WHITE, 0.78, radius)
	style.border_color = FRAME_DARK
	style.set_border_width_all(1)
	return style


static func pill(_accent: Color, alpha: float = 0.10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, clampf(alpha + 0.20, 0.24, 0.42))
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.94)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func command_style(accent: Color, state: String = "normal", compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.0, 0.0, 0.0, 0.10)
	var edge := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.0)
	match state:
		"hover", "focus":
			bg = Color(0.0, 0.0, 0.0, 0.28)
			edge = Color(accent.r, accent.g, accent.b, 0.82)
		"pressed", "selected":
			bg = Color(0.0, 0.0, 0.0, 0.38)
			edge = Color(accent.r, accent.g, accent.b, 1.0)
		"disabled":
			bg = Color(0.0, 0.0, 0.0, 0.04)
	style.bg_color = bg
	style.border_color = edge
	style.border_width_left = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14.0 if not compact else 11.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func focus_outline(accent: Color = GOLD, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.98)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	return style


static func turn_node_style(accent: Color, current: bool, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72 if current else 0.48)
	var border := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.90)
	if current:
		border = Color(accent.r, accent.g, accent.b, 0.88)
	if state == "hover" or state == "focus":
		style.bg_color = Color(0.0, 0.0, 0.0, 0.66)
		border = Color(accent.r, accent.g, accent.b, 0.94)
	elif state == "pressed":
		style.bg_color = Color(0.0, 0.0, 0.0, 0.76)
		border = Color(accent.r, accent.g, accent.b, 1.0)
	style.border_color = border
	style.set_border_width_all(1)
	var radius := 12 if current else 10
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func action_style(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.0, 0.0, 0.0, 0.50)
	var border := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.92)
	match state:
		"hover", "focus":
			bg = Color(0.0, 0.0, 0.0, 0.62)
			border = Color(accent.r, accent.g, accent.b, 0.86)
		"pressed", "selected":
			bg = Color(0.0, 0.0, 0.0, 0.72)
			border = Color(accent.r, accent.g, accent.b, 1.0)
		"disabled":
			bg = Color(0.0, 0.0, 0.0, 0.24)
			border = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.34)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func separator(_accent: Color = BLUE, alpha: float = 0.20) -> Color:
	return Color(1.0, 1.0, 1.0, alpha)


static func rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return CYAN
		"champion": return GREEN
		"ultimate": return PURPLE
		"mega": return GOLD
		"ultra": return RED
		"in-training", "training": return Color(0.56, 0.68, 0.96, 1.0)
		"fresh": return MUTED
	return MUTED
