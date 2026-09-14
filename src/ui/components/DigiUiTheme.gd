extends RefCounted
class_name DigiUiTheme

# Digi UI V2: a quieter, game-first design language built entirely with Godot
# Control nodes and StyleBoxFlat resources. The palette intentionally avoids
# broad neon glows; color is reserved for state, stats and primary actions.
const BaseUI = preload("res://src/ui/TacticalTheme.gd")

const BACKDROP := Color(0.012, 0.025, 0.038, 0.94)
const BASE := Color(0.035, 0.067, 0.102, 0.985)
const SURFACE := Color(0.059, 0.106, 0.153, 0.98)
const SURFACE_ALT := Color(0.078, 0.133, 0.188, 0.98)
const SURFACE_SOFT := Color(0.048, 0.087, 0.124, 0.94)
const SURFACE_HOVER := Color(0.098, 0.173, 0.235, 0.98)
const BORDER := Color(0.184, 0.255, 0.322, 0.90)
const BORDER_SOFT := Color(0.184, 0.255, 0.322, 0.42)
const TEXT := Color(0.933, 0.953, 0.973, 1.0)
const MUTED := Color(0.616, 0.675, 0.733, 1.0)
const SUBTLE := Color(0.451, 0.518, 0.584, 1.0)
const CYAN := Color(0.388, 0.745, 0.812, 1.0)
const BLUE := Color(0.435, 0.663, 0.910, 1.0)
const GREEN := Color(0.424, 0.796, 0.576, 1.0)
const AMBER := Color(0.886, 0.706, 0.353, 1.0)
const ORANGE := Color(0.886, 0.596, 0.369, 1.0)
const PURPLE := Color(0.651, 0.518, 0.847, 1.0)
const RED := Color(0.847, 0.435, 0.467, 1.0)
const WHITE := Color(0.985, 0.990, 1.0, 1.0)

const TOUCH_TARGET := 52.0
const CARD_RADIUS := 12
const SMALL_RADIUS := 8


static func physical_window_size(viewport: Viewport) -> Vector2:
	return BaseUI.physical_window_size(viewport)


static func ui_scale(viewport: Viewport) -> float:
	return BaseUI.ui_scale(viewport)


static func is_compact(viewport: Viewport, width_breakpoint: float = 820.0) -> bool:
	return BaseUI.is_compact(viewport, width_breakpoint)


static func rank_color(rank: String) -> Color:
	return BaseUI.rank_color(rank)


static func apply_heading(control: Control) -> void:
	BaseUI.apply_heading_font(control)


static func apply_body(control: Control) -> void:
	BaseUI.apply_body_font(control)


static func apply_reading(control: Control) -> void:
	BaseUI.apply_reading_font(control)


static func surface_style(
	fill: Color = SURFACE,
	border: Color = BORDER_SOFT,
	radius: int = CARD_RADIUS,
	content: Vector4 = Vector4.ZERO,
	shadow_strength: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.set_content_margin(SIDE_LEFT, content.x)
	style.set_content_margin(SIDE_TOP, content.y)
	style.set_content_margin(SIDE_RIGHT, content.z)
	style.set_content_margin(SIDE_BOTTOM, content.w)
	if shadow_strength > 0.0:
		style.shadow_color = Color(0.0, 0.0, 0.0, clampf(shadow_strength, 0.0, 0.45))
		style.shadow_size = 8
		style.shadow_offset = Vector2(0.0, 3.0)
	return style


static func outlined_surface(accent: Color, selected: bool = false, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var fill := SURFACE_ALT if selected else SURFACE
	var alpha := 0.82 if selected else 0.34
	var style := surface_style(fill, Color(accent.r, accent.g, accent.b, alpha), radius)
	if selected:
		style.set_border_width_all(2)
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
		style.shadow_size = 7
	return style


static func button_style(accent: Color, state: String, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var fill := SURFACE
	var border := BORDER_SOFT
	var border_width := 1
	var shadow_alpha := 0.0
	match state:
		"hover":
			fill = SURFACE_HOVER
			border = Color(accent.r, accent.g, accent.b, 0.68)
		"focus":
			fill = SURFACE_ALT
			border = accent
			border_width = 2
			shadow_alpha = 0.13
		"pressed":
			fill = Color(
				SURFACE_ALT.r * 0.82,
				SURFACE_ALT.g * 0.82,
				SURFACE_ALT.b * 0.82,
				SURFACE_ALT.a
			)
			border = Color(accent.r, accent.g, accent.b, 0.84)
		"selected":
			fill = Color(
				SURFACE_ALT.r + accent.r * 0.045,
				SURFACE_ALT.g + accent.g * 0.045,
				SURFACE_ALT.b + accent.b * 0.045,
				0.99
			)
			border = accent
			border_width = 2
			shadow_alpha = 0.10
		"disabled":
			fill = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.48)
			border = Color(BORDER.r, BORDER.g, BORDER.b, 0.28)
		_:
			pass
	var style := surface_style(fill, border, radius)
	style.set_border_width_all(border_width)
	if shadow_alpha > 0.0:
		style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
		style.shadow_size = 6
	return style


static func pill_style(accent: Color, active: bool = true) -> StyleBoxFlat:
	var fill_alpha := 0.15 if active else 0.06
	var border_alpha := 0.62 if active else 0.24
	var style := surface_style(
		Color(accent.r, accent.g, accent.b, fill_alpha),
		Color(accent.r, accent.g, accent.b, border_alpha),
		7,
		Vector4(10.0, 4.0, 10.0, 4.0)
	)
	return style


static func progress_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.032, 0.047, 0.98)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


static func progress_fill_style(accent: Color, soft_glow: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if soft_glow:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
		style.shadow_size = 4
	return style


static func separator_color(alpha: float = 0.36) -> Color:
	return Color(BORDER.r, BORDER.g, BORDER.b, clampf(alpha, 0.0, 1.0))
