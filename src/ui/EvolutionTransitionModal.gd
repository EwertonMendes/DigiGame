extends Control
class_name EvolutionTransitionModal

signal confirmed(direction: String, target_seed: String)
signal cancelled

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")

const STAT_ROWS: Array[Dictionary] = [
	{"key": "level", "label": "LEVEL"},
	{"key": "exp", "label": "EXP"},
	{"key": "potential", "label": "POTENTIAL"},
	{"key": "hp", "label": "HP"},
	{"key": "sp", "label": "SP"},
	{"key": "atk", "label": "ATK"},
	{"key": "def", "label": "DEF"},
	{"key": "int", "label": "INT"},
	{"key": "speed", "label": "SPD"},
	{"key": "mov", "label": "MOV"},
]

var _backdrop: ColorRect
var _panel: PanelContainer
var _panel_margin: MarginContainer
var _title: Label
var _subtitle: Label
var _operation: Label
var _route_grid: GridContainer
var _route_arrow: Label
var _from_portrait: DigimonPortraitPreview
var _from_name: Label
var _from_rank: Label
var _to_portrait: DigimonPortraitPreview
var _to_name: Label
var _to_rank: Label
var _stat_body: VBoxContainer
var _preserved_note: Label
var _button_grid: GridContainer
var _confirm_button: Button
var _cancel_button: Button
var _previous_focus: Control = null
var _preview: Dictionary = {}
var _changed_rows: Array[Control] = []
var _open_tween: Tween = null
var _close_tween: Tween = null
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_preview(preview: Dictionary) -> void:
	if preview.is_empty():
		return
	_preview = preview.duplicate(true)
	_closing = false
	_previous_focus = get_viewport().gui_get_focus_owner()
	_populate()
	visible = true
	_confirm_button.disabled = false
	_cancel_button.disabled = false
	_layout()
	_play_open_animation()
	call_deferred("_focus_safe_default")


func cancel() -> void:
	if not visible or _closing:
		return
	_closing = true
	_confirm_button.disabled = true
	_cancel_button.disabled = true
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	_close_tween = create_tween().set_parallel(true)
	_close_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.10)
	_close_tween.tween_property(_panel, "modulate:a", 0.0, 0.10)
	_close_tween.tween_property(_panel, "scale", _panel.scale * 0.975, 0.10)
	_close_tween.chain().tween_callback(_finish_cancel)


func close_immediately() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	visible = false
	_closing = false
	_preview.clear()
	_previous_focus = null


func is_open() -> bool:
	return visible


# Handle cancel before any parent menu receives _unhandled_input. This keeps
# Escape/B/Circle equivalent to choosing the safe default (NO) instead of
# accidentally closing the whole Evolution Chart behind the modal.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		cancel()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "TransitionModalBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.008, 0.020, 0.82)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "EvolutionTransitionPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.12, 0.24, 0.38, 0.99), Vector4.ZERO, 14.0)
	)
	add_child(_panel)

	_panel_margin = MarginContainer.new()
	_set_panel_margins(22, 20, 22, 18)
	_panel.add_child(_panel_margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	_panel_margin.add_child(root)

	_title = _label("CONFIRM DIGIVOLUTION", 23, UI.TEXT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)

	_subtitle = _label("Review the permanent form change before continuing.", 11, UI.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle)

	var scroll := ScrollContainer.new()
	scroll.name = "TransitionSummaryScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)

	_operation = _label("DIGIVOLUTION", 10, UI.GREEN, true)
	_operation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_operation)

	var route_panel := PanelContainer.new()
	route_panel.add_theme_stylebox_override(
		"panel",
		_surface_style(Color(0.12, 0.28, 0.42, 0.55), UI.CYAN, 0.30)
	)
	body.add_child(route_panel)

	var route_margin := MarginContainer.new()
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		route_margin.add_theme_constant_override("margin_%s" % _side_name(side), 10)
	route_margin.add_theme_constant_override("margin_top", 8)
	route_margin.add_theme_constant_override("margin_bottom", 8)
	route_panel.add_child(route_margin)

	_route_grid = GridContainer.new()
	_route_grid.columns = 3
	_route_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_grid.add_theme_constant_override("h_separation", 8)
	_route_grid.add_theme_constant_override("v_separation", 4)
	route_margin.add_child(_route_grid)

	var from_card := _form_card()
	_route_grid.add_child(from_card.get("panel") as Control)
	_from_portrait = from_card.get("portrait") as DigimonPortraitPreview
	_from_name = from_card.get("name") as Label
	_from_rank = from_card.get("rank") as Label

	_route_arrow = _label("→", 28, UI.CYAN, true)
	_route_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_route_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_route_arrow.custom_minimum_size = Vector2(34, 82)
	_route_grid.add_child(_route_arrow)

	var to_card := _form_card()
	_route_grid.add_child(to_card.get("panel") as Control)
	_to_portrait = to_card.get("portrait") as DigimonPortraitPreview
	_to_name = to_card.get("name") as Label
	_to_rank = to_card.get("rank") as Label

	body.add_child(_label("ATTRIBUTE TRANSITION", 10, UI.SUBTLE, true))

	_stat_body = VBoxContainer.new()
	_stat_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_body.add_theme_constant_override("separation", 4)
	body.add_child(_stat_body)

	_preserved_note = _label("", 10, UI.MUTED)
	_preserved_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preserved_note.add_theme_constant_override("line_spacing", 2)
	body.add_child(_preserved_note)

	_button_grid = GridContainer.new()
	_button_grid.columns = 2
	_button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_grid.add_theme_constant_override("h_separation", 10)
	_button_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(_button_grid)

	_cancel_button = _button("NO, GO BACK", UI.CYAN)
	_cancel_button.name = "CancelEvolutionTransition"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(cancel)
	_button_grid.add_child(_cancel_button)

	_confirm_button = _button("YES, DIGIVOLVE", UI.GREEN)
	_confirm_button.name = "ConfirmEvolutionTransition"
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(_confirm)
	_button_grid.add_child(_confirm_button)

	_cancel_button.focus_neighbor_left = _cancel_button.get_path()
	_cancel_button.focus_neighbor_right = _confirm_button.get_path()
	_cancel_button.focus_neighbor_bottom = _confirm_button.get_path()
	_confirm_button.focus_neighbor_left = _cancel_button.get_path()
	_confirm_button.focus_neighbor_right = _confirm_button.get_path()
	_confirm_button.focus_neighbor_top = _cancel_button.get_path()


func _populate() -> void:
	var direction := String(_preview.get("direction", "digivolution"))
	var degenerating := direction == "degeneration"
	var accent := UI.CYAN if degenerating else UI.GREEN
	_title.text = "CONFIRM DEGENERATION" if degenerating else "CONFIRM DIGIVOLUTION"
	_operation.text = "DEGENERATION" if degenerating else "DIGIVOLUTION"
	_operation.add_theme_color_override("font_color", accent)
	_confirm_button.text = "YES, DEGENERATE" if degenerating else "YES, DIGIVOLVE"
	SKIN.apply_button(_confirm_button, accent)
	UI.apply_body_font(_confirm_button)

	_from_name.text = String(_preview.get("from_name", "Unknown")).to_upper()
	_from_rank.text = String(_preview.get("from_rank", "Unknown")).to_upper()
	_to_name.text = String(_preview.get("to_name", "Unknown")).to_upper()
	_to_rank.text = String(_preview.get("to_rank", "Unknown")).to_upper()
	_from_portrait.set_species(String(_preview.get("from_name", "")))
	_to_portrait.set_species(String(_preview.get("to_name", "")))

	for child in _stat_body.get_children():
		child.free()
	_changed_rows.clear()
	var before := _preview.get("before", {}) as Dictionary
	var after := _preview.get("after", {}) as Dictionary
	for definition: Dictionary in STAT_ROWS:
		var key := String(definition.get("key", ""))
		var before_value := int(before.get(key, 0))
		var after_value := int(after.get(key, 0))
		var row := _stat_row(String(definition.get("label", key.to_upper())), before_value, after_value)
		_stat_body.add_child(row)
		if before_value != after_value:
			_changed_rows.append(row)

	var actual_gain := int(_preview.get("potential_gain", 0))
	var potential_copy := (
		"Potential +%d is awarded. " % actual_gain
		if actual_gain > 0
		else "Potential is already capped. "
	)
	_preserved_note.text = (
		"Level and EXP reset to 1 / 0. " + potential_copy
		+ "Link, training, aptitudes, learned techniques, equipment and evolution history are preserved."
	)


func _form_card() -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 82)
	panel.add_theme_stylebox_override(
		"panel",
		_surface_style(Color(0.025, 0.045, 0.075, 0.84), UI.FRAME_DARK, 0.40)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)

	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(58, 72)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_stretch_ratio = 0.40
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 0.60
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)

	var name_label := _label("UNKNOWN", 13, UI.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(name_label)
	var rank_label := _label("UNKNOWN", 9, UI.SUBTLE, true)
	info.add_child(rank_label)

	return {
		"panel": panel,
		"portrait": portrait,
		"name": name_label,
		"rank": rank_label,
	}


func _stat_row(stat_name: String, before_value: int, after_value: int) -> PanelContainer:
	var delta := after_value - before_value
	var accent := UI.BLUE if delta > 0 else UI.RED if delta < 0 else UI.FRAME_DARK
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 30)
	panel.add_theme_stylebox_override(
		"panel",
		_surface_style(
			Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.72)
			if delta != 0
			else Color(0.025, 0.035, 0.052, 0.56),
			accent,
			0.66 if delta != 0 else 0.22
		)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)

	var stat := _label(stat_name, 10, UI.SUBTLE, true)
	stat.custom_minimum_size = Vector2(78, 0)
	row.add_child(stat)

	var before := _label(str(before_value), 12, UI.TEXT, true)
	before.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	before.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(before)

	var arrow := _label("→", 12, UI.SUBTLE, true)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.custom_minimum_size = Vector2(20, 0)
	row.add_child(arrow)

	var after := _label(str(after_value), 12, UI.TEXT if delta == 0 else accent, true)
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if delta != 0:
		after.add_theme_constant_override("outline_size", 4)
		after.add_theme_color_override("font_outline_color", Color(accent.r, accent.g, accent.b, 0.32))
		after.add_theme_constant_override("shadow_outline_size", 4)
		after.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.24))
	row.add_child(after)

	var delta_label := _label(_format_delta(delta), 10, UI.SUBTLE if delta == 0 else accent, true)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(delta_label)
	return panel


func _format_delta(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	if delta < 0:
		return str(delta)
	return "—"


func _play_open_animation() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_backdrop.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var target_scale := _panel.scale
	_panel.scale = target_scale * 0.94
	for row: Control in _changed_rows:
		row.modulate.a = 0.34

	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.14)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	_open_tween.tween_property(_panel, "scale", target_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index in range(_changed_rows.size()):
		_open_tween.tween_property(_changed_rows[index], "modulate:a", 1.0, 0.16).set_delay(0.05 + float(index) * 0.025)


func _focus_safe_default() -> void:
	if visible and _cancel_button != null and not _cancel_button.disabled:
		_cancel_button.grab_focus()


func _confirm() -> void:
	if not visible or _closing:
		return
	var direction := String(_preview.get("direction", ""))
	var target_seed := String(_preview.get("to_seed", ""))
	if direction.is_empty() or target_seed.is_empty():
		cancel()
		return
	close_immediately()
	confirmed.emit(direction, target_seed)


func _finish_cancel() -> void:
	visible = false
	_closing = false
	_preview.clear()
	if (
		is_instance_valid(_previous_focus)
		and _previous_focus.is_visible_in_tree()
		and _previous_focus.focus_mode != Control.FOCUS_NONE
	):
		_previous_focus.grab_focus()
	_previous_focus = null
	cancelled.emit()


func _layout() -> void:
	if _panel == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var scale_factor := UI.ui_scale(viewport_obj)
	var safe := 12.0
	var available_w := maxf(1.0, physical.x - safe * 2.0)
	var available_h := maxf(1.0, physical.y - safe * 2.0)
	var modal_w := minf(760.0, available_w)
	var modal_h := minf(680.0, available_h)
	var narrow := modal_w < 540.0 or physical.y > physical.x * 1.10

	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2((physical.x - modal_w) * 0.5, (physical.y - modal_h) * 0.5) * scale_factor
	_panel.size = Vector2(modal_w, modal_h)
	_title.add_theme_font_size_override("font_size", 18 if narrow else 23)
	_subtitle.add_theme_font_size_override("font_size", 10 if narrow else 11)
	_set_panel_margins(14 if narrow else 22, 14 if narrow else 20, 14 if narrow else 22, 12 if narrow else 18)

	_route_grid.columns = 1 if narrow else 3
	_route_arrow.text = "↓" if narrow else "→"
	_route_arrow.custom_minimum_size = Vector2(0, 28) if narrow else Vector2(34, 82)
	_button_grid.columns = 1 if modal_w < 390.0 else 2


func _set_panel_margins(left: int, top: int, right: int, bottom: int) -> void:
	if _panel_margin == null:
		return
	_panel_margin.add_theme_constant_override("margin_left", left)
	_panel_margin.add_theme_constant_override("margin_top", top)
	_panel_margin.add_theme_constant_override("margin_right", right)
	_panel_margin.add_theme_constant_override("margin_bottom", bottom)


func _side_name(side: int) -> String:
	match side:
		SIDE_LEFT: return "left"
		SIDE_TOP: return "top"
		SIDE_RIGHT: return "right"
		SIDE_BOTTOM: return "bottom"
	return "left"


func _surface_style(background: Color, accent: Color, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style


func _label(text: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(104, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	SKIN.apply_button(button, accent)
	UI.apply_body_font(button)
	return button
