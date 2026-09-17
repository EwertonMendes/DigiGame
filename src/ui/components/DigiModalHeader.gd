extends Control
class_name DigiModalHeader

signal close_requested
signal tab_selected(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")
const BITS_ICON = preload("res://assets/ui/icons/bits.png")

const HEADER_HEIGHT := 60.0
const CLOSE_SIZE := 40.0
const TITLE_BLOCK_WIDTH := 196.0
const WORKSPACE_HEADER_HEIGHT := 86.0
const WORKSPACE_CLOSE_SIZE := 48.0
const WORKSPACE_BITS_SIZE := Vector2(166.0, 46.0)

var _backplate: ColorRect
var _brand_row: HBoxContainer
var _brand_icon: DigiProceduralIcon
var _title: Label
var _subtitle: Label
var _tabs_root: HBoxContainer
var _tab_buttons: Dictionary = {}
var _tab_specs: Array[Dictionary] = []
var _active_tab := ""
var _bits_badge: PanelContainer
var _bits_icon: TextureRect
var _bits_value: Label
var _close_button: Button
var _title_text := "DIGI"
var _subtitle_text := "Digital Monsters"
var _bits := 0
var _show_bits := true
var _workspace_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_build()
	resized.connect(_layout)
	_rebuild_tabs()
	_apply_visual_mode()
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


func set_workspace_mode(enabled: bool) -> void:
	if _workspace_mode == enabled:
		return
	_workspace_mode = enabled
	if _title != null:
		_apply_visual_mode()
		_layout()


func is_workspace_mode() -> bool:
	return _workspace_mode


func set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id
	if _tabs_root != null:
		_rebuild_tabs()
		_layout()


func set_tab_enabled(tab_id: String, enabled: bool) -> void:
	for spec: Dictionary in _tab_specs:
		if String(spec.get("id", "")) == tab_id:
			spec["enabled"] = enabled
			break
	if _tabs_root != null:
		_rebuild_tabs()
		_layout()


func set_bits(bits: int) -> void:
	_bits = maxi(0, bits)
	if _bits_value != null:
		_bits_value.text = "%d BITS" % _bits


func get_close_button() -> Button:
	return _close_button


func get_tab_button(tab_id: String) -> Button:
	return _tab_buttons.get(tab_id) as Button


func select_adjacent_tab(direction: int) -> bool:
	if direction == 0:
		return false
	var enabled_tabs: Array[String] = []
	for spec: Dictionary in _tab_specs:
		if not bool(spec.get("enabled", true)):
			continue
		var tab_id := String(spec.get("id", ""))
		if not tab_id.is_empty():
			enabled_tabs.append(tab_id)
	if enabled_tabs.size() < 2:
		return false
	var current_index := enabled_tabs.find(_active_tab)
	if current_index < 0:
		current_index = 0
	var step := -1 if direction < 0 else 1
	var next_index := posmod(current_index + step, enabled_tabs.size())
	var next_tab := enabled_tabs[next_index]
	if next_tab == _active_tab:
		return false
	tab_selected.emit(next_tab)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventJoypadButton):
		return
	var joy_button := event as InputEventJoypadButton
	if not joy_button.pressed:
		return
	var direction := 0
	if joy_button.button_index == JOY_BUTTON_LEFT_SHOULDER:
		direction = -1
	elif joy_button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		direction = 1
	if direction != 0 and select_adjacent_tab(direction):
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backplate = ColorRect.new()
	_backplate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backplate)

	_brand_row = HBoxContainer.new()
	_brand_row.name = "Brand"
	_brand_row.add_theme_constant_override("separation", 10)
	_brand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brand_row)

	_brand_icon = IconScript.new() as DigiProceduralIcon
	_brand_icon.custom_minimum_size = Vector2(34.0, 34.0)
	_brand_row.add_child(_brand_icon)

	var brand_copy := VBoxContainer.new()
	brand_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_copy.add_theme_constant_override("separation", -2)
	brand_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_row.add_child(brand_copy)

	_title = Label.new()
	_title.text = _title_text
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_copy.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = _subtitle_text
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_body(_subtitle)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_copy.add_child(_subtitle)

	_brand_row.set_meta("title", _title)
	_brand_row.set_meta("subtitle", _subtitle)
	_brand_row.set_meta("copy", brand_copy)

	_tabs_root = HBoxContainer.new()
	_tabs_root.name = "HeaderTabs"
	_tabs_root.add_theme_constant_override("separation", 4)
	_tabs_root.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tabs_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tabs_root)

	_bits_badge = PanelContainer.new()
	_bits_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bits_badge)
	var bits_row := HBoxContainer.new()
	bits_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bits_row.add_theme_constant_override("separation", 8)
	bits_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bits_badge.add_child(bits_row)
	_bits_icon = TextureRect.new()
	_bits_icon.texture = BITS_ICON
	_bits_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bits_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bits_icon.self_modulate = V2.AMBER
	_bits_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bits_row.add_child(_bits_icon)
	_bits_value = Label.new()
	_bits_value.text = "%d BITS" % _bits
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
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.tooltip_text = "Close"
	_close_button.pressed.connect(func(): close_requested.emit())
	add_child(_close_button)


func _apply_visual_mode() -> void:
	if _title == null:
		return
	if _workspace_mode:
		_backplate.color = Color(0.016, 0.037, 0.055, 0.94)
		_brand_icon.custom_minimum_size = Vector2(52.0, 52.0)
		_brand_icon.configure("brand", V2.CYAN, 1.65)
		_title.add_theme_font_size_override("font_size", 30)
		_title.add_theme_color_override("font_color", V2.WHITE)
		_subtitle.add_theme_font_size_override("font_size", 16)
		_subtitle.add_theme_color_override("font_color", V2.MUTED)
		_bits_badge.custom_minimum_size = WORKSPACE_BITS_SIZE
		_bits_badge.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.AMBER))
		_bits_icon.custom_minimum_size = Vector2(27.0, 27.0)
		_bits_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bits_icon.self_modulate = Color.WHITE
		_bits_value.add_theme_font_size_override("font_size", 18)
		_bits_value.add_theme_color_override("font_color", V2.WHITE)
		_close_button.custom_minimum_size = Vector2(WORKSPACE_CLOSE_SIZE, WORKSPACE_CLOSE_SIZE)
		for state in ["normal", "hover", "focus", "pressed", "disabled"]:
			_close_button.add_theme_stylebox_override(state, V2.hospital_button_style(V2.CYAN, state))
		_close_button.add_theme_color_override("icon_normal_color", V2.WHITE)
		_close_button.add_theme_color_override("icon_hover_color", V2.WHITE)
		_close_button.add_theme_color_override("icon_focus_color", V2.WHITE)
		_close_button.add_theme_color_override("icon_pressed_color", V2.WHITE)
	else:
		_backplate.color = Color(V2.BASE.r, V2.BASE.g, V2.BASE.b, 0.995)
		_brand_icon.custom_minimum_size = Vector2(34.0, 34.0)
		_brand_icon.configure("brand", Color(0.66, 0.76, 0.88, 1.0), 1.4)
		_title.add_theme_font_size_override("font_size", 24)
		_title.add_theme_color_override("font_color", Color(0.70, 0.79, 0.90, 1.0))
		_subtitle.add_theme_font_size_override("font_size", 9)
		_subtitle.add_theme_color_override("font_color", V2.MUTED)
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
		_bits_icon.custom_minimum_size = Vector2(19.0, 19.0)
		_bits_value.add_theme_font_size_override("font_size", 11)
		_bits_value.add_theme_color_override("font_color", V2.TEXT)
		_close_button.custom_minimum_size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
		_close_button.add_theme_stylebox_override("normal", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.68), V2.BORDER_SOFT, 7))
		_close_button.add_theme_stylebox_override("hover", V2.button_style(V2.RED, "hover", 7))
		_close_button.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 7))
		_close_button.add_theme_stylebox_override("pressed", V2.button_style(V2.RED, "pressed", 7))
		_close_button.add_theme_color_override("icon_normal_color", V2.MUTED)
		_close_button.add_theme_color_override("icon_hover_color", V2.WHITE)
		_close_button.add_theme_color_override("icon_focus_color", V2.WHITE)
		_close_button.add_theme_color_override("icon_pressed_color", V2.WHITE)


func _rebuild_tabs() -> void:
	if _tabs_root == null:
		return
	for child in _tabs_root.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for spec: Dictionary in _tab_specs:
		var tab_id := String(spec.get("id", ""))
		var label_text := String(spec.get("label", tab_id.capitalize()))
		var compact_label := String(spec.get("compact_label", label_text))
		var enabled := bool(spec.get("enabled", true))
		var active := tab_id == _active_tab
		var icon_kind := String(spec.get("icon", _tab_icon_for(tab_id)))
		var min_width := float(spec.get("min_width", 126.0))

		var button := Button.new()
		button.name = "Tab_%s" % tab_id
		button.text = ""
		button.custom_minimum_size = Vector2(min_width, 58.0)
		button.focus_mode = Control.FOCUS_NONE if _workspace_mode else Control.FOCUS_ALL
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
		button.set_meta("tab_label", label)
		button.set_meta("tab_icon", icon)
		button.set_meta("tab_row", row)
		button.set_meta("full_label", label_text)
		button.set_meta("compact_label", compact_label)
		button.set_meta("preferred_min_width", min_width)
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
		"convert":
			return "database"
		"party":
			return "party"
		"ascension":
			return "evolution"
		_:
			return "info"


func _layout() -> void:
	if _title == null:
		return
	if _workspace_mode:
		_layout_workspace()
		return

	var compact := size.x < 760.0
	var has_tabs := not _tab_specs.is_empty()
	var compact_tabs := compact and has_tabs
	var show_bits_now := _show_bits and not compact
	_bits_badge.visible = show_bits_now
	_brand_row.visible = not compact_tabs
	_brand_row.position = Vector2(28.0, 10.0)
	_brand_row.size = Vector2(TITLE_BLOCK_WIDTH - 28.0, 42.0)
	_subtitle.visible = not compact and not compact_tabs

	var controls_right := 18.0 + CLOSE_SIZE + (140.0 if show_bits_now else 0.0)
	_tabs_root.visible = has_tabs
	if _tabs_root.visible:
		if compact_tabs:
			_tabs_root.position = Vector2(8.0, 0.0)
			_tabs_root.size = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 32.0), HEADER_HEIGHT)
			var available := maxf(180.0, _tabs_root.size.x - float(maxi(0, _tab_specs.size() - 1)) * 4.0)
			var per_tab := available / float(maxi(1, _tab_specs.size()))
			var icon_only := size.x < 390.0 or per_tab < 92.0
			for value in _tab_buttons.values():
				var tab_button := value as Button
				if tab_button == null:
					continue
				tab_button.custom_minimum_size.x = maxf(72.0, per_tab)
				var label := tab_button.get_meta("tab_label") as Label
				var icon := tab_button.get_meta("tab_icon") as DigiProceduralIcon
				var row := tab_button.get_meta("tab_row") as HBoxContainer
				if label != null:
					label.visible = not icon_only
					label.text = String(tab_button.get_meta("compact_label", tab_button.get_meta("full_label", "")))
					label.add_theme_font_size_override("font_size", 11)
				if icon != null:
					icon.custom_minimum_size = Vector2(19.0, 19.0)
				if row != null:
					row.add_theme_constant_override("separation", 6 if not icon_only else 0)
		else:
			_tabs_root.position = Vector2(TITLE_BLOCK_WIDTH, 0.0)
			_tabs_root.size = Vector2(maxf(0.0, size.x - TITLE_BLOCK_WIDTH - controls_right - 12.0), HEADER_HEIGHT)
			for value in _tab_buttons.values():
				var tab_button := value as Button
				if tab_button == null:
					continue
				tab_button.custom_minimum_size.x = float(tab_button.get_meta("preferred_min_width", 126.0))
				var label := tab_button.get_meta("tab_label") as Label
				var icon := tab_button.get_meta("tab_icon") as DigiProceduralIcon
				var row := tab_button.get_meta("tab_row") as HBoxContainer
				if label != null:
					label.visible = true
					label.text = String(tab_button.get_meta("full_label", ""))
					label.add_theme_font_size_override("font_size", 13)
				if icon != null:
					icon.custom_minimum_size = Vector2(22.0, 22.0)
				if row != null:
					row.add_theme_constant_override("separation", 9)

	_close_button.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 16.0), 10.0)
	_close_button.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	if show_bits_now:
		_bits_badge.position = Vector2(maxf(0.0, size.x - CLOSE_SIZE - 16.0 - 12.0 - 128.0), 11.0)
		_bits_badge.size = Vector2(128.0, 38.0)


func _layout_workspace() -> void:
	_tabs_root.visible = not _tab_specs.is_empty()
	var compact := size.x < 680.0
	var show_bits_now := _show_bits and not compact and (not _tabs_root.visible or size.x >= 900.0)
	_bits_badge.visible = show_bits_now
	_brand_row.visible = true
	_brand_row.position = Vector2(24.0, 12.0)
	_brand_row.size = Vector2((340.0 if size.x >= 900.0 else 220.0) if _tabs_root.visible else maxf(180.0, size.x - 360.0), 60.0)
	_subtitle.visible = size.x >= (900.0 if _tabs_root.visible else 520.0)
	_close_button.position = Vector2(maxf(0.0, size.x - 70.0), 16.0)
	_close_button.size = Vector2(WORKSPACE_CLOSE_SIZE, WORKSPACE_CLOSE_SIZE)
	if show_bits_now:
		_bits_badge.position = Vector2(maxf(0.0, size.x - WORKSPACE_BITS_SIZE.x - 82.0), 17.0)
		_bits_badge.size = WORKSPACE_BITS_SIZE
	if _tabs_root.visible:
		var tabs_left := 370.0 if size.x >= 900.0 else 258.0
		var tabs_right := _bits_badge.position.x if show_bits_now else _close_button.position.x
		_tabs_root.position = Vector2(tabs_left, 17.0)
		_tabs_root.size = Vector2(maxf(0.0, tabs_right - tabs_left - 20.0), 50.0)
		var tab_width := clampf((_tabs_root.size.x - 8.0) / float(_tab_specs.size()), 72.0, 150.0)
		for value in _tab_buttons.values():
			var button := value as Button
			button.custom_minimum_size = Vector2(tab_width, 50.0)
			var label := button.get_meta("tab_label") as Label
			var icon := button.get_meta("tab_icon") as DigiProceduralIcon
			if label != null:
				label.visible = tab_width >= 94.0
				label.add_theme_font_size_override("font_size", 14)
			if icon != null:
				icon.custom_minimum_size = Vector2(20.0, 20.0)
