extends CanvasLayer

const TOUCH_BUTTON_SIZE_PX := 56.0
const TOUCH_CENTER_WIDTH_PX := 88.0
const TOUCH_MARGIN_PX := 16.0
const TOUCH_GAP_PX := 8.0
const CYAN := Color(0.12, 0.88, 1.0, 1.0)
const RED := Color(1.0, 0.30, 0.28, 1.0)

@onready var debug_button: Button = $Root/DebugButton
@onready var zoom_out_button: Button = $Root/ZoomOutButton
@onready var zoom_in_button: Button = $Root/ZoomInButton
@onready var center_button: Button = $Root/CenterButton
@onready var touch_hint: Label = $Root/TouchHint

var _camera: Camera2D

func _ready() -> void:
	_camera = get_tree().root.get_node_or_null("Main/DigimonController/MainCamera") as Camera2D
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
	_style_button(center_button, CYAN)
	_style_button(zoom_out_button, CYAN)
	_style_button(zoom_in_button, CYAN)
	_style_button(debug_button, RED)
	for button in [center_button, zoom_out_button, zoom_in_button, debug_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
	touch_hint.add_theme_color_override("font_color", Color(0.70, 0.86, 0.94, 0.92))

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _button_style(accent, 0.12, 0.46))
	button.add_theme_stylebox_override("hover", _button_style(accent, 0.24, 0.90))
	button.add_theme_stylebox_override("pressed", _button_style(accent, 0.36, 1.0))

func _button_style(accent: Color, alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.015, 0.05, 0.08, 0.90)
	bg = bg.lerp(accent, alpha)
	var border := accent
	border.a = border_alpha
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _layout_controls() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = viewport_size

	var ui_scale := maxf(
		viewport_size.x / maxf(window_size.x, 1.0),
		viewport_size.y / maxf(window_size.y, 1.0)
	)
	ui_scale = maxf(ui_scale, 1.0)

	var button_size := TOUCH_BUTTON_SIZE_PX * ui_scale
	var center_width := TOUCH_CENTER_WIDTH_PX * ui_scale
	var margin := TOUCH_MARGIN_PX * ui_scale
	var gap := TOUCH_GAP_PX * ui_scale
	var bottom := -margin
	var top := bottom - button_size

	zoom_in_button.offset_right = -margin
	zoom_in_button.offset_left = zoom_in_button.offset_right - button_size
	zoom_in_button.offset_bottom = bottom
	zoom_in_button.offset_top = top

	zoom_out_button.offset_right = zoom_in_button.offset_left - gap
	zoom_out_button.offset_left = zoom_out_button.offset_right - button_size
	zoom_out_button.offset_bottom = bottom
	zoom_out_button.offset_top = top

	center_button.offset_right = zoom_out_button.offset_left - gap
	center_button.offset_left = center_button.offset_right - center_width
	center_button.offset_bottom = bottom
	center_button.offset_top = top

	var debug_margin := 14.0 * ui_scale
	debug_button.offset_right = -debug_margin
	debug_button.offset_left = debug_button.offset_right - 150.0 * ui_scale
	debug_button.offset_top = debug_margin
	debug_button.offset_bottom = debug_button.offset_top + 48.0 * ui_scale

	zoom_out_button.add_theme_font_size_override("font_size", int(round(24.0 * ui_scale)))
	zoom_in_button.add_theme_font_size_override("font_size", int(round(24.0 * ui_scale)))
	center_button.add_theme_font_size_override("font_size", int(round(14.0 * ui_scale)))
	debug_button.add_theme_font_size_override("font_size", int(round(16.0 * ui_scale)))

	var touch_layout := ui_scale > 1.15 or DisplayServer.is_touchscreen_available()
	touch_hint.visible = touch_layout
	if touch_layout:
		var hint_bottom := -(TOUCH_MARGIN_PX + TOUCH_BUTTON_SIZE_PX + 12.0) * ui_scale
		touch_hint.offset_left = 14.0 * ui_scale
		touch_hint.offset_right = minf(360.0 * ui_scale, viewport_size.x - 14.0 * ui_scale)
		touch_hint.offset_bottom = hint_bottom
		touch_hint.offset_top = hint_bottom - 36.0 * ui_scale
		touch_hint.add_theme_font_size_override("font_size", int(round(14.0 * ui_scale)))
		touch_hint.add_theme_constant_override("outline_size", int(round(4.0 * ui_scale)))

func _on_debug_toggled(enabled: bool) -> void:
	GlobalVariables.DebugMode = enabled
	_refresh_label()

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
	var accent := Color(1.0, 0.76, 0.16, 1.0) if GlobalVariables.DebugMode else RED
	_style_button(debug_button, accent)
