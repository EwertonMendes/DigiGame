extends RefCounted
class_name KenneyFantasySkin

# Shared asset-backed skin for DigiGame surfaces that use Kenney Fantasy UI
# Borders. Controls still own layout, input and text, but visible chrome comes
# from the vendored Kenney artwork rather than StyleBoxFlat geometry.

const UI = preload("res://src/ui/TacticalTheme.gd")
const FRAME_TEXTURE = preload("res://assets/ui/kenney_fantasy_digi/frame_original.svg")
const BORDER_TEXTURE = preload("res://assets/ui/kenney_fantasy_digi/panel-border-000.png")
const DIVIDER_TEXTURE = preload("res://assets/ui/kenney_fantasy_digi/divider-fade-000.png")


static func frame_style(
	tint: Color = UI.FRAME_DARK,
	content: Vector4 = Vector4.ZERO,
	texture_margin: float = 12.0
) -> StyleBoxTexture:
	return _texture_style(FRAME_TEXTURE, tint, content, texture_margin)


static func border_style(
	tint: Color = UI.GOLD,
	content: Vector4 = Vector4.ZERO,
	texture_margin: float = 12.0
) -> StyleBoxTexture:
	return _texture_style(BORDER_TEXTURE, tint, content, texture_margin)


static func progress_track_style() -> StyleBoxTexture:
	return frame_style(UI.FRAME_DARK, Vector4.ZERO, 6.0)


static func progress_fill_style(accent: Color) -> StyleBoxTexture:
	return frame_style(accent, Vector4.ZERO, 6.0)


static func apply_button(button: Button, accent: Color = UI.GOLD) -> void:
	if button == null:
		return
	var content := Vector4(16.0, 9.0, 16.0, 9.0)
	button.add_theme_stylebox_override("normal", frame_style(UI.FRAME_DARK, content))
	button.add_theme_stylebox_override("hover", frame_style(accent, content))
	button.add_theme_stylebox_override("focus", border_style(accent))
	button.add_theme_stylebox_override("pressed", frame_style(accent, content))
	button.add_theme_stylebox_override("hover_pressed", frame_style(accent, content))
	button.add_theme_stylebox_override(
		"disabled",
		frame_style(Color(UI.FRAME_DARK.r, UI.FRAME_DARK.g, UI.FRAME_DARK.b, 0.42), content)
	)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.44))
	button.add_theme_color_override("icon_normal_color", Color(0.90, 0.90, 0.92, 0.92))
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_focus_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent)


static func _texture_style(
	texture: Texture2D,
	tint: Color,
	content: Vector4,
	texture_margin: float
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.set_texture_margin(SIDE_LEFT, texture_margin)
	style.set_texture_margin(SIDE_TOP, texture_margin)
	style.set_texture_margin(SIDE_RIGHT, texture_margin)
	style.set_texture_margin(SIDE_BOTTOM, texture_margin)
	style.set_content_margin(SIDE_LEFT, content.x)
	style.set_content_margin(SIDE_TOP, content.y)
	style.set_content_margin(SIDE_RIGHT, content.z)
	style.set_content_margin(SIDE_BOTTOM, content.w)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style
