extends RefCounted
class_name MenuUiStyle

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")

static func screen_frame() -> StyleBox:
	# Match the established Digimon menu: one quiet Kenney frame owns the screen.
	# Accent-heavy borders belong to focused content, not every container.
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
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.action_style(UI.GOLD if selected else accent, "focus"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(accent, "disabled"))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_focus_color", UI.TEXT)
	button.add_theme_color_override("font_pressed_color", UI.TEXT)
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

static func icon_button(texture: Texture2D, accent: Color, tooltip: String, size: Vector2 = Vector2(44, 40)) -> Button:
	var button := action_button("", accent, size.y)
	button.custom_minimum_size = size
	button.icon = texture
	button.expand_icon = true
	button.icon_max_width = int(minf(size.x, size.y) * 0.45)
	button.tooltip_text = tooltip
	return button

static func margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", left)
	result.add_theme_constant_override("margin_top", top)
	result.add_theme_constant_override("margin_right", right)
	result.add_theme_constant_override("margin_bottom", bottom)
	return result
