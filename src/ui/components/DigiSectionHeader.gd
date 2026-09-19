extends PanelContainer
class_name DigiSectionHeader

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiIconView.gd")

var _title_text := "SECTION"
var _trailing_text := ""
var _accent := V2.CYAN
var _icon_kind := ""
var _icon_texture: Texture2D = null
var _title_label: Label
var _trailing_label: Label
var _icon: DigiIconView
var _icon_slot: CenterContainer
var _margin: MarginContainer
var _built := false
var _workspace_mode := false


func configure(title: String, trailing: String = "", accent: Color = V2.CYAN, icon_kind: String = "") -> DigiSectionHeader:
	_title_text = title
	_trailing_text = trailing
	_accent = accent
	_icon_kind = icon_kind
	if _built:
		_apply_content()
	return self


func set_icon_texture(texture: Texture2D) -> DigiSectionHeader:
	_icon_texture = texture
	if _built:
		_apply_content()
	return self


func clear_icon_texture() -> void:
	_icon_texture = null
	if _built:
		_apply_content()


func get_icon_view() -> DigiIconView:
	return _icon


func set_workspace_mode(enabled: bool) -> void:
	_workspace_mode = enabled
	if _built:
		_apply_visual_mode()


func set_trailing(text: String) -> void:
	_trailing_text = text
	if _trailing_label != null:
		_trailing_label.text = _trailing_text
		_trailing_label.visible = not _trailing_text.is_empty()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(row)

	_icon_slot = CenterContainer.new()
	_icon_slot.name = "SectionIconSlot"
	_icon_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon_slot)

	_icon = IconScript.new() as DigiIconView
	_icon.name = "SectionIcon"
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_slot.add_child(_icon)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(_title_label)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title_label)

	_trailing_label = Label.new()
	_trailing_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trailing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trailing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_body(_trailing_label)
	_trailing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_trailing_label)

	_built = true
	_apply_visual_mode()
	_apply_content()


func _apply_visual_mode() -> void:
	if _title_label == null:
		return
	if _workspace_mode:
		custom_minimum_size.y = 44.0
		add_theme_stylebox_override("panel", V2.header_strip_style(9))
		_margin.add_theme_constant_override("margin_left", 14)
		_margin.add_theme_constant_override("margin_top", 7)
		_margin.add_theme_constant_override("margin_right", 14)
		_margin.add_theme_constant_override("margin_bottom", 7)
		_icon_slot.custom_minimum_size = Vector2(24.0, 0.0)
		_icon.custom_minimum_size = Vector2(22.0, 22.0)
		_title_label.add_theme_font_size_override("font_size", 16)
		_title_label.add_theme_color_override("font_color", V2.TEXT)
		_trailing_label.add_theme_font_size_override("font_size", 12)
		_trailing_label.add_theme_color_override("font_color", V2.MUTED)
	else:
		custom_minimum_size.y = 34.0
		add_theme_stylebox_override("panel", V2.header_strip_style(7))
		_margin.add_theme_constant_override("margin_left", 12)
		_margin.add_theme_constant_override("margin_top", 5)
		_margin.add_theme_constant_override("margin_right", 12)
		_margin.add_theme_constant_override("margin_bottom", 5)
		_icon_slot.custom_minimum_size = Vector2(18.0, 0.0)
		_icon.custom_minimum_size = Vector2(16.0, 16.0)
		_title_label.add_theme_font_size_override("font_size", 12)
		_title_label.add_theme_color_override("font_color", V2.TEXT)
		_trailing_label.add_theme_font_size_override("font_size", 9)
		_trailing_label.add_theme_color_override("font_color", V2.SUBTLE)
	_apply_content()


func _apply_content() -> void:
	if _title_label == null:
		return
	_title_label.text = _title_text.to_upper()
	_trailing_label.text = _trailing_text
	_trailing_label.visible = not _trailing_text.is_empty()
	_icon.visible = _icon_texture != null or not _icon_kind.is_empty()
	if _icon.visible:
		var icon_accent := Color(_accent.r, _accent.g, _accent.b, 0.82)
		if _icon_texture != null:
			_icon.configure_texture(_icon_texture, icon_accent)
		else:
			_icon.configure_procedural(_icon_kind, icon_accent, 1.65 if _workspace_mode else 1.45)
