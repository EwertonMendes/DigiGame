extends CanvasLayer

const UI = preload("res://src/ui/TacticalTheme.gd")
const ICON_ROOT := "res://assets/ui/icons"
const DESKTOP_BUTTON := 42.0
const COMPACT_BUTTON := 40.0

@onready var debug_button: Button = $Root/DebugButton
@onready var zoom_out_button: Button = $Root/ZoomOutButton
@onready var zoom_in_button: Button = $Root/ZoomInButton
@onready var center_button: Button = $Root/CenterButton
@onready var touch_hint: Label = $Root/TouchHint

var _camera: Camera2D = null
var _battle_controller: Node = null
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO


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
	set_process(true)
	call_deferred("_layout_controls")


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout_controls()


func _style_controls() -> void:
	_style_button(center_button, UI.CYAN)
	_style_button(zoom_out_button, UI.CYAN)
	_style_button(zoom_in_button, UI.CYAN)
	_style_button(debug_button, UI.RED)
	center_button.text = ""
	center_button.icon = load("%s/center.svg" % ICON_ROOT) as Texture2D
	center_button.expand_icon = true
	center_button.icon_max_width = 19
	zoom_out_button.text = "-"
	zoom_in_button.text = "+"
	for button in [center_button, zoom_out_button, zoom_in_button, debug_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", UI.TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	center_button.add_theme_color_override("icon_normal_color", UI.CYAN)
	center_button.add_theme_color_override("icon_hover_color", Color.WHITE)
	touch_hint.add_theme_color_override("font_color", Color(0.66, 0.82, 0.90, 0.82))
	touch_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.92))
	touch_hint.add_theme_constant_override("outline_size", 3)


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))


func _layout_controls() -> void:
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := physical.x < 760.0
	var button_size := COMPACT_BUTTON if compact else DESKTOP_BUTTON
	var margin := 10.0 if compact else 14.0
	var gap := 5.0

	var debug_width := 100.0 if compact else 112.0
	var debug_height := 32.0 if compact else 34.0
	debug_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_button.scale = Vector2.ONE * ui_scale
	debug_button.position = Vector2((physical.x - debug_width - margin) * ui_scale, 10.0 * ui_scale)
	debug_button.size = Vector2(debug_width, debug_height)
	debug_button.add_theme_font_size_override("font_size", 9 if compact else 10)

	for button in [center_button, zoom_out_button, zoom_in_button]:
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.scale = Vector2.ONE * ui_scale
		button.size = Vector2(button_size, button_size)
		button.add_theme_font_size_override("font_size", 18)

	var utility_y := physical.y - margin - button_size
	if compact:
		utility_y = physical.y - 116.0 - margin - button_size
	var zoom_in_x := physical.x - margin - button_size
	var zoom_out_x := zoom_in_x - gap - button_size
	var center_x := zoom_out_x - gap - button_size
	zoom_in_button.position = Vector2(zoom_in_x * ui_scale, utility_y * ui_scale)
	zoom_out_button.position = Vector2(zoom_out_x * ui_scale, utility_y * ui_scale)
	center_button.position = Vector2(center_x * ui_scale, utility_y * ui_scale)

	var touch_layout := compact or DisplayServer.is_touchscreen_available()
	touch_hint.visible = touch_layout or GlobalVariables.DebugMode
	if touch_hint.visible:
		touch_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
		touch_hint.scale = Vector2.ONE * ui_scale
		var hint_width := minf(330.0, maxf(160.0, physical.x - 130.0))
		var hint_y := physical.y - (145.0 if compact else 34.0)
		touch_hint.position = Vector2(margin * ui_scale, hint_y * ui_scale)
		touch_hint.size = Vector2(hint_width, 24.0)
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
