extends Control
class_name DigiRosterPickerModal

signal entry_selected(entry_id: String)
signal cancelled

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")

const PAGE_SIZE := 3

var _backdrop: ColorRect
var _panel: PanelContainer
var _header: DigiSectionHeader
var _list: VBoxContainer
var _pager: DigiPager
var _cancel: Button
var _entries: Array[Dictionary] = []
var _page := 0
var _title := "SELECT DIGIMON"
var _subtitle := ""
var _accent := V2.CYAN
var _previous_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func configure(title: String, subtitle: String, entries: Array[Dictionary], accent: Color = V2.CYAN) -> void:
	_title = title
	_subtitle = subtitle
	_entries = entries.duplicate(true)
	_accent = accent
	_page = 0
	if _header != null:
		_refresh()


func open_picker(previous_focus: Control = null) -> void:
	_previous_focus = previous_focus if previous_focus != null else get_viewport().gui_get_focus_owner()
	visible = true
	_refresh()
	_layout()
	call_deferred("_focus_first")


func close_picker(restore_focus: bool = true) -> void:
	if not visible:
		return
	visible = false
	if restore_focus and _previous_focus != null and is_instance_valid(_previous_focus) and _previous_focus.visible and _previous_focus.focus_mode != Control.FOCUS_NONE:
		_previous_focus.grab_focus()
	_previous_focus = null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		close_picker()
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.003, 0.010, 0.018, 0.70)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.CYAN))
	add_child(_panel)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_panel.add_child(stack)

	_header = SectionHeaderScript.new() as DigiSectionHeader
	_header.set_workspace_mode(true)
	stack.add_child(_header)

	var content := MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(content)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.alignment = BoxContainer.ALIGNMENT_BEGIN
	_list.add_theme_constant_override("separation", 9)
	content.add_child(_list)

	var pager_margin := MarginContainer.new()
	pager_margin.add_theme_constant_override("margin_left", 14)
	pager_margin.add_theme_constant_override("margin_right", 14)
	pager_margin.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(pager_margin)
	_pager = PagerScript.new() as DigiPager
	_pager.set_workspace_mode(true)
	_pager.page_delta_requested.connect(_turn_page)
	pager_margin.add_child(_pager)

	var cancel_margin := MarginContainer.new()
	cancel_margin.add_theme_constant_override("margin_left", 14)
	cancel_margin.add_theme_constant_override("margin_right", 14)
	cancel_margin.add_theme_constant_override("margin_bottom", 14)
	stack.add_child(cancel_margin)
	_cancel = Button.new()
	_cancel.text = "BACK"
	_cancel.custom_minimum_size.y = V2.TOUCH_TARGET
	_cancel.focus_mode = Control.FOCUS_ALL
	_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	V2.apply_heading(_cancel)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		_cancel.add_theme_stylebox_override(state, V2.hospital_button_style(V2.MUTED, state))
	_cancel.pressed.connect(func():
		close_picker()
		cancelled.emit()
	)
	cancel_margin.add_child(_cancel)


func _refresh() -> void:
	if _header == null:
		return
	_header.configure(_title, _subtitle, _accent, "party")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var pages := maxi(1, ceili(float(_entries.size()) / float(PAGE_SIZE)))
	_page = clampi(_page, 0, pages - 1)
	var start := _page * PAGE_SIZE
	var finish := mini(_entries.size(), start + PAGE_SIZE)
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "No valid Digimon available."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", V2.MUTED)
		V2.apply_body(empty)
		_list.add_child(empty)
	else:
		for index in range(start, finish):
			_list.add_child(_entry_button(_entries[index]))
	_pager.configure(_page, pages)
	call_deferred("_focus_first")


func _entry_button(entry: Dictionary) -> Button:
	var id := String(entry.get("id", ""))
	var title := String(entry.get("title", id))
	var subtitle := String(entry.get("subtitle", ""))
	var species := String(entry.get("species", ""))
	var accent: Color = entry.get("accent", _accent)

	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 92.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, V2.hospital_button_style(accent, state))
	button.pressed.connect(func():
		close_picker(false)
		entry_selected.emit(id)
	)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	if not species.is_empty():
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.custom_minimum_size = Vector2(68, 68)
		preview.set_species(species)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := Label.new()
	name.text = title
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", V2.WHITE)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	V2.apply_heading(name)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name)
	var meta := Label.new()
	meta.text = subtitle
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", V2.MUTED)
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	V2.apply_body(meta)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(meta)
	return button


func _turn_page(delta: int) -> void:
	var pages := maxi(1, ceili(float(_entries.size()) / float(PAGE_SIZE)))
	var next := clampi(_page + delta, 0, pages - 1)
	if next == _page:
		return
	_page = next
	_refresh()


func _focus_first() -> void:
	if not visible:
		return
	for child in _list.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	_cancel.grab_focus()


func _layout() -> void:
	if _panel == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := physical.x < 760.0 or physical.y < 620.0
	var width := minf(620.0, physical.x - (24.0 if compact else 80.0))
	var height := minf(520.0, physical.y - (24.0 if compact else 80.0))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_panel.size = Vector2(width, height)
	_pager.set_compact(compact)
