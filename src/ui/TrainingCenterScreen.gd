extends Control
class_name TrainingCenterScreen

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const TrainingStatRowScript = preload("res://src/ui/TrainingStatRow.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const ProceduralIconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CONFIRM_ICON := preload("res://assets/ui/icons/confirm.svg")
const UNDO_ICON := preload("res://assets/ui/icons/undo.svg")

const DESKTOP_BREAKPOINT := 1040.0
const FRAME_MAX_WIDTH := 1380.0
const FRAME_MAX_HEIGHT := 850.0
const HEADER_HEIGHT := 60.0
const HINT_HEIGHT := 50.0

var STAT_META := {
	"hp": ["HP", V2.GREEN],
	"mp": ["SP", V2.BLUE],
	"atk": ["ATK", V2.AMBER],
	"def": ["DEF", V2.CYAN],
	"int": ["INT", V2.PURPLE],
	"speed": ["SPD", V2.ORANGE],
}

var _database: DigimonDatabase
var _training: DigimonTrainingService
var _calculator: DigimonStatCalculator
var _selected_id := ""
var _pending_stats: Dictionary = {}
var _pending_mobility := 0
var _compact_layout := false

var _frame: PanelContainer
var _menu_root: Control
var _header: DigiModalHeader
var _hint_bar: DigiInputHintBar
var _collection_panel: PanelContainer
var _collection_scroll: ScrollContainer
var _collection_list: GridContainer
var _collection_header: DigiSectionHeader
var _collection_buttons: Array[Button] = []
var _collection_ids: Array[String] = []
var _collection_previews: Array[DigimonWalkPreview] = []
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _status_panel: PanelContainer
var _status_icon: DigiProceduralIcon
var _status: Label
var _stat_rows: Dictionary = {}
var _mobility_minus: Button
var _mobility_plus: Button
var _discard_button: Button
var _apply_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_training = TrainingServiceScript.new() as DigimonTrainingService
	_calculator = StatCalculatorScript.new() as DigimonStatCalculator
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	OverworldState.collection_changed.connect(_on_collection_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_screen() -> void:
	visible = true
	var owned: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not owned.is_empty():
		_selected_id = owned[0].id
	_clear_plan()
	_set_status("Build a plan, preview the result, then apply it.", V2.CYAN)
	_layout()
	_refresh()
	call_deferred("_layout")
	call_deferred("_focus_selected_collection")
	_frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close_view() -> void:
	_clear_plan()
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		close_view()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = V2.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "TrainingCenterV2"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color(V2.BACKDROP.r, V2.BACKDROP.g, V2.BACKDROP.b, 1.0), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 10, Vector4.ZERO, 0.18)
	)
	add_child(_frame)

	_menu_root = Control.new()
	_menu_root.name = "TrainingV2Content"
	_menu_root.clip_contents = true
	_frame.add_child(_menu_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "TrainingHeader"
	_header.configure("TRAINING", "Permanent Growth", 0, false)
	_header.configure_tabs([], "")
	_header.close_requested.connect(close_view)
	_menu_root.add_child(_header)

	_build_collection_panel(_menu_root)
	_build_detail_panel(_menu_root)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "TrainingInputHints"
	_hint_bar.set_description("Select a Digimon, build a permanent training plan, then apply it.")
	_menu_root.add_child(_hint_bar)


func _build_collection_panel(parent: Control) -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.name = "TrainingRoster"
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))
	parent.add_child(_collection_panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	_collection_panel.add_child(root)

	_collection_header = SectionHeaderScript.new() as DigiSectionHeader
	_collection_header.configure("DIGIMON", "", V2.CYAN, "digimon")
	root.add_child(_collection_header)

	var intro_margin := _margin(12, 9, 12, 6)
	root.add_child(intro_margin)
	intro_margin.add_child(_label("Choose the individual you want to train.", 10, V2.MUTED))

	var scroll_margin := _margin(8, 2, 5, 8)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll_margin)

	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_collection_scroll.follow_focus = true
	_collection_scroll.scroll_deadzone = 8
	_collection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_collection_scroll)
	SmoothScrollScript.attach(_collection_scroll)

	_collection_list = GridContainer.new()
	_collection_list.columns = 1
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("h_separation", 8)
	_collection_list.add_theme_constant_override("v_separation", 8)
	_collection_scroll.add_child(_collection_list)


func _build_detail_panel(parent: Control) -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "TrainingDetails"
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	parent.add_child(_detail_panel)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(outer)

	_status_panel = PanelContainer.new()
	_status_panel.custom_minimum_size.y = 38.0
	outer.add_child(_status_panel)
	var status_margin := _margin(12, 6, 12, 6)
	_status_panel.add_child(status_margin)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_margin.add_child(status_row)
	_status_icon = ProceduralIconScript.new() as DigiProceduralIcon
	_status_icon.custom_minimum_size = Vector2(18.0, 18.0)
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(_status_icon)
	_status = _single_line_label("Build a plan, preview the result, then apply it.", 10, V2.CYAN, true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status)
	_set_status(_status.text, V2.CYAN)

	var detail_frame := PanelContainer.new()
	detail_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_frame.clip_contents = true
	detail_frame.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.60), 8))
	outer.add_child(detail_frame)

	var detail_margin := _margin(10, 10, 6, 10)
	detail_frame.add_child(detail_margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.scroll_deadzone = 8
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)

	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail)


func _refresh() -> void:
	_refresh_collection()
	_refresh_detail()


func _clear_children_now(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_collection() -> void:
	_clear_children_now(_collection_list)
	_collection_buttons.clear()
	_collection_ids.clear()
	_collection_previews.clear()
	var owned: Array[DigimonInstance] = OverworldState.get_collection_instances()
	var active_ids := OverworldState.get_active_party_ids()
	_collection_header.set_trailing("%d OWNED" % owned.size())
	if owned.is_empty():
		_collection_list.add_child(_label("No Digimon in your collection.", 11, V2.MUTED))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = owned[0].id
	for instance: DigimonInstance in owned:
		var species := _database.get_by_seed(instance.species_seed)
		var active := active_ids.has(instance.id)
		var button := _collection_button(instance, species, active)
		_collection_list.add_child(button)
		_collection_buttons.append(button)
		_collection_ids.append(instance.id)
	_style_collection_selection()


func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Train %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	button.pressed.connect(_select_instance.bind(instance.id))
	button.focus_entered.connect(_select_instance.bind(instance.id))
	_style_collection_button(button, instance.id == _selected_id)

	var margin := _margin(10, 8, 10, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.name = "WalkPreview"
	preview.custom_minimum_size = Vector2(60, 60)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", "")))
	preview.set_active(instance.id == _selected_id)
	row.add_child(preview)
	_collection_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := instance.get_display_name(String(species.get("name", "Unknown")))
	copy.add_child(_single_line_label(name.to_upper(), 13, V2.TEXT, true))
	var location := "PARTY" if active else "STORAGE"
	var location_color := V2.GREEN if active else V2.MUTED
	copy.add_child(_single_line_label("LV %d  ·  %s" % [instance.level, location], 9, location_color, true))
	copy.add_child(_single_line_label("POTENTIAL %d  ·  TIER %s" % [instance.potential, instance.tier], 9, V2.PURPLE, true))
	return button


func _style_collection_button(button: Button, selected: bool) -> void:
	var accent := V2.AMBER if selected else V2.CYAN
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "selected" if selected else "normal", 8))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 8))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 8))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 8))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 8))


func _style_collection_selection() -> void:
	for index in range(_collection_buttons.size()):
		var id := _collection_ids[index] if index < _collection_ids.size() else ""
		var instance := OverworldState.get_instance_by_id(id)
		_style_collection_button(_collection_buttons[index], id == _selected_id)
		if index < _collection_previews.size():
			_collection_previews[index].set_active(id == _selected_id)
		if instance == null:
			_collection_buttons[index].disabled = true


func _focus_selected_collection() -> void:
	if not visible:
		return
	for index in range(_collection_ids.size()):
		if _collection_ids[index] == _selected_id and index < _collection_buttons.size():
			_collection_buttons[index].grab_focus()
			return
	if not _collection_buttons.is_empty():
		_collection_buttons[0].grab_focus()


func _refresh_detail() -> void:
	var previous_scroll := _detail_scroll.scroll_vertical if _detail_scroll != null else 0
	_clear_children_now(_detail)
	_stat_rows.clear()
	_mobility_minus = null
	_mobility_plus = null
	_discard_button = null
	_apply_button = null
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_empty_state("Select a Digimon from your collection."))
		call_deferred("_restore_detail_scroll", previous_scroll)
		return
	var species := _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_detail.add_child(_empty_state("Species data unavailable.", V2.RED))
		call_deferred("_restore_detail_scroll", previous_scroll)
		return

	var preview := DigimonInstance.from_dict(instance.to_dict())
	if _has_plan():
		_training.apply_plan(preview, _pending_stats, _pending_mobility)
	var current_stats := _calculator.get_all_stats(instance, species)
	var preview_stats := _calculator.get_all_stats(preview, species)
	_build_identity(instance, species)
	_build_capacity(instance)

	var attribute_header := SectionHeaderScript.new() as DigiSectionHeader
	attribute_header.configure(
		"ATTRIBUTE TRAINING",
		"1 point = +%.1f%%" % _training.stat_bonus_percent(1),
		V2.CYAN,
		"training"
	)
	_detail.add_child(attribute_header)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 1 if _compact_layout else 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 8)
	_detail.add_child(stat_grid)
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		_build_stat_row(stat_grid, instance, stat_key, current_stats, preview_stats)

	_build_mobility(instance, current_stats, preview_stats)
	_build_plan_actions(instance)
	call_deferred("_restore_detail_scroll", previous_scroll)


func _restore_detail_scroll(position: int) -> void:
	if _detail_scroll == null or not is_instance_valid(_detail_scroll):
		return
	var scroll_bar := _detail_scroll.get_v_scroll_bar()
	var maximum := maxi(0, int(round(scroll_bar.max_value - scroll_bar.page)))
	_detail_scroll.scroll_vertical = clampi(position, 0, maximum)


func _build_identity(instance: DigimonInstance, species: Dictionary) -> void:
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", V2.outlined_surface(accent, false, 8))
	_detail.add_child(card)
	var margin := _margin(12, 10, 12, 10)
	card.add_child(margin)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	margin.add_child(hero)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(86, 76)
	portrait_frame.add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.98), Color(accent.r, accent.g, accent.b, 0.54), 8)
	)
	hero.add_child(portrait_frame)
	var portrait_margin := _margin(5, 5, 5, 5)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(74, 64)
	portrait.set_species(String(species.get("name", "Unknown")))
	portrait_margin.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	hero.add_child(info)
	info.add_child(_single_line_label(instance.get_display_name(String(species.get("name", "Unknown"))).to_upper(), 19, V2.TEXT, true))
	info.add_child(_single_line_label("%s  ·  LV %d  ·  TIER %s" % [rank.to_upper(), instance.level, instance.tier], 10, accent, true))
	info.add_child(_single_line_label("Training is permanent and stays with this individual through Digivolution and Degeneration.", 9, V2.MUTED))


func _build_capacity(instance: DigimonInstance) -> void:
	var total := _training.capacity_for(instance)
	var used := _training.used_capacity(instance)
	var planned := _training.plan_cost(instance, _pending_stats, _pending_mobility)
	var remaining := maxi(0, total - used - planned)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TRAINING BUDGET", "%d AVAILABLE" % remaining, V2.PURPLE, "training")
	_detail.add_child(header)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.PURPLE.r, V2.PURPLE.g, V2.PURPLE.b, 0.40), 8))
	_detail.add_child(card)
	var margin := _margin(12, 10, 12, 10)
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)

	var metrics := GridContainer.new()
	metrics.columns = 1 if _compact_layout else 3
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 10)
	metrics.add_theme_constant_override("v_separation", 8)
	body.add_child(metrics)
	metrics.add_child(_metric_block("POTENTIAL", "%d / 100" % instance.potential, V2.PURPLE, 100, instance.potential))
	metrics.add_child(_metric_block("CAPACITY", "%d / %d" % [used + planned, total], V2.AMBER if planned > 0 else V2.CYAN, total, used + planned))
	metrics.add_child(_metric_block("AVAILABLE", str(remaining), V2.GREEN if remaining > 0 else V2.RED, total, remaining))

	var explanation := "Base 10 Capacity  ·  +1 for every 2 Potential"
	if planned > 0:
		explanation += "  ·  %d Capacity reserved by this plan" % planned
	body.add_child(_single_line_label(explanation, 9, V2.MUTED))


func _metric_block(title: String, value: String, accent: Color, maximum: int, current: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 160.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE_SOFT, Color(accent.r, accent.g, accent.b, 0.24), 7))
	var margin := _margin(10, 7, 10, 7)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	var label := _single_line_label(title, 9, V2.MUTED, true)
	label.custom_minimum_size.x = 72.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var value_label := _single_line_label(value, 12, accent, true)
	value_label.custom_minimum_size.x = 74.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_label)
	body.add_child(_progress(accent, maximum, current))
	return panel


func _build_stat_row(parent: Container, instance: DigimonInstance, stat_key: String, current_stats: Dictionary, preview_stats: Dictionary) -> void:
	var meta: Array = STAT_META[stat_key]
	var test_plan := _pending_stats.duplicate(true)
	test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
	var row := TrainingStatRowScript.new() as TrainingStatRow
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_requested.connect(_add_stat)
	row.remove_requested.connect(_remove_stat)
	parent.add_child(row)
	_stat_rows[stat_key] = row
	row.configure(
		stat_key,
		String(meta[0]),
		int(current_stats.get(stat_key, 0)),
		int(preview_stats.get(stat_key, 0)),
		int(instance.training.get(stat_key, 0)),
		int(_pending_stats.get(stat_key, 0)),
		_training.max_points_per_stat(),
		_training.can_apply_plan(instance, test_plan, _pending_mobility),
		meta[1] as Color
	)


func _build_mobility(instance: DigimonInstance, current_stats: Dictionary, preview_stats: Dictionary) -> void:
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TACTICAL MOBILITY", "PERMANENT", V2.AMBER, "move")
	_detail.add_child(header)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.36), 8))
	_detail.add_child(panel)
	var margin := _margin(12, 9, 12, 9)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 10)
	root.add_child(line)
	var icon := ProceduralIconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(26, 26)
	icon.configure("move", V2.AMBER, 1.8)
	line.add_child(icon)
	var mov := _single_line_label("MOV %d" % int(current_stats.get("mov", 0)), 15, V2.TEXT, true)
	mov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(preview_stats.get("mov", 0)) != int(current_stats.get("mov", 0)):
		mov.text += "  →  %d" % int(preview_stats.get("mov", 0))
		mov.add_theme_color_override("font_color", V2.GREEN)
	line.add_child(mov)
	var target_level := _training.mobility_level(instance) + _pending_mobility
	var mobility_level_label := _single_line_label("MOBILITY %d / 2" % target_level, 10, V2.AMBER, true)
	mobility_level_label.custom_minimum_size.x = 112.0
	mobility_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(mobility_level_label)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	root.add_child(actions)
	_mobility_minus = _action_button("UNDO MOV", V2.MUTED)
	_mobility_minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobility_minus.disabled = _pending_mobility <= 0
	_mobility_minus.pressed.connect(_remove_mobility)
	actions.add_child(_mobility_minus)
	_mobility_plus = _action_button("TRAIN MOV +1", V2.AMBER)
	_mobility_plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobility_plus.disabled = not _training.can_apply_plan(instance, _pending_stats, _pending_mobility + 1)
	_mobility_plus.pressed.connect(_add_mobility)
	actions.add_child(_mobility_plus)

	if target_level < 2:
		var next_level := target_level + 1
		root.add_child(_single_line_label(
			"Next upgrade requires Potential %d and costs %d Capacity." % [_training.mobility_potential_for_level(next_level), _training.mobility_cost_for_level(next_level)],
			9,
			V2.MUTED
		))
	else:
		root.add_child(_single_line_label("Maximum permanent mobility training reached.", 9, V2.GREEN, true))


func _build_plan_actions(instance: DigimonInstance) -> void:
	var has_plan := _has_plan()
	var validation := _training.validate_plan(instance, _pending_stats, _pending_mobility)
	var planned_cost := _training.plan_cost(instance, _pending_stats, _pending_mobility)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TRAINING PLAN", "%d CAPACITY" % planned_cost if has_plan else "NO CHANGES", V2.GREEN, "training")
	_detail.add_child(header)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.GREEN.r, V2.GREEN.g, V2.GREEN.b, 0.34) if has_plan else V2.BORDER_SOFT, 8))
	_detail.add_child(card)
	var margin := _margin(12, 9, 12, 10)
	card.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var summary := _plan_summary()
	var summary_color := V2.GREEN if has_plan and validation.is_empty() else V2.MUTED
	root.add_child(_single_line_label(summary, 10, summary_color, true))
	if has_plan and not validation.is_empty():
		var error_label := _label(validation, 9, V2.RED, true)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(error_label)
	elif has_plan:
		root.add_child(_single_line_label("Previewed values above are the values that will be saved.", 9, V2.MUTED))
	else:
		root.add_child(_single_line_label("Add attribute or mobility training to create a plan.", 9, V2.MUTED))

	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 10)
	root.add_child(actions)
	_discard_button = _icon_text_button(UNDO_ICON, "DISCARD PLAN", V2.MUTED)
	_discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_button.disabled = not has_plan
	_discard_button.pressed.connect(_discard_plan)
	actions.add_child(_discard_button)
	_apply_button = _icon_text_button(CONFIRM_ICON, "APPLY TRAINING", V2.GREEN)
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.disabled = not has_plan or not validation.is_empty()
	_apply_button.pressed.connect(_apply_plan)
	actions.add_child(_apply_button)


func _plan_summary() -> String:
	if not _has_plan():
		return "NO PENDING CHANGES"
	var parts := PackedStringArray()
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var points := int(_pending_stats.get(stat_key, 0))
		if points <= 0:
			continue
		var meta: Array = STAT_META[stat_key]
		parts.append("%s +%d" % [String(meta[0]), points])
	if _pending_mobility > 0:
		parts.append("MOV +%d" % _pending_mobility)
	return "  ·  ".join(parts)


func _select_instance(instance_id: String) -> void:
	if instance_id.is_empty() or OverworldState.get_instance_by_id(instance_id) == null:
		return
	if _selected_id == instance_id:
		_style_collection_selection()
		return
	_selected_id = instance_id
	_clear_plan()
	_set_status("Training plan cleared for the new selection.", V2.CYAN)
	_style_collection_selection()
	_refresh_detail()


func _add_stat(stat_key: String) -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var test_plan := _pending_stats.duplicate(true)
	test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
	var error := _training.validate_plan(instance, test_plan, _pending_mobility)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_pending_stats = test_plan
	_set_status("Plan updated. Review the preview before applying.", V2.GREEN)
	_refresh_detail()
	var row := _stat_rows.get(stat_key) as TrainingStatRow
	if row != null:
		row.pulse()
	call_deferred("_focus_stat_button", stat_key, true)


func _remove_stat(stat_key: String) -> void:
	var value := int(_pending_stats.get(stat_key, 0))
	if value <= 0:
		return
	if value == 1:
		_pending_stats.erase(stat_key)
	else:
		_pending_stats[stat_key] = value - 1
	_set_status("Plan updated.", V2.CYAN)
	_refresh_detail()
	call_deferred("_focus_stat_button", stat_key, int(_pending_stats.get(stat_key, 0)) <= 0)


func _focus_stat_button(stat_key: String, prefer_plus: bool) -> void:
	if not visible:
		return
	var row := _stat_rows.get(stat_key) as TrainingStatRow
	if row == null:
		return
	if prefer_plus:
		row.focus_plus()
	else:
		row.focus_minus()


func _add_mobility() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var test_steps := _pending_mobility + 1
	var error := _training.validate_plan(instance, _pending_stats, test_steps)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_pending_mobility = test_steps
	_set_status("Mobility added to the training plan.", V2.GREEN)
	_refresh_detail()
	call_deferred("_focus_mobility", true)


func _remove_mobility() -> void:
	_pending_mobility = maxi(0, _pending_mobility - 1)
	_set_status("Mobility plan updated.", V2.CYAN)
	_refresh_detail()
	call_deferred("_focus_mobility", _pending_mobility <= 0)


func _focus_mobility(prefer_plus: bool) -> void:
	if not visible:
		return
	if prefer_plus and _mobility_plus != null and not _mobility_plus.disabled:
		_mobility_plus.grab_focus()
	elif _mobility_minus != null and not _mobility_minus.disabled:
		_mobility_minus.grab_focus()
	elif _mobility_plus != null and not _mobility_plus.disabled:
		_mobility_plus.grab_focus()


func _discard_plan() -> void:
	_clear_plan()
	_set_status("Pending training discarded.", V2.CYAN)
	_refresh_detail()
	call_deferred("_focus_selected_collection")


func _apply_plan() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var error := _training.validate_plan(instance, _pending_stats, _pending_mobility)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	if not OverworldState.apply_training_plan(_selected_id, _pending_stats, _pending_mobility):
		_set_status("Training could not be applied.", V2.RED)
		return
	_clear_plan()
	_set_status("Training applied and saved.", V2.GREEN)
	_refresh()
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.08)
	tween.tween_property(_detail_panel, "modulate", Color.WHITE, 0.20)
	call_deferred("_focus_selected_collection")


func _set_status(text: String, accent: Color) -> void:
	if _status == null or _status_panel == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", accent)
	_status_icon.configure("info", accent, 1.45)
	_status_panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color(accent.r, accent.g, accent.b, 0.07), Color(accent.r, accent.g, accent.b, 0.34), 7)
	)


func _clear_plan() -> void:
	_pending_stats.clear()
	_pending_mobility = 0


func _has_plan() -> bool:
	if _pending_mobility > 0:
		return true
	for value in _pending_stats.values():
		if int(value) > 0:
			return true
	return false


func _on_collection_changed() -> void:
	if visible:
		var owned := OverworldState.get_collection_instances()
		if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not owned.is_empty():
			_selected_id = owned[0].id
		_refresh()


func _layout() -> void:
	if not visible or _frame == null or _menu_root == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var stacked := V2.is_compact(get_viewport(), DESKTOP_BREAKPOINT)
	var edge := 8.0 if stacked else 18.0
	var width := minf(FRAME_MAX_WIDTH, maxf(1.0, physical.x - edge * 2.0))
	var height := minf(FRAME_MAX_HEIGHT, maxf(1.0, physical.y - edge * 2.0))
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	_header.position = Vector2.ZERO
	_header.size = Vector2(width, HEADER_HEIGHT)
	_hint_bar.position = Vector2(0.0, height - HINT_HEIGHT)
	_hint_bar.size = Vector2(width, HINT_HEIGHT)

	var content_y := HEADER_HEIGHT + 10.0
	var content_h := height - content_y - HINT_HEIGHT - 8.0
	if stacked:
		var collection_h := clampf(content_h * 0.27, 145.0, 205.0)
		_collection_panel.position = Vector2(10.0, content_y)
		_collection_panel.size = Vector2(width - 20.0, collection_h)
		_detail_panel.position = Vector2(10.0, content_y + collection_h + 10.0)
		_detail_panel.size = Vector2(width - 20.0, content_h - collection_h - 10.0)
		_collection_list.columns = 1 if width < 620.0 else 2
	else:
		var collection_w := clampf(width * 0.245, 286.0, 330.0)
		var gap := 12.0
		_collection_panel.position = Vector2(12.0, content_y)
		_collection_panel.size = Vector2(collection_w, content_h)
		_detail_panel.position = Vector2(12.0 + collection_w + gap, content_y)
		_detail_panel.size = Vector2(width - collection_w - gap - 24.0, content_h)
		_collection_list.columns = 1

	if stacked != _compact_layout:
		_compact_layout = stacked
		call_deferred("_refresh_detail")


func _progress(accent: Color, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	return bar


func _action_button(text: String, accent: Color, height: float = 52.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
	V2.apply_heading(button)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 7))
	return button


func _icon_text_button(texture: Texture2D, text: String, accent: Color) -> Button:
	var button := _action_button(text, accent)
	button.icon = texture
	button.expand_icon = false
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", V2.WHITE)
	button.add_theme_color_override("icon_focus_color", V2.WHITE)
	button.add_theme_color_override("icon_pressed_color", V2.WHITE)
	button.add_theme_color_override("icon_disabled_color", V2.SUBTLE)
	return button


func _empty_state(text: String, accent: Color = V2.MUTED) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 96.0
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(accent.r, accent.g, accent.b, 0.30), 8))
	var margin := _margin(16, 16, 16, 16)
	panel.add_child(margin)
	var label := _label(text, 12, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return panel


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label