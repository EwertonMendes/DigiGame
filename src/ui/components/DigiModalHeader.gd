extends Control
class_name DigiModalHeader

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")

const HEADER_HEIGHT := 58.0
const CLOSE_SIZE := 44.0

var _title: Label
var _subtitle: Label
var _bits_badge: PanelContainer
var _bits_value: Label
var _close_button: Button
var _title_text := "DIGIMON"
var _subtitle_text := ""
var _bits := 0
var _show_bits := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()


func configure(title: String, subtitle: String, bits: int = 0, show_bits: bool = true) -> DigiModalHeader:
	_title_text = title
	_subtitle_text = subtitle
	_bits = maxi(0, bits)
	_show_bits = show_bits
	if _title != null:
		_title.text = _title_text
		_subtitle.text = _subtitle_text
		_bits_value.text = "%d BITS" % _bits
		_layout()
	return self


func set_bits(bits: int) -> void:
	_bits = maxi(0, bits)
	if _bits_value != null:
		_bits_value.text = "%d BITS" % _bits


func get_close_button() -> Button:
	return _close_button


func _build() -> void:
	_title = Label.new()
	_title.text = _title_text
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", V2.TEXT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = _subtitle_text
	_subtitle.add_theme_font_size_override("font_size", 11)
	_subtitle.add_theme_color_override("font_color", V2.MUTED)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	V2.apply_body(_subtitle)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	_bits_badge = PanelContainer.new()
	_bits_badge.custom_minimum_size = Vector2(148.0, 38.0)
	_bits_badge.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.09),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.40),
			9,
			Vector4(10.0, 5.0, 12.0, 5.0)
		)
	)
	_bits_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bits_badge)
	var bits_row := HBoxContainer.new()
	bits_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bits_row.add_theme_constant_override("separation", 7)
	bits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bits_badge.add_child(bits_row)
	var bit_icon := IconScript.new() as DigiProceduralIcon
	bit_icon.custom_minimum_size = Vector2(22.0, 22.0)
	bit_icon.configure("bits", V2.AMBER, 1.8)
	bits_row.add_child(bit_icon)
	_bits_value = Label.new()
	_bits_value.text = "%d BITS" % _bits
	_bits_value.add_theme_font_size_override("font_size", 11)
	_bits_value.add_theme_color_override("font_color", V2.TEXT)
	_bits_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(_bits_value)
	_bits_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bits_row.add_child(_bits_value)

	_close_button = Button.new()
	_close_button.name = "ModalClose"
	_close_button.text = ""
	_close_button.icon = CLOSE_ICON
	_close_button.expand_icon = true
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.tooltip_text = "Close"
	_close_button.add_theme_stylebox_override("normal", V2.button_style(V2.MUTED, "normal", 9))
	_close_button.add_theme_stylebox_override("hover", V2.button_style(V2.RED, "hover", 9))
	_close_button.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 9))
	_close_button.add_theme_stylebox_override("pressed", V2.button_style(V2.RED, "pressed", 9))
	_close_button.add_theme_color_override("icon_normal_color", V2.MUTED)
	_close_button.add_theme_color_override("icon_hover_color", V2.WHITE)
	_close_button.add_theme_color_override("icon_focus_color", V2.WHITE)
	_close_button.add_theme_color_override("icon_pressed_color", V2.WHITE)
	_close_button.pressed.connect(func(): close_requested.emit())
	add_child(_close_button)


func _layout() -> void:
	if _title == null:
		return
	var compact := size.x < 620.0
	var show_bits_now := _show_bits and not compact
	_bits_badge.visible = show_bits_now
	var controls_right := 52.0 + (156.0 if show_bits_now else 0.0)
	_title.position = Vector2.ZERO
	_title.size = Vector2(maxf(120.0, size.x - controls_right - 10.0), 31.0)
	_subtitle.position = Vector2(0.0, 29.0)
	_subtitle.size = Vector2(maxf(100.0, size.x - controls_right - 10.0), 20.0)
	_subtitle.visible = not compact
	_close_button.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE), 0.0)
	_close_button.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	if show_bits_now:
		_bits_badge.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 156.0), 3.0)
		_bits_badge.size = Vector2(148.0, 38.0)
