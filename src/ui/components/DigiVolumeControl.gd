extends Control
class_name DigiVolumeControl

signal value_changed(value: float)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

const VALUE_WIDTH := 58.0
const TRACK_HEIGHT := 7.0
const KNOB_RADIUS := 8.0

var _value := 1.0
var _dragging := false
var _percent: Label
var _compact := false


func _ready() -> void:
	custom_minimum_size = Vector2(290.0, 42.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE

	_percent = Label.new()
	_percent.name = "Percentage"
	_percent.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_percent.offset_left = -VALUE_WIDTH
	_percent.offset_right = 0.0
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.add_theme_font_size_override("font_size", 14)
	_percent.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(_percent)
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_percent)
	_refresh_label()
	queue_redraw()


func set_value(value: float, emit_change: bool = false) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	if is_equal_approx(_value, normalized):
		return
	_value = normalized
	_refresh_label()
	queue_redraw()
	if emit_change:
		value_changed.emit(_value)


func get_value() -> float:
	return _value


func adjust_steps(steps: int, step_size: float = 0.05) -> bool:
	var previous := _value
	set_value(_value + float(steps) * step_size, true)
	return not is_equal_approx(previous, _value)


func set_compact(enabled: bool) -> void:
	_compact = enabled
	custom_minimum_size = Vector2(205.0 if enabled else 290.0, 38.0 if enabled else 42.0)
	if _percent != null:
		_percent.add_theme_font_size_override("font_size", 12 if enabled else 14)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse.pressed
			if mouse.pressed:
				_set_from_pointer(mouse.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_pointer((event as InputEventMouseMotion).position.x)
		accept_event()


func _set_from_pointer(pointer_x: float) -> void:
	var track := _track_rect()
	if track.size.x <= 1.0:
		return
	set_value((pointer_x - track.position.x) / track.size.x, true)


func _draw() -> void:
	var track := _track_rect()
	var center_y := track.position.y + track.size.y * 0.5
	var radius := TRACK_HEIGHT * 0.5
	draw_style_box(_track_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.52), int(radius)), track)
	if _value > 0.0:
		var fill := Rect2(track.position, Vector2(track.size.x * _value, track.size.y))
		draw_style_box(_track_style(Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.90), int(radius)), fill)
	var knob_x := track.position.x + track.size.x * _value
	draw_circle(Vector2(knob_x, center_y), KNOB_RADIUS if not _compact else 7.0, V2.WHITE, true, -1.0, true)
	draw_circle(Vector2(knob_x, center_y), (KNOB_RADIUS + 3.0) if not _compact else 10.0, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.45), false, 2.0, true)


func _track_rect() -> Rect2:
	var right_edge := maxf(60.0, size.x - VALUE_WIDTH - 14.0)
	var width := maxf(40.0, right_edge - KNOB_RADIUS)
	return Rect2(Vector2(KNOB_RADIUS, (size.y - TRACK_HEIGHT) * 0.5), Vector2(width - KNOB_RADIUS, TRACK_HEIGHT))


func _track_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _refresh_label() -> void:
	if _percent != null:
		_percent.text = "%d%%" % int(round(_value * 100.0))
