extends RefCounted
class_name DigiUiTheme

# Digi UI V2 prototype palette. These values intentionally mirror the approved
# mock-up: almost-black navy foundations, restrained blue-grey borders and
# semantic colour only where it carries information.
const BaseUI = preload("res://src/ui/TacticalTheme.gd")

const BACKDROP := Color(0.018, 0.039, 0.061, 0.985)
const BASE := Color(0.031, 0.063, 0.094, 1.0)
const SURFACE := Color(0.047, 0.078, 0.110, 1.0)
const SURFACE_ALT := Color(0.067, 0.118, 0.165, 1.0)
const SURFACE_SOFT := Color(0.039, 0.070, 0.102, 1.0)
const SURFACE_HOVER := Color(0.075, 0.145, 0.196, 1.0)
const HEADER_SURFACE := Color(0.055, 0.098, 0.137, 1.0)
const PANEL_FILL := Color(0.035, 0.059, 0.082, 0.985)
const PANEL_DEEP := Color(0.022, 0.039, 0.055, 0.985)
const BORDER := Color(0.165, 0.239, 0.310, 0.95)
const BORDER_SOFT := Color(0.165, 0.239, 0.310, 0.52)
const TEXT := Color(0.863, 0.902, 0.945, 1.0)
const MUTED := Color(0.557, 0.631, 0.710, 1.0)
const SUBTLE := Color(0.373, 0.451, 0.533, 1.0)
const CYAN := Color(0.435, 0.851, 0.902, 1.0)
const BLUE := Color(0.412, 0.663, 0.965, 1.0)
const GREEN := Color(0.455, 0.835, 0.604, 1.0)
const AMBER := Color(1.000, 0.765, 0.353, 1.0)
const ORANGE := Color(0.941, 0.627, 0.369, 1.0)
const PURPLE := Color(0.655, 0.502, 0.875, 1.0)
const RED := Color(1.000, 0.467, 0.478, 1.0)
const WHITE := Color(0.985, 0.992, 1.0, 1.0)

const TOUCH_TARGET := 52.0
const CARD_RADIUS := 8
const SMALL_RADIUS := 6

# Hospital surfaces use the same palette as UI V2 with stronger edge light and
# enough opacity to keep text readable over the full-screen illustrated room.
static func hospital_panel_style(accent: Color = CYAN, selected: bool = false) -> StyleBoxFlat:
	var fill := Color(0.025, 0.055, 0.079, 0.91)
	var edge := Color(accent.r, accent.g, accent.b, 0.93 if selected else 0.44)
	var style := surface_style(fill, edge, 11)
	style.set_border_width_all(2 if selected else 1)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.34 if selected else 0.09)
	style.shadow_size = 14 if selected else 6
	return style


static func hospital_button_style(accent: Color, state: String) -> StyleBoxFlat:
	var selected := state == "focus" or state == "hover" or state == "pressed"
	var style := hospital_panel_style(accent, selected)
	style.bg_color = Color(0.035, 0.095, 0.127, 0.95) if selected else Color(0.034, 0.068, 0.097, 0.93)
	if state == "disabled":
		style.bg_color = Color(0.025, 0.045, 0.062, 0.78)
		style.border_color = Color(BORDER.r, BORDER.g, BORDER.b, 0.46)
		style.shadow_size = 0
	return style


# Workspace aliases make the approved full-screen menu language explicit.
# Existing Hospital callers keep their stable API while Digimon/DigiLab and
# future services no longer depend on a screen-specific style name.
static func workspace_panel_style(accent: Color = CYAN, selected: bool = false) -> StyleBoxFlat:
	return hospital_panel_style(accent, selected)


static func workspace_button_style(accent: Color, state: String) -> StyleBoxFlat:
	return hospital_button_style(accent, state)


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
		style.shadow_color = Color(0.0, 0.0, 0.0, clampf(shadow_strength, 0.0, 0.32))
		style.shadow_size = 5
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func panel_style(border: Color = BORDER_SOFT, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	return surface_style(PANEL_FILL, border, radius, Vector4.ZERO, 0.10)


static func header_strip_style(radius: int = SMALL_RADIUS) -> StyleBoxFlat:
	var style := surface_style(HEADER_SURFACE, Color(BORDER.r, BORDER.g, BORDER.b, 0.30), radius)
	style.border_width_bottom = 1
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	return style


static func outlined_surface(accent: Color, selected: bool = false, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var fill := Color(accent.r, accent.g, accent.b, 0.105) if selected else SURFACE
	var border := Color(accent.r, accent.g, accent.b, 0.96) if selected else BORDER_SOFT
	var style := surface_style(fill, border, radius)
	style.set_border_width_all(2 if selected else 1)
	if selected:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.17)
		style.shadow_size = 7
	return style


static func glass_style(
	accent: Color = CYAN,
	variant: String = "floating",
	content: Vector4 = Vector4.ZERO,
	radius: int = 10
) -> StyleBoxFlat:
	var fill_alpha := 0.72
	var tint_strength := 0.055
	var border_alpha := 0.42
	var shadow_alpha := 0.20
	var shadow_size := 10
	match variant:
		"modal":
			fill_alpha = 0.82
			tint_strength = 0.040
			border_alpha = 0.36
			shadow_alpha = 0.26
			shadow_size = 14
		"subtle":
			fill_alpha = 0.58
			tint_strength = 0.075
			border_alpha = 0.28
			shadow_alpha = 0.12
			shadow_size = 7
	var base := PANEL_DEEP
	var fill := Color(
		lerpf(base.r, accent.r, tint_strength),
		lerpf(base.g, accent.g, tint_strength),
		lerpf(base.b, accent.b, tint_strength),
		fill_alpha
	)
	var style := surface_style(
		fill,
		Color(accent.r, accent.g, accent.b, border_alpha),
		radius,
		content
	)
	style.border_blend = true
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 4.0 if variant == "modal" else 3.0)
	return style


static func button_style(accent: Color, state: String, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var fill := SURFACE
	var border := BORDER_SOFT
	var border_width := 1
	var shadow_alpha := 0.0
	match state:
		"hover":
			fill = SURFACE_HOVER
			border = Color(accent.r, accent.g, accent.b, 0.72)
		"focus":
			fill = Color(accent.r, accent.g, accent.b, 0.12)
			border = accent
			border_width = 2
			shadow_alpha = 0.12
		"pressed":
			fill = Color(accent.r, accent.g, accent.b, 0.16)
			border = Color(accent.r, accent.g, accent.b, 0.88)
		"selected":
			fill = Color(accent.r, accent.g, accent.b, 0.115)
			border = accent
			border_width = 2
			shadow_alpha = 0.14
		"disabled":
			fill = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.48)
			border = Color(BORDER.r, BORDER.g, BORDER.b, 0.26)
		_:
			pass
	var style := surface_style(fill, border, radius)
	style.set_border_width_all(border_width)
	if shadow_alpha > 0.0:
		style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
		style.shadow_size = 6
	return style


static func glass_button_style(accent: Color, state: String, radius: int = CARD_RADIUS) -> StyleBoxFlat:
	var fill_alpha := 0.40
	var accent_mix := 0.035
	var border_alpha := 0.32
	var border_width := 1
	var shadow_alpha := 0.0
	match state:
		"hover":
			fill_alpha = 0.54
			accent_mix = 0.060
			border_alpha = 0.58
		"focus":
			fill_alpha = 0.60
			accent_mix = 0.12
			border_alpha = 0.92
			border_width = 2
			shadow_alpha = 0.14
		"pressed":
			fill_alpha = 0.64
			accent_mix = 0.15
			border_alpha = 0.78
		"disabled":
			fill_alpha = 0.22
			accent_mix = 0.0
			border_alpha = 0.16
	var fill := Color(
		lerpf(SURFACE.r, accent.r, accent_mix),
		lerpf(SURFACE.g, accent.g, accent_mix),
		lerpf(SURFACE.b, accent.b, accent_mix),
		fill_alpha
	)
	var style := surface_style(
		fill,
		Color(accent.r, accent.g, accent.b, border_alpha),
		radius
	)
	style.set_border_width_all(border_width)
	style.border_blend = true
	if shadow_alpha > 0.0:
		style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
		style.shadow_size = 7
	return style


static func action_card_style(accent: Color, state: String) -> StyleBoxFlat:
	var alpha := 0.105
	var border_alpha := 0.58
	var shadow_alpha := 0.08
	match state:
		"hover":
			alpha = 0.155
			border_alpha = 0.88
			shadow_alpha = 0.14
		"focus":
			alpha = 0.17
			border_alpha = 1.0
			shadow_alpha = 0.18
		"pressed":
			alpha = 0.20
			border_alpha = 0.92
		"disabled":
			alpha = 0.045
			border_alpha = 0.22
			shadow_alpha = 0.0
	var style := surface_style(
		Color(
			PANEL_FILL.r * (1.0 - alpha) + accent.r * alpha,
			PANEL_FILL.g * (1.0 - alpha) + accent.g * alpha,
			PANEL_FILL.b * (1.0 - alpha) + accent.b * alpha,
			0.995
		),
		Color(accent.r, accent.g, accent.b, border_alpha),
		8
	)
	style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
	style.shadow_size = 7 if shadow_alpha > 0.0 else 0
	return style


static func tab_style(active: bool, emphasized: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SURFACE_ALT.r, SURFACE_ALT.g, SURFACE_ALT.b, 0.34 if active else (0.16 if emphasized else 0.0))
	if disabled:
		style.bg_color = Color.TRANSPARENT
	style.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.96 if active else (0.42 if emphasized else 0.0))
	style.border_width_bottom = 3 if active else 0
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func pill_style(accent: Color, active: bool = true) -> StyleBoxFlat:
	var fill_alpha := 0.15 if active else 0.06
	var border_alpha := 0.62 if active else 0.24
	return surface_style(
		Color(accent.r, accent.g, accent.b, fill_alpha),
		Color(accent.r, accent.g, accent.b, border_alpha),
		6,
		Vector4(10.0, 4.0, 10.0, 4.0)
	)


# Selection cards deliberately keep their silhouette and depth fixed across
# hover/focus/press. Navigation feedback is a restrained tint; committed
# selection is a persistent cyan highlight owned by screen state.
static func selection_card_style(
	accent: Color = CYAN,
	selected: bool = false,
	emphasized: bool = false,
	disabled: bool = false
) -> StyleBoxFlat:
	var fill := PANEL_FILL
	var edge := Color(BORDER.r, BORDER.g, BORDER.b, 0.52)
	if selected:
		fill = Color(
			lerpf(PANEL_FILL.r, accent.r, 0.13),
			lerpf(PANEL_FILL.g, accent.g, 0.13),
			lerpf(PANEL_FILL.b, accent.b, 0.13),
			0.995
		)
		edge = Color(accent.r, accent.g, accent.b, 0.96)
	elif emphasized:
		fill = Color(
			lerpf(PANEL_FILL.r, SURFACE_HOVER.r, 0.68),
			lerpf(PANEL_FILL.g, SURFACE_HOVER.g, 0.68),
			lerpf(PANEL_FILL.b, SURFACE_HOVER.b, 0.68),
			0.995
		)
		edge = Color(BORDER.r, BORDER.g, BORDER.b, 0.82)
	if disabled:
		fill = Color(PANEL_DEEP.r, PANEL_DEEP.g, PANEL_DEEP.b, 0.76)
		edge = Color(BORDER.r, BORDER.g, BORDER.b, 0.24)

	var style := surface_style(fill, edge, 9)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


static func progress_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.035, 0.049, 1.0)
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
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
		style.shadow_size = 4
	return style


static func separator_color(alpha: float = 0.36) -> Color:
	return Color(BORDER.r, BORDER.g, BORDER.b, clampf(alpha, 0.0, 1.0))
