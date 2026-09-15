extends PanelContainer
class_name DigiSectionHeader

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

var _title_text := "SECTION"
var _trailing_text := ""
var _accent := V2.CYAN
var _icon_kind := ""
var _title_label: Label
var _trailing_label: Label
var _icon: DigiProceduralIcon
var _built := false


func configure(title: String, trailing: String = "", accent: Color = V2.CYAN, icon_kind: String = "") -> DigiSectionHeader:
	_title_text = title
	_trailing_text = trailing
	_accent = accent
	_icon_kind = icon_kind
	if _built:
		_apply_content()
	return self


func set_trailing(text: String) -> void:
	_trailing_text = text
	if _trailing_label != null:
		_trailing_label.text = _trailing_text
		_trailing_label.visible = not _trailing_text.is_empty()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 34.0
	add_theme_stylebox_override("panel", V2.header_strip_style(7))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	_icon = IconScript.new() as DigiProceduralIcon
	_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(_title_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title_label)

	_trailing_label = Label.new()
	_trailing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trailing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trailing_label.add_theme_font_size_override("font_size", 9)
	_trailing_label.add_theme_color_override("font_color", V2.SUBTLE)
	V2.apply_body(_trailing_label)
	_trailing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_trailing_label)

	_built = true
	_apply_content()


func _apply_content() -> void:
	if _title_label == null:
		return
	_title_label.text = _title_text.to_upper()
	_trailing_label.text = _trailing_text
	_trailing_label.visible = not _trailing_text.is_empty()
	_icon.visible = not _icon_kind.is_empty()
	if _icon.visible:
		_icon.configure(_icon_kind, Color(_accent.r, _accent.g, _accent.b, 0.82), 1.45)
