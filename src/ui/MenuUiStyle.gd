extends RefCounted
class_name MenuUiStyle

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")

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
	SKIN.apply_button(button, UI.GOLD if selected else accent)
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
	button.tooltip_text = tooltip
	SKIN.apply_button(button, accent)
	return button

static func safe_frame_layout(viewport: Viewport, max_size: Vector2, breakpoint: float = 840.0) -> Dictionary:
	var physical: Vector2 = UI.physical_window_size(viewport)
	var scale_factor: float = UI.ui_scale(viewport)
	var compact: bool = UI.is_compact(viewport, breakpoint)
	var edge: float = 14.0 if compact else 28.0
	var width: float = minf(max_size.x, maxf(1.0, physical.x - edge * 2.0))
	var height: float = minf(max_size.y, maxf(1.0, physical.y - edge * 2.0))
	var origin: Vector2 = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	return {"compact": compact, "scale": scale_factor, "position": origin, "size": Vector2(width, height)}

static func apply_safe_frame(frame: Control, viewport: Viewport, max_size: Vector2, breakpoint: float = 840.0) -> Dictionary:
	var layout: Dictionary = safe_frame_layout(viewport, max_size, breakpoint)
	if frame != null:
		frame.scale = Vector2.ONE * float(layout["scale"])
		frame.position = layout["position"] as Vector2
		frame.size = layout["size"] as Vector2
		frame.clip_contents = true
	return layout

static func margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", left)
	result.add_theme_constant_override("margin_top", top)
	result.add_theme_constant_override("margin_right", right)
	result.add_theme_constant_override("margin_bottom", bottom)
	return result
