extends Control
class_name DigiModalHeader

signal close_requested
signal tab_selected(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")
const BITS_ICON = preload("res://assets/ui/icons/bits.svg")

const HEADER_HEIGHT := 60.0
const CLOSE_SIZE := 40.0
const TITLE_BLOCK_WIDTH := 196.0

var _backplate: ColorRect
var _brand_icon: DigiProceduralIcon
var _title: Label
var _subtitle: Label
var _tabs_root: HBoxContainer
var _tab_buttons: Dictionary = {}
var _tab_specs: Array[Dictionary] = []
var _active_tab := ""
var _bits_badge: PanelContainer
var _bits_value: Label
var _close_button: Button
var _title_text := "DIGI"
var _subtitle_text := "Digital Monsters"
var _bits := 0
var _show_bits := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_rebuild_tabs()
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


func configure_tabs(specs: Array[Dictionary], active_id: String) -> DigiModalHeader:
	_tab_specs = specs.duplicate(true)
	_active_tab = active_id
	if _tabs_root != null:
		_rebuild_tabs()
		_layout()
	return self


func set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id
	if _tabs_root != null:
		_rebuild_tabs()


func set_tab_enabled(tab_id: String, enabled: bool) -> void:
	for spec: Dictionary in _tab_specs:
		if String(spec.get("id", "")) == tab_id:
			spec["enabled"] = enabled
			break
	if _tabs_root != null:
		_rebuild_tabs()


func set_bits(bits: int) -> void:
	_bits = maxi(0, bits)
	if _bits_value != null:
		_bits_value.text = "%d BITS" % _bits


func get_close_button() -> Button:
	return _close_button


func get_tab_button(tab_id: String) -> Button:
	return _tab_buttons.get(tab_id) as Button


func _build() -> void:
	_backplate = ColorRect.new()
	_backplate.color = Color(V2.BASE.r, V2.BASE.g, V2.BASE.b, 0.995)
	_backplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backplate)

	var brand_row := HBoxContainer.new()
	brand_row.name = "Brand"
	brand_row.add_theme_constant_override("separation", 10)
	brand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand_row)

	_brand_icon = IconScript.new() as DigiProceduralIcon
	_brand_icon.custom_minimum_size = Vector2(34.0, 34.0)
	_brand_icon.configure("brand", Color(0.66, 0.76, 0.88, 1.0), 1.4)
	brand_row.add_child(_brand_icon)

	var brand_copy := VBoxContainer.new()
	brand_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_copy.add_theme_constant_override("separation", -2)
	brand_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_row.add_child(brand_copy)

	_title = Label.new()
	_title.text = _title_text
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.70, 0.79, 0.90, 1.0))
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_copy.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = _subtitle_text
	_subtitle.add_theme_font_size_override("font_size", 9)
	_subtitle.add_theme_color_override("font_color", V2.MUTED)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_body(_subtitle)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_copy.add_child(_subtitle)

	brand_row.set_meta("title", _title)
	brand_row.set_meta("subtitle", _subtitle)
	brand_row.set_meta("copy", brand_copy)

	_tabs_root = HBoxContainer.new()
	_tabs_root.name = "HeaderTabs"
	_tabs_root.add_theme_constant_override("separation", 4)
	_tabs_root.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tabs_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tabs_root)

	_bits_badge = PanelContainer.new()
	_bits_badge.custom_minimum_size = Vector2(128.0, 38.0)
	_bits_badge.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(0.035, 0.055, 0.075, 0.98),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.30),
			7,
			Vector4(10.0, 5.0, 10.0, 5.0)
		)
	)
	_bits_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bits_badge)
	var bits_row := HBoxContainer.new()
	bits_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bits_row.add_theme_constant_override("separation", 8)
	bits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bits_badge.add_child(bits_row)
	var bit_icon := TextureRect.new()
	bit_icon.custom_minimum_size = Vector2(19.0, 19.0)
	bit_icon.texture = BITS_ICON
	bit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bit_icon.self_modulate = V2.AMBER
	bit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_close_button.add_theme_stylebox_override("normal", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.68), V2.BORDER_SOFT, 7))
	_close_button.add_theme_stylebox_override("hover", V2.button_style(V2.RED, "hover", 7))
	_close_button.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 7))
	_close_button.add_theme_stylebox_override("pressed", V2.button_style(V2.RED, "pressed", 7))
	_close_button.add_theme_color_override("icon_normal_color", V2.MUTED)
	_close_button.add_theme_color_override("icon_hover_color", V2.WHITE)
	_close_button.add_theme_color_override("icon_focus_color", V2.WHITE)
	_close_button.add_theme_color_override("icon_pressed_color", V2.WHITE)
	_close_button.pressed.connect(func(): close_requested.emit())
	add_child(_close_button)


func _rebuild_tabs() -> void:
	if _tabs_root == null:
		return
	for child in _tabs_root.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for spec: Dictionary in _tab_specs:
		var tab_id := String(spec.get("id", ""))
		var label_text := String(spec.get("label", tab_id.capitalize()))
		var enabled := bool(spec.get("enabled", true))
		var active := tab_id == _active_tab
		var icon_kind := String(spec.get("icon", _tab_icon_for(tab_id)))

		var button := Button.new()
		button.name = "Tab_%s" % tab_id
		button.text = ""
		button.custom_minimum_size = Vector2(126.0, 58.0)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not enabled
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
		button.tooltip_text = label_text if enabled else "%s — coming later" % label_text
		button.add_theme_stylebox_override("normal", V2.tab_style(active, false, false))
		button.add_theme_stylebox_override("hover", V2.tab_style(active, true, false))
		button.add_theme_stylebox_override("focus", V2.tab_style(active, true, false))
		button.add_theme_stylebox_override("pressed", V2.tab_style(active, true, false))
		button.add_theme_stylebox_override("disabled", V2.tab_style(false, false, true))

		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 9)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var icon := IconScript.new() as DigiProceduralIcon
		icon.custom_minimum_size = Vector2(22.0, 22.0)
		icon.configure(icon_kind, V2.CYAN if active else (V2.MUTED if enabled else V2.SUBTLE), 1.8)
		row.add_child(icon)
		var label := Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", V2.WHITE if active else (V2.MUTED if enabled else V2.SUBTLE))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		V2.apply_heading(label)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		if enabled:
			button.pressed.connect(func(): tab_selected.emit(tab_id))
		_tabs_root.add_child(button)
		_tab_buttons[tab_id] = button


func _tab_icon_for(tab_id: String) -> String:
	match tab_id:
		"digimon":
			return "digimon"
		"digipedia":
			return "book"
		"system":
			return "gear"
		_:
			return "info"


func _layout() -> void:
	if _title == null:
		return
	var compact := size.x < 760.0
	var show_bits_now := _show_bits and not compact
	_bits_badge.visible = show_bits_now
	var brand_row := _brand_icon.get_parent() as HBoxContainer
	if brand_row != null:
		brand_row.position = Vector2(28.0, 10.0)
		brand_row.size = Vector2(TITLE_BLOCK_WIDTH - 28.0, 42.0)
	_subtitle.visible = not compact

	var controls_right := 18.0 + CLOSE_SIZE + (140.0 if show_bits_now else 0.0)
	_tabs_root.visible = not compact and not _tab_specs.is_empty()
	if _tabs_root.visible:
		_tabs_root.position = Vector2(TITLE_BLOCK_WIDTH, 0.0)
		_tabs_root.size = Vector2(maxf(0.0, size.x - TITLE_BLOCK_WIDTH - controls_right - 12.0), HEADER_HEIGHT)

	_close_button.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 16.0), 10.0)
	_close_button.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	if show_bits_now:
		_bits_badge.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 16.0 - 12.0 - 128.0), 11.0)
		_bits_badge.size = Vector2(128.0, 38.0)
