extends Button
class_name DigiActionCard

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

var _title_text := "ACTION"
var _description_text := ""
var _footer_text := ""
var _icon_kind := "info"
var _accent := V2.CYAN
var _built := false


func configure(title: String, description: String, footer: String, icon_kind: String, accent: Color) -> DigiActionCard:
	_title_text = title
	_description_text = description
	_footer_text = footer
	_icon_kind = icon_kind
	_accent = accent
	if _built:
		_rebuild_content()
	return self


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(176.0, 132.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	text = ""
	_apply_styles()
	_rebuild_content()
	_built = true


func _apply_styles() -> void:
	add_theme_stylebox_override("normal", V2.action_card_style(_accent, "normal"))
	add_theme_stylebox_override("hover", V2.action_card_style(_accent, "hover"))
	add_theme_stylebox_override("focus", V2.action_card_style(_accent, "focus"))
	add_theme_stylebox_override("pressed", V2.action_card_style(_accent, "pressed"))
	add_theme_stylebox_override("hover_pressed", V2.action_card_style(_accent, "pressed"))
	add_theme_stylebox_override("disabled", V2.action_card_style(_accent, "disabled"))


func _rebuild_content() -> void:
	for child in get_children():
		child.queue_free()
	_apply_styles()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(top)

	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(_icon_kind, _accent, 2.0)
	top.add_child(icon)

	var title := Label.new()
	title.text = _title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", V2.WHITE)
	V2.apply_heading(title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(title)

	var description := Label.new()
	description.text = _description_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_reading(description)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(description)

	var separator := ColorRect.new()
	separator.custom_minimum_size.y = 1.0
	separator.color = Color(_accent.r, _accent.g, _accent.b, 0.25)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(separator)

	var footer := Label.new()
	footer.text = _footer_text
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", _accent)
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	V2.apply_heading(footer)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(footer)

	tooltip_text = "%s — %s" % [_title_text, _description_text]
