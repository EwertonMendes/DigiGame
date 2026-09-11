extends RefCounted
class_name TacticalTheme

# DigiGame visual language: deep indigo surfaces, electric blue / sky highlights
# and warm orange for decisive actions. Violet and mint are reserved for
# secondary state so the interface stays colorful without turning noisy.
const CYAN: Color = Color(0.38, 0.79, 0.97, 1.0)
const BLUE: Color = Color(0.31, 0.47, 1.0, 1.0)
const RED: Color = Color(1.0, 0.40, 0.49, 1.0)
const ORANGE: Color = Color(1.0, 0.56, 0.32, 1.0)
const PURPLE: Color = Color(0.60, 0.49, 1.0, 1.0)
const GREEN: Color = Color(0.39, 0.86, 0.61, 1.0)
const GOLD: Color = Color(1.0, 0.69, 0.29, 1.0)
const TEXT: Color = Color(0.96, 0.97, 1.0, 1.0)
const MUTED: Color = Color(0.68, 0.71, 0.81, 1.0)
const SUBTLE: Color = Color(0.45, 0.49, 0.61, 1.0)
const BASE: Color = Color(0.063, 0.078, 0.149, 0.94)
const BASE_SOFT: Color = Color(0.090, 0.114, 0.212, 0.94)
const GLASS: Color = Color(0.078, 0.102, 0.188, 0.88)
const GLASS_LIGHT: Color = Color(0.133, 0.169, 0.294, 0.94)
const DISABLED: Color = Color(0.24, 0.27, 0.38, 1.0)

# Keep the platform/default sans-serif. It stays readable at small physical
# sizes and avoids forcing the decorative border style into typography too.
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


static func panel(accent: Color = BLUE, fill_alpha: float = 0.90, border_alpha: float = 0.26, radius: int = 8, shadow: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := BASE
	bg.a = fill_alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, minf(border_alpha, 0.46))
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.01, 0.015, 0.04, 0.34)
	style.shadow_size = mini(shadow, 4)
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func glass_panel(accent: Color = BLUE, fill_alpha: float = 0.86, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := GLASS
	bg.a = fill_alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, 0.24)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.01, 0.015, 0.04, 0.30)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func ribbon(accent: Color = GOLD, fill_alpha: float = 0.76) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := BASE_SOFT
	bg.a = fill_alpha
	style.bg_color = bg
	style.border_color = Color(accent.r, accent.g, accent.b, 0.30)
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


static func panel_strong(accent: Color = BLUE, radius: int = 9) -> StyleBoxFlat:
	var style := glass_panel(accent, 0.94, radius)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.64)
	style.set_border_width_all(2)
	return style


static func pill(accent: Color, alpha: float = 0.14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.38)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


# Command rows stay deliberately understated. The ornate Kenney-derived frames
# are reserved for large surfaces and dialog actions, so the command rail can
# remain dense, readable and free from edge collisions.
static func command_style(accent: Color, state: String = "normal", compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(GLASS.r, GLASS.g, GLASS.b, 0.16)
	var edge := Color(accent.r, accent.g, accent.b, 0.0)
	var edge_width := 3
	match state:
		"hover", "focus":
			bg = Color(BLUE.r, BLUE.g, BLUE.b, 0.15)
			edge = Color(accent.r, accent.g, accent.b, 0.84)
		"pressed", "selected":
			bg = Color(accent.r, accent.g, accent.b, 0.22)
			edge = Color(accent.r, accent.g, accent.b, 0.96)
		"disabled":
			bg = Color(GLASS.r, GLASS.g, GLASS.b, 0.08)
			edge = Color(1.0, 1.0, 1.0, 0.0)
	style.bg_color = bg
	style.border_color = edge
	style.border_width_left = edge_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14.0 if not compact else 11.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func focus_outline(accent: Color = CYAN, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.94)
	style.set_border_width_all(2)
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
	var alpha := 0.93 if current else 0.76
	style.bg_color = Color(BASE_SOFT.r, BASE_SOFT.g, BASE_SOFT.b, alpha)
	var border_alpha := 0.90 if current else 0.34
	if state == "hover" or state == "focus":
		style.bg_color = Color(GLASS_LIGHT.r, GLASS_LIGHT.g, GLASS_LIGHT.b, 0.96)
		border_alpha = 0.95
	elif state == "pressed":
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
		border_alpha = 1.0
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.set_border_width_all(2 if current else 1)
	var radius := 13 if current else 10
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.01, 0.015, 0.04, 0.30)
	style.shadow_size = 3 if current else 1
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


# Secondary/context controls use a restrained colored edge. Major dialog buttons
# receive the Kenney-derived texture at runtime.
static func action_style(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(BASE_SOFT.r, BASE_SOFT.g, BASE_SOFT.b, 0.86)
	var border := Color(accent.r, accent.g, accent.b, 0.26)
	var border_width := 1
	match state:
		"hover", "focus":
			bg = Color(BLUE.r, BLUE.g, BLUE.b, 0.16)
			border = Color(accent.r, accent.g, accent.b, 0.72)
		"pressed", "selected":
			bg = Color(accent.r, accent.g, accent.b, 0.22)
			border = Color(accent.r, accent.g, accent.b, 0.94)
			border_width = 2
		"disabled":
			bg = Color(GLASS.r, GLASS.g, GLASS.b, 0.30)
			border = Color(0.45, 0.48, 0.58, 0.10)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func separator(accent: Color = BLUE, alpha: float = 0.22) -> Color:
	return Color(accent.r, accent.g, accent.b, alpha)


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
