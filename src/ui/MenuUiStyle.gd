extends RefCounted
class_name MenuUiStyle

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")

const SAFE_EDGE_DESKTOP := 28.0
const SAFE_EDGE_COMPACT := 14.0

static func screen_frame() -> StyleBox:
	return SKIN.frame_style(UI.FRAME_DARK, Vector4.ZERO, 14.0)

static func surface(accent: Color = UI.CYAN, fill_alpha: float = 0.80, radius: int = 10) -> StyleBoxFlat:
	return UI.glass_panel(accent, fill_alpha, radius)

static func card(accent: Color, strong: bool = false, radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.020, 0.90 if strong else 0.72)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.48 if strong else 0.22)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

static func portrait(accent: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.36)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

static func stat_surface(accent: Color, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.40 if selected else 0.28)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.52 if selected else 0.24)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style

static func style_action_button(button: Button, accent: Color, selected: bool = false) -> void:
	if button == null:
		return
	SKIN.apply_button(button, accent)
	if selected:
		button.add_theme_stylebox_override("normal", SKIN.border_style(accent, Vector4(14.0, 8.0, 14.0, 8.0), 10.0))
	button.add_theme_color_override("font_disabled_color", UI.DISABLED)
	UI.apply_body_font(button)

static func action_button(text: String, accent: Color, minimum_height: float = 42.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = minimum_height
	button.add_theme_font_size_override("font_size", 12)
	style_action_button(button, accent)
	return button

static func icon_button(texture: Texture2D, accent: Color, tooltip: String, size: Vector2 = Vector2(44, 44)) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = size
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	SKIN.apply_button(button, accent)
	return button

static func safe_frame_layout(viewport: Viewport, max_size: Vector2 = Vector2(1240.0, 720.0), breakpoint: float = 840.0, desktop_edge: float = SAFE_EDGE_DESKTOP, compact_edge: float = SAFE_EDGE_COMPACT) -> Dictionary:
	var physical := UI.physical_window_size(viewport)
	var scale_factor := UI.ui_scale(viewport)
	var compact := UI.is_compact(viewport, breakpoint)
	var edge := compact_edge if compact else desktop_edge
	var available := Vector2(maxf(1.0, physical.x - edge * 2.0), maxf(1.0, physical.y - edge * 2.0))
	var frame_size := Vector2(minf(max_size.x, available.x), minf(max_size.y, available.y))
	var origin := Vector2((physical.x - frame_size.x) * 0.5, (physical.y - frame_size.y) * 0.5) * scale_factor
	return {"physical": physical, "scale": scale_factor, "compact": compact, "edge": edge, "size": frame_size, "position": origin}

static func apply_safe_frame(frame: Control, viewport: Viewport, max_size: Vector2 = Vector2(1240.0, 720.0), breakpoint: float = 840.0, desktop_edge: float = SAFE_EDGE_DESKTOP, compact_edge: float = SAFE_EDGE_COMPACT) -> Dictionary:
	var layout := safe_frame_layout(viewport, max_size, breakpoint, desktop_edge, compact_edge)
	if frame != null:
		frame.scale = Vector2.ONE * float(layout.get("scale", 1.0))
		frame.position = Vector2(layout.get("position", Vector2.ZERO))
		frame.size = Vector2(layout.get("size", max_size))
		frame.clip_contents = true
	return layout

static func margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", left)
	result.add_theme_constant_override("margin_top", top)
	result.add_theme_constant_override("margin_right", right)
	result.add_theme_constant_override("margin_bottom", bottom)
	return result
