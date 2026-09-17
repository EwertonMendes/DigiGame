extends HBoxContainer
class_name DigiPager

signal page_delta_requested(delta: int)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _previous: Button
var _next: Button
var _label: Label
var _page := 0
var _page_count := 1


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 46.0
	add_theme_constant_override("separation", 12)
	_build()
	_refresh()


func configure(page: int, page_count: int) -> DigiPager:
	_page_count = maxi(1, page_count)
	_page = clampi(page, 0, _page_count - 1)
	if _label != null:
		_refresh()
	return self


func set_compact(compact: bool) -> void:
	custom_minimum_size.y = 40.0 if compact else 46.0
	if _previous != null:
		var side := 38.0 if compact else 44.0
		_previous.custom_minimum_size = Vector2(side, side)
		_next.custom_minimum_size = Vector2(side, side)


func get_page() -> int:
	return _page


func get_page_count() -> int:
	return _page_count


func _build() -> void:
	_previous = _nav_button("‹", -1)
	_previous.name = "PreviousPage"
	add_child(_previous)

	_label = Label.new()
	_label.name = "PageIndicator"
	_label.custom_minimum_size.x = 64.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_heading(_label)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_next = _nav_button("›", 1)
	_next.name = "NextPage"
	add_child(_next)


func _nav_button(copy: String, delta: int) -> Button:
	var button := Button.new()
	button.text = copy
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", V2.MUTED)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_stylebox_override("normal", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.62), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.56), 8))
	button.add_theme_stylebox_override("hover", V2.button_style(V2.CYAN, "hover", 8))
	button.add_theme_stylebox_override("pressed", V2.button_style(V2.CYAN, "pressed", 8))
	button.pressed.connect(func(): page_delta_requested.emit(delta))
	return button


func _refresh() -> void:
	_label.text = "%d / %d" % [_page + 1, _page_count]
	var multi := _page_count > 1
	_previous.visible = multi
	_next.visible = multi
	_label.visible = multi
	_previous.disabled = not multi
	_next.disabled = not multi
