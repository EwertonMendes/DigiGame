extends CanvasLayer

const UI = preload("res://src/ui/TacticalTheme.gd")
const DESKTOP_BUTTON := 42.0
const COMPACT_BUTTON := 38.0

@onready var debug_button: Button = $Root/DebugButton
@onready var zoom_out_button: Button = $Root/ZoomOutButton
@onready var zoom_in_button: Button = $Root/ZoomInButton
@onready var center_button: Button = $Root/CenterButton
@onready var touch_hint: Label = $Root/TouchHint

var _camera: Camera2D = null
var _battle_controller: Node = null


func _ready() -> void:
	_camera = get_tree().root.get_node_or_null("Main/DigimonController/MainCamera") as Camera2D
	_battle_controller = get_tree().root.get_node_or_null("Main/BattleController")
	debug_button.button_pressed = GlobalVariables.DebugMode
	debug_button.toggled.connect(_on_debug_toggled)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	center_button.pressed.connect(_on_center_pressed)
	get_viewport().size_changed.connect(_layout_controls)
	_style_controls()
	_refresh_label()
	call_deferred("_layout_controls")


func _style_controls() -> void:
	_style_button(center_button, UI.CYAN)
	_style_button(zoom_out_button, UI.CYAN)
	_style_button(zoom_in_button, UI.CYAN)
	_style_button(debug_button, UI.RED)
	center_button.text = "◎"
	zoom_out_button.text = "−"
	zoom_in_button.text = "+"
	for button in [center_button, zoom_out_button, zoom_in_button, debug_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", UI.TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	touch_hint.add_theme_color_override("font_color", Color(0.66, 0.82, 0.90, 0.74))
	touch_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.92))
	touch_hint.add_theme_constant_override("outline_size", 3)


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))


func _layout_controls() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var compact := viewport.x < 760.0
	var button_size := COMPACT_BUTTON if compact else DESKTOP_BUTTON
	var gap := 5.0
	var margin := 10.0 if compact else 14.0

	debug_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_button.offset_right = -margin
	debug_button.offset_left = debug_button.offset_right - (100.0 if compact else 112.0)
	debug_button.offset_top = 12.0
	debug_button.offset_bottom = 44.0 if compact else 46.0
	debug_button.add_theme_font_size_override("font_size", 9 if compact else 10)

	for button in [center_button, zoom_out_button, zoom_in_button]:
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		button.size = Vector2(button_size, button_size)
		button.add_theme_font_size_override("font_size", 18 if button != center_button else 17)

	var utility_bottom := -margin
	if compact:
		# Keep camera tools above the touch action dock instead of competing with it.
		utility_bottom = -(116.0 + margin)
	zoom_in_button.offset_right = -margin
	zoom_in_button.offset_left = zoom_in_button.offset_right - button_size
	zoom_in_button.offset_bottom = utility_bottom
	zoom_in_button.offset_top = utility_bottom - button_size
	zoom_out_button.offset_right = zoom_in_button.offset_left - gap
	zoom_out_button.offset_left = zoom_out_button.offset_right - button_size
	zoom_out_button.offset_bottom = utility_bottom
	zoom_out_button.offset_top = utility_bottom - button_size
	center_button.offset_right = zoom_out_button.offset_left - gap
	center_button.offset_left = center_button.offset_right - button_size
	center_button.offset_bottom = utility_bottom
	center_button.offset_top = utility_bottom - button_size

	var touch_layout := compact or DisplayServer.is_touchscreen_available()
	touch_hint.visible = touch_layout or GlobalVariables.DebugMode
	if touch_hint.visible:
		touch_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		touch_hint.offset_left = margin
		touch_hint.offset_right = minf(viewport.x - 108.0, 330.0)
		touch_hint.offset_bottom = -(112.0 if compact else 16.0)
		touch_hint.offset_top = touch_hint.offset_bottom - 24.0
		touch_hint.add_theme_font_size_override("font_size", 9 if compact else 10)


func _on_debug_toggled(enabled: bool) -> void:
	if _battle_controller != null and _battle_controller.has_method("set_debug_mode"):
		_battle_controller.call("set_debug_mode", enabled)
	else:
		GlobalVariables.DebugMode = enabled
	_refresh_label()
	_layout_controls()


func _on_zoom_out_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_out"):
		_camera.call("zoom_out")


func _on_zoom_in_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_in"):
		_camera.call("zoom_in")


func _on_center_pressed() -> void:
	if _camera != null and _camera.has_method("reset_view"):
		_camera.call("reset_view")


func _refresh_label() -> void:
	debug_button.text = "DEBUG  ON" if GlobalVariables.DebugMode else "DEBUG  OFF"
	var accent := UI.GOLD if GlobalVariables.DebugMode else UI.RED
	_style_button(debug_button, accent)
	if GlobalVariables.DebugMode:
		touch_hint.text = "DEBUG • select any Digimon, then choose a free tile"
	else:
		touch_hint.text = "Drag route • two-finger pan/pinch"
