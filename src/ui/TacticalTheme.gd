extends RefCounted
class_name TacticalTheme

# DigiGame HUD palette. The interface uses a dark translucent glass base and
# reserves brighter colors for state and gameplay meaning.
const CYAN: Color = Color(0.35, 0.86, 0.90, 1.0)
const BLUE: Color = Color(0.30, 0.63, 0.96, 1.0)
const RED: Color = Color(0.95, 0.34, 0.35, 1.0)
const ORANGE: Color = Color(0.98, 0.65, 0.18, 1.0)
const PURPLE: Color = Color(0.72, 0.53, 0.95, 1.0)
const GREEN: Color = Color(0.34, 0.82, 0.48, 1.0)
const GOLD: Color = Color(0.98, 0.76, 0.16, 1.0)
const TEXT: Color = Color(0.97, 0.98, 0.96, 1.0)
const MUTED: Color = Color(0.74, 0.78, 0.77, 1.0)
const SUBTLE: Color = Color(0.52, 0.57, 0.56, 1.0)
const BASE: Color = Color(0.025, 0.045, 0.045, 0.86)
const BASE_SOFT: Color = Color(0.055, 0.080, 0.078, 0.88)
const GLASS: Color = Color(0.035, 0.070, 0.066, 0.78)
const GLASS_LIGHT: Color = Color(0.075, 0.115, 0.108, 0.78)
const DISABLED: Color = Color(0.31, 0.35, 0.35, 1.0)

# Keep the platform/default sans-serif. It stays readable at small physical
# sizes and avoids the condensed dashboard look the old HUD had.
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


static func panel(accent: Color = GOLD, fill_alpha: float = 0.86, border_alpha: float = 0.20, radius: int = 10, shadow: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := BASE
	bg.a = fill_alpha
	var border := accent
	border.a = minf(border_alpha, 0.42)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = mini(shadow, 4)
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func glass_panel(accent: Color = GOLD, fill_alpha: float = 0.74, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := GLASS
	bg.a = fill_alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, 0.18)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func ribbon(accent: Color = GOLD, fill_alpha: float = 0.68) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := GLASS
	bg.a = fill_alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


static func panel_strong(accent: Color = GOLD, radius: int = 10) -> StyleBoxFlat:
	var style := glass_panel(accent, 0.88, radius)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.set_border_width_all(2)
	return style


static func pill(accent: Color, alpha: float = 0.10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := accent
	bg.a = alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, 0.28)
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


# Menu rows intentionally avoid the "web button" look. Normal rows blend into
# one translucent command sheet; hover/focus/selection becomes the game cursor.
static func command_style(accent: Color, state: String = "normal", compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(GLASS.r, GLASS.g, GLASS.b, 0.34)
	style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_width_left = 3
	match state:
		"hover", "focus":
			bg = Color(GLASS_LIGHT.r, GLASS_LIGHT.g, GLASS_LIGHT.b, 0.88)
			style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
		"pressed", "selected":
			bg = Color(accent.r, accent.g, accent.b, 0.82)
			style.border_color = Color(1.0, 1.0, 1.0, 0.90)
		"disabled":
			bg = Color(GLASS.r, GLASS.g, GLASS.b, 0.18)
			style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	style.bg_color = bg
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 13.0 if not compact else 10.0
	style.content_margin_right = 11.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func focus_outline(accent: Color = GOLD, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


static func turn_node_style(accent: Color, current: bool, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var alpha := 0.88 if current else 0.66
	style.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, alpha)
	var border_alpha := 0.88 if current else 0.34
	if state == "hover" or state == "focus":
		style.bg_color = Color(GLASS_LIGHT.r, GLASS_LIGHT.g, GLASS_LIGHT.b, 0.92)
		border_alpha = 0.95
	elif state == "pressed":
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.35)
		border_alpha = 1.0
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.set_border_width_all(2 if current else 1)
	var radius := 15 if current else 12
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 3 if current else 1
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


# Kept for secondary/context controls and older UI surfaces.
static func action_style(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(GLASS.r, GLASS.g, GLASS.b, 0.72)
	var border := Color(0.80, 0.84, 0.82, 0.18)
	var border_width := 1
	match state:
		"hover":
			bg = Color(GLASS_LIGHT.r, GLASS_LIGHT.g, GLASS_LIGHT.b, 0.92)
			border = Color(accent.r, accent.g, accent.b, 0.62)
		"pressed", "selected":
			bg = Color(accent.r, accent.g, accent.b, 0.25)
			border = Color(accent.r, accent.g, accent.b, 0.92)
			border_width = 2
		"disabled":
			bg = Color(GLASS.r, GLASS.g, GLASS.b, 0.34)
			border = Color(0.50, 0.52, 0.53, 0.08)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func separator(accent: Color = GOLD, alpha: float = 0.18) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)


static func rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return BLUE
		"champion": return GREEN
		"ultimate": return PURPLE
		"mega": return GOLD
		"ultra": return RED
		"in-training", "training": return Color(0.58, 0.70, 0.88, 1.0)
		"fresh": return MUTED
	return MUTED
