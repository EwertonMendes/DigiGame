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
var _accent_bar: ColorRect
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
	custom_minimum_size.y = 32.0
	_build()
	_built = true
	_apply_content()


func _build() -> void:
	var style := V2.surface_style(
		Color(V2.SURFACE_ALT.r, V2.SURFACE_ALT.g, V2.SURFACE_ALT.b, 0.74),
		Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.28),
		8,
		Vector4(9.0, 3.0, 10.0, 3.0)
	)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 1.0)
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(3.0, 16.0)
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_accent_bar)

	_icon = IconScript.new() as DigiProceduralIcon
	_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 11)
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


func _apply_content() -> void:
	if _title_label == null:
		return
	_title_label.text = _title_text.to_upper()
	_trailing_label.text = _trailing_text
	_trailing_label.visible = not _trailing_text.is_empty()
	_accent_bar.color = Color(_accent.r, _accent.g, _accent.b, 0.90)
	_icon.visible = not _icon_kind.is_empty()
	if _icon.visible:
		_icon.configure(_icon_kind, _accent, 1.45)
