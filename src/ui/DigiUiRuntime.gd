extends Node

# Runtime presentation layer for DigiGame UI.
#
# This keeps text, layout and localization-friendly Controls intact while
# applying a reusable dark sci-fi skin derived from the visual language of
# Kenney's CC0 UI Pack - Sci-Fi. The art remains separate from translated text.

const UI = preload("res://src/ui/TacticalTheme.gd")
const PANEL_TEXTURE_PATH := "res://assets/ui/kenney_scifi_dark/panel.svg"
const PANEL_STRONG_TEXTURE_PATH := "res://assets/ui/kenney_scifi_dark/panel_strong.svg"
const BUTTON_NORMAL_TEXTURE_PATH := "res://assets/ui/kenney_scifi_dark/button_normal.svg"
const BUTTON_HOVER_TEXTURE_PATH := "res://assets/ui/kenney_scifi_dark/button_hover.svg"
const BUTTON_PRESSED_TEXTURE_PATH := "res://assets/ui/kenney_scifi_dark/button_pressed.svg"

const PANEL_NAMES_STRONG := [
	"BattleDialog",
	"EscapeDialog",
	"EscapeResult",
	"InteractionPrompt",
	"ActiveUnitStatus",
	"TechniqueMenu",
]

const PANEL_NAME_HINTS := [
	"Panel",
	"Dock",
	"Rail",
	"Bar",
	"Dialog",
	"Prompt",
	"Status",
	"Timeline",
	"Overlay",
]

var _panel_texture: Texture2D = null
var _panel_strong_texture: Texture2D = null
var _button_normal_texture: Texture2D = null
var _button_hover_texture: Texture2D = null
var _button_pressed_texture: Texture2D = null
var _skin_ready := false


func _ready() -> void:
	_load_skin_resources()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_decorate_existing_tree")


func _load_skin_resources() -> void:
	_panel_texture = load(PANEL_TEXTURE_PATH) as Texture2D
	_panel_strong_texture = load(PANEL_STRONG_TEXTURE_PATH) as Texture2D
	_button_normal_texture = load(BUTTON_NORMAL_TEXTURE_PATH) as Texture2D
	_button_hover_texture = load(BUTTON_HOVER_TEXTURE_PATH) as Texture2D
	_button_pressed_texture = load(BUTTON_PRESSED_TEXTURE_PATH) as Texture2D
	_skin_ready = (
		_panel_texture != null
		and _panel_strong_texture != null
		and _button_normal_texture != null
		and _button_hover_texture != null
		and _button_pressed_texture != null
	)
	if not _skin_ready:
		push_warning("Digi UI Dark skin resources could not be loaded; keeping the base TacticalTheme presentation.")


func _decorate_existing_tree() -> void:
	if not _skin_ready:
		return
	var scene: Node = get_tree().current_scene
	if scene != null:
		_decorate_branch(scene)


func _decorate_branch(node: Node) -> void:
	_decorate_node(node)
	for child: Node in node.get_children():
		_decorate_branch(child)


func _on_node_added(node: Node) -> void:
	if _skin_ready:
		call_deferred("_decorate_node", node)


func _decorate_node(node: Node) -> void:
	if not _skin_ready or not is_instance_valid(node) or not node is Control:
		return
	var control: Control = node as Control
	if control.has_meta("digi_ui_dark_applied"):
		return

	if control is Button:
		_style_button(control as Button)
		_install_button_motion(control as Button)
		control.set_meta("digi_ui_dark_applied", true)
		return

	if control is PanelContainer or control is Panel:
		if _should_skin_panel(control):
			_style_panel(control)
			_install_panel_motion(control)
			control.set_meta("digi_ui_dark_applied", true)


func _should_skin_panel(control: Control) -> bool:
	var node_name: String = String(control.name)
	for strong_name: String in PANEL_NAMES_STRONG:
		if node_name == strong_name:
			return true
	for hint: String in PANEL_NAME_HINTS:
		if node_name.contains(hint):
			return true
	return false


func _style_panel(control: Control) -> void:
	var strong: bool = String(control.name) in PANEL_NAMES_STRONG
	var texture: Texture2D = _panel_strong_texture if strong else _panel_texture
	var style: StyleBoxTexture = _nine_patch(texture, Vector4(28.0, 24.0, 30.0, 24.0), Vector4(20.0, 16.0, 20.0, 16.0))
	control.add_theme_stylebox_override("panel", style)


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _nine_patch(_button_normal_texture, Vector4(22.0, 16.0, 22.0, 16.0), Vector4(15.0, 8.0, 15.0, 8.0)))
	button.add_theme_stylebox_override("hover", _nine_patch(_button_hover_texture, Vector4(22.0, 16.0, 22.0, 16.0), Vector4(15.0, 8.0, 15.0, 8.0)))
	button.add_theme_stylebox_override("pressed", _nine_patch(_button_pressed_texture, Vector4(22.0, 16.0, 22.0, 16.0), Vector4(15.0, 8.0, 15.0, 8.0)))
	button.add_theme_stylebox_override("hover_pressed", _nine_patch(_button_pressed_texture, Vector4(22.0, 16.0, 22.0, 16.0), Vector4(15.0, 8.0, 15.0, 8.0)))
	button.add_theme_stylebox_override("focus", UI.focus_outline(UI.CYAN, 7))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.42))
	button.add_theme_color_override("icon_hover_color", UI.CYAN)
	button.add_theme_color_override("icon_focus_color", UI.CYAN)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)


func _nine_patch(texture: Texture2D, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, margins.x)
	style.set_texture_margin(SIDE_TOP, margins.y)
	style.set_texture_margin(SIDE_RIGHT, margins.z)
	style.set_texture_margin(SIDE_BOTTOM, margins.w)
	style.set_content_margin(SIDE_LEFT, content.x)
	style.set_content_margin(SIDE_TOP, content.y)
	style.set_content_margin(SIDE_RIGHT, content.z)
	style.set_content_margin(SIDE_BOTTOM, content.w)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style


func _install_button_motion(button: Button) -> void:
	button.resized.connect(_refresh_pivot.bind(button))
	button.mouse_entered.connect(_animate_button.bind(button, true))
	button.mouse_exited.connect(_animate_button.bind(button, false))
	button.focus_entered.connect(_animate_button.bind(button, true))
	button.focus_exited.connect(_animate_button.bind(button, false))
	button.button_down.connect(_press_button.bind(button))
	button.button_up.connect(_release_button.bind(button))
	_refresh_pivot(button)


func _refresh_pivot(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5


func _animate_button(button: Button, active: bool) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.018, 1.018) if active else Vector2.ONE, 0.11)
	var target: Color = Color(1.04, 1.04, 1.04, 1.0) if active else Color.WHITE
	tween.parallel().tween_property(button, "modulate", target, 0.11)


func _press_button(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.985, 0.985), 0.065)


func _release_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween: Tween = button.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.13)


func _install_panel_motion(control: Control) -> void:
	control.visibility_changed.connect(_on_panel_visibility_changed.bind(control))
	if control.visible:
		call_deferred("_animate_panel_in", control)


func _on_panel_visibility_changed(control: Control) -> void:
	if is_instance_valid(control) and control.visible:
		_animate_panel_in(control)


func _animate_panel_in(control: Control) -> void:
	if not is_instance_valid(control) or not control.visible:
		return
	control.pivot_offset = control.size * 0.5
	control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	control.scale = Vector2(0.985, 0.985)
	var tween: Tween = control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", Color.WHITE, 0.18)
	tween.tween_property(control, "scale", Vector2.ONE, 0.20)
