extends HBoxContainer
class_name DigiSegmentedTabs

signal tab_selected(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _specs: Array[Dictionary] = []
var _buttons: Dictionary = {}
var _active_id := ""
var _compact := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_rebuild()


func configure(specs: Array[Dictionary], active_id: String) -> DigiSegmentedTabs:
	_specs = specs.duplicate(true)
	_active_id = active_id
	if is_inside_tree():
		_rebuild()
	return self


func set_active(tab_id: String) -> void:
	if _active_id == tab_id:
		return
	_active_id = tab_id
	_refresh_styles()


func get_active() -> String:
	return _active_id


func set_compact(compact: bool) -> void:
	_compact = compact
	if is_inside_tree():
		_refresh_styles()


func select_adjacent(direction: int) -> bool:
	if direction == 0 or _specs.size() < 2:
		return false
	var ids: Array[String] = []
	for spec: Dictionary in _specs:
		if bool(spec.get("enabled", true)):
			ids.append(String(spec.get("id", "")))
	if ids.size() < 2:
		return false
	var current := ids.find(_active_id)
	if current < 0:
		current = 0
	var next := posmod(current + (-1 if direction < 0 else 1), ids.size())
	var id := ids[next]
	if id == _active_id:
		return false
	tab_selected.emit(id)
	return true


func get_button(tab_id: String) -> Button:
	return _buttons.get(tab_id) as Button


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	for spec: Dictionary in _specs:
		var id := String(spec.get("id", ""))
		var button := Button.new()
		button.name = "Segment_%s" % id
		button.text = String(spec.get("label", id.to_upper()))
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 46.0 if _compact else 52.0
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = not bool(spec.get("enabled", true))
		button.add_theme_font_size_override("font_size", 12 if _compact else 14)
		V2.apply_heading(button)
		button.pressed.connect(func(): tab_selected.emit(id))
		add_child(button)
		_buttons[id] = button
	_refresh_styles()


func _refresh_styles() -> void:
	for spec: Dictionary in _specs:
		var id := String(spec.get("id", ""))
		var button := _buttons.get(id) as Button
		if button == null:
			continue
		var accent: Color = spec.get("accent", V2.CYAN)
		var active := id == _active_id
		button.custom_minimum_size.y = 46.0 if _compact else 52.0
		button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
		button.add_theme_color_override("font_hover_color", V2.WHITE)
		button.add_theme_color_override("font_pressed_color", V2.WHITE)
		button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
		button.add_theme_stylebox_override("normal", V2.hospital_button_style(accent, "focus" if active else "normal"))
		button.add_theme_stylebox_override("hover", V2.hospital_button_style(accent, "hover"))
		button.add_theme_stylebox_override("pressed", V2.hospital_button_style(accent, "pressed"))
		button.add_theme_stylebox_override("disabled", V2.hospital_button_style(accent, "disabled"))
