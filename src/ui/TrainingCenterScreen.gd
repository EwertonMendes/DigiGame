extends Control
class_name TrainingCenterScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const TrainingStatRowScript = preload("res://src/ui/TrainingStatRow.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")
const CONFIRM_ICON := preload("res://assets/ui/icons/confirm.svg")
const UNDO_ICON := preload("res://assets/ui/icons/undo.svg")
const MOVE_ICON := preload("res://assets/ui/icons/move.svg")

var STAT_META := {
	"hp": ["HP", UI.GREEN],
	"mp": ["SP", UI.BLUE.lightened(0.12)],
	"atk": ["ATK", UI.GOLD],
	"def": ["DEF", UI.CYAN],
	"int": ["INT", UI.PURPLE],
	"speed": ["SPD", UI.ORANGE],
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
var _title: Label
var _subtitle: Label
var _close: Button
var _collection_panel: PanelContainer
var _collection_scroll: ScrollContainer
var _collection_list: GridContainer
var _collection_buttons: Array[Button] = []
var _collection_ids: Array[String] = []
var _collection_previews: Array[DigimonWalkPreview] = []
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _status: Label
var _stat_rows: Dictionary = {}

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
	_status.text = "Build a plan, preview the result, then apply it."
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
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "TrainingCenterPanel"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", MENU.screen_frame())
	add_child(_frame)

	_menu_root = Control.new()
	_menu_root.name = "MenuContent"
	_menu_root.clip_contents = true
	_frame.add_child(_menu_root)

	_title = _single_line_label("TRAINING CENTER", 25, UI.TEXT, true)
	_menu_root.add_child(_title)
	_subtitle = _single_line_label("Use Potential to shape permanent tactical strengths.", 11, UI.MUTED)
	_menu_root.add_child(_subtitle)
	_status = _single_line_label("Build a plan, preview the result, then apply it.", 10, UI.CYAN, true)
	_menu_root.add_child(_status)
	_close = MENU.close_button(CLOSE_ICON, "Close Training Center")
	_close.pressed.connect(close_view)
	_menu_root.add_child(_close)

	_build_collection_panel(_menu_root)
	_build_detail_panel(_menu_root)

func _build_collection_panel(parent: Control) -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", MENU.surface(UI.CYAN, 0.80, 10))
	parent.add_child(_collection_panel)
	var margin := MENU.margin(10, 10, 10, 10)
	_collection_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	root.add_child(_single_line_label("DIGIMON COLLECTION", 11, UI.CYAN, true))
	root.add_child(_single_line_label("Choose the individual you want to train.", 9, UI.SUBTLE))

	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_collection_scroll.follow_focus = true
	_collection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_collection_scroll)
	SmoothScrollScript.attach(_collection_scroll)

	_collection_list = GridContainer.new()
	_collection_list.columns = 1
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("h_separation", 8)
	_collection_list.add_theme_constant_override("v_separation", 8)
	_collection_scroll.add_child(_collection_list)

func _build_detail_panel(parent: Control) -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", MENU.surface(UI.GOLD, 0.80, 10))
	parent.add_child(_detail_panel)
	var margin := MENU.margin(11, 10, 11, 10)
	_detail_panel.add_child(margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 7)
	_detail_scroll.add_child(_detail)

func _refresh() -> void:
	_refresh_collection()
	_refresh_detail()

func _refresh_collection() -> void:
	for child in _collection_list.get_children():
		child.queue_free()
	_collection_buttons.clear()
	_collection_ids.clear()
	_collection_previews.clear()
	var owned: Array[DigimonInstance] = OverworldState.get_collection_instances()
	var active_ids := OverworldState.get_active_party_ids()
	if owned.is_empty():
		_collection_list.add_child(_label("No Digimon in your collection.", 11, UI.MUTED))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = owned[0].id
	for instance: DigimonInstance in owned:
		var species := _database.get_by_seed(instance.species_seed)
		var active := active_ids.has(instance.id)
		var accent := UI.GOLD if active else UI.CYAN
		var button := _collection_button(instance, species, active, accent)
		_collection_list.add_child(button)
		_collection_buttons.append(button)
		_collection_ids.append(instance.id)
	_style_collection_selection()

func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool, accent: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 78)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.tooltip_text = "Train %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	button.pressed.connect(_select_instance.bind(instance.id))
	button.focus_entered.connect(_select_instance.bind(instance.id))
	MENU.style_action_button(button, accent, instance.id == _selected_id)

	var margin := MENU.margin(8, 7, 9, 7)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.name = "WalkPreview"
	preview.custom_minimum_size = Vector2(58, 58)
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
	copy.add_child(_single_line_label(name.to_upper(), 13, UI.TEXT, true))
	var location := "PARTY" if active else "STORAGE"
	copy.add_child(_single_line_label("LV %d  ·  %s" % [instance.level, location], 10, accent.lightened(0.08), true))
	copy.add_child(_single_line_label("POTENTIAL %d" % instance.potential, 9, UI.PURPLE.lightened(0.10), true))
	return button

func _style_collection_selection() -> void:
	for index in range(_collection_buttons.size()):
		var id := _collection_ids[index] if index < _collection_ids.size() else ""
		var instance := OverworldState.get_instance_by_id(id)
		var active := OverworldState.get_active_party_ids().has(id)
		var accent := UI.GOLD if active else UI.CYAN
		MENU.style_action_button(_collection_buttons[index], UI.GREEN if id == _selected_id else accent, id == _selected_id)
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
	for child in _detail.get_children():
		child.queue_free()
	_stat_rows.clear()
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_label("Select a Digimon from your collection.", 12, UI.MUTED))
		return
	var species := _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_detail.add_child(_label("Species data unavailable.", 12, UI.RED))
		return

	var preview := DigimonInstance.from_dict(instance.to_dict())
	if _has_plan():
		_training.apply_plan(preview, _pending_stats, _pending_mobility)
	var current_stats := _calculator.get_all_stats(instance, species)
	var preview_stats := _calculator.get_all_stats(preview, species)
	_build_identity(instance, species)
	_build_capacity(instance)
	_detail.add_child(_section_heading("ATTRIBUTE TRAINING", UI.CYAN))
	_detail.add_child(_single_line_label("Each point costs 1 Capacity and grants +%.1f%% to that attribute." % _training.stat_bonus_percent(1), 9, UI.MUTED))

	var stat_grid := GridContainer.new()
	stat_grid.columns = 1 if _compact_layout else 2
	stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 7)
	_detail.add_child(stat_grid)
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		_build_stat_row(stat_grid, instance, stat_key, current_stats, preview_stats)

	_build_mobility(instance, current_stats, preview_stats)
	_build_plan_actions(instance)

func _build_identity(instance: DigimonInstance, species: Dictionary) -> void:
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MENU.card(accent, true))
	_detail.add_child(card)
	var margin := MENU.margin(9, 7, 9, 7)
	card.add_child(margin)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 10)
	margin.add_child(hero)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(76, 68)
	portrait_frame.add_theme_stylebox_override("panel", MENU.portrait(accent))
	hero.add_child(portrait_frame)
	var portrait_margin := MENU.margin(4, 4, 4, 4)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(66, 58)
	portrait.set_species(String(species.get("name", "Unknown")))
	portrait_margin.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	hero.add_child(info)
	info.add_child(_single_line_label(instance.get_display_name(String(species.get("name", "Unknown"))).to_upper(), 18, UI.TEXT, true))
	info.add_child(_single_line_label("%s  ·  LV %d" % [rank.to_upper(), instance.level], 10, accent.lightened(0.10), true))
	info.add_child(_single_line_label("Permanent training stays with this Digimon through Digivolution and Degeneration.", 9, UI.SUBTLE))

func _build_capacity(instance: DigimonInstance) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MENU.card(UI.PURPLE, false))
	_detail.add_child(card)
	var margin := MENU.margin(9, 7, 9, 7)
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	margin.add_child(body)
	var total := _training.capacity_for(instance)
	var used := _training.used_capacity(instance)
	var planned := _training.plan_cost(instance, _pending_stats, _pending_mobility)

	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 14)
	body.add_child(metrics)

	var potential_box := VBoxContainer.new()
	potential_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potential_box.add_theme_constant_override("separation", 3)
	metrics.add_child(potential_box)
	potential_box.add_child(_single_line_label("POTENTIAL %d / 100" % instance.potential, 10, UI.PURPLE, true))
	potential_box.add_child(_progress(UI.PURPLE, 100, instance.potential))

	var capacity_box := VBoxContainer.new()
	capacity_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_box.add_theme_constant_override("separation", 3)
	metrics.add_child(capacity_box)
	var capacity_text := "CAPACITY %d / %d" % [used + planned, total]
	if planned > 0:
		capacity_text += "  ·  +%d PLANNED" % planned
	capacity_box.add_child(_single_line_label(capacity_text, 10, UI.GOLD if planned == 0 else UI.GREEN, true))
	capacity_box.add_child(_progress(UI.GOLD, total, used + planned))
	body.add_child(_single_line_label("Base 10  ·  +1 Capacity for every 2 Potential", 9, UI.SUBTLE))

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
	row.configure(stat_key, String(meta[0]), int(current_stats.get(stat_key, 0)), int(preview_stats.get(stat_key, 0)), int(instance.training.get(stat_key, 0)), int(_pending_stats.get(stat_key, 0)), _training.max_points_per_stat(), _training.can_apply_plan(instance, test_plan, _pending_mobility), meta[1] as Color)

func _build_mobility(instance: DigimonInstance, current_stats: Dictionary, preview_stats: Dictionary) -> void:
	_detail.add_child(_section_heading("TACTICAL MOBILITY", UI.GOLD))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MENU.card(UI.GOLD, false))
	_detail.add_child(panel)
	var margin := MENU.margin(9, 7, 9, 7)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	root.add_child(line)
	var icon := TextureRect.new()
	icon.texture = MOVE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(20, 20)
	icon.modulate = UI.GOLD
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var mov := _single_line_label("MOV %d" % int(current_stats.get("mov", 0)), 13, UI.TEXT, true)
	mov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(preview_stats.get("mov", 0)) != int(current_stats.get("mov", 0)):
		mov.text += "  →  %d" % int(preview_stats.get("mov", 0))
		mov.add_theme_color_override("font_color", UI.GREEN)
	line.add_child(mov)
	var target_level := _training.mobility_level(instance) + _pending_mobility
	line.add_child(_single_line_label("MOBILITY %d / 2" % target_level, 10, UI.GOLD, true))

	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 8)
	root.add_child(actions)
	var undo := MENU.action_button("UNDO MOV", UI.MUTED, 36)
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.disabled = _pending_mobility <= 0
	undo.pressed.connect(_remove_mobility)
	actions.add_child(undo)
	var add := MENU.action_button("TRAIN MOV +1", UI.GOLD, 36)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.disabled = not _training.can_apply_plan(instance, _pending_stats, _pending_mobility + 1)
	add.pressed.connect(_add_mobility)
	actions.add_child(add)
	if target_level < 2:
		var next_level := target_level + 1
		root.add_child(_single_line_label("Next upgrade: Potential %d  ·  %d Capacity" % [_training.mobility_potential_for_level(next_level), _training.mobility_cost_for_level(next_level)], 9, UI.MUTED))
	else:
		root.add_child(_single_line_label("Maximum permanent mobility training reached", 9, UI.GREEN, true))

func _build_plan_actions(instance: DigimonInstance) -> void:
	_detail.add_child(_section_heading("TRAINING PLAN", UI.GREEN))
	var has_plan := _has_plan()
	var validation := _training.validate_plan(instance, _pending_stats, _pending_mobility)
	var message := "Ready to apply this plan." if has_plan and validation.is_empty() else (validation if has_plan else "No pending changes.")
	_detail.add_child(_single_line_label(message, 9, UI.GREEN if has_plan and validation.is_empty() else UI.MUTED, true))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("h_separation", 10)
	_detail.add_child(actions)
	var discard := _icon_text_button(UNDO_ICON, "DISCARD PLAN", UI.MUTED)
	discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard.disabled = not has_plan
	discard.pressed.connect(_discard_plan)
	actions.add_child(discard)
	var apply := _icon_text_button(CONFIRM_ICON, "APPLY TRAINING", UI.GREEN)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.disabled = not has_plan or not validation.is_empty()
	apply.pressed.connect(_apply_plan)
	actions.add_child(apply)

func _select_instance(instance_id: String) -> void:
	if instance_id.is_empty() or OverworldState.get_instance_by_id(instance_id) == null:
		return
	if _selected_id == instance_id:
		_style_collection_selection()
		return
	_selected_id = instance_id
	_clear_plan()
	_status.text = "Training plan cleared for the new selection."
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
		_status.text = error
		return
	_pending_stats = test_plan
	_refresh_detail()
	var row := _stat_rows.get(stat_key) as TrainingStatRow
	if row != null:
		row.pulse()

func _remove_stat(stat_key: String) -> void:
	var value := int(_pending_stats.get(stat_key, 0))
	if value <= 0:
		return
	if value == 1:
		_pending_stats.erase(stat_key)
	else:
		_pending_stats[stat_key] = value - 1
	_refresh_detail()

func _add_mobility() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var test_steps := _pending_mobility + 1
	var error := _training.validate_plan(instance, _pending_stats, test_steps)
	if not error.is_empty():
		_status.text = error
		return
	_pending_mobility = test_steps
	_refresh_detail()

func _remove_mobility() -> void:
	_pending_mobility = maxi(0, _pending_mobility - 1)
	_refresh_detail()

func _discard_plan() -> void:
	_clear_plan()
	_status.text = "Pending training discarded."
	_refresh_detail()

func _apply_plan() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var error := _training.validate_plan(instance, _pending_stats, _pending_mobility)
	if not error.is_empty():
		_status.text = error
		return
	if not OverworldState.apply_training_plan(_selected_id, _pending_stats, _pending_mobility):
		_status.text = "Training could not be applied."
		return
	_clear_plan()
	_status.text = "Training applied and saved."
	_refresh()
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.08)
	tween.tween_property(_detail_panel, "modulate", Color.WHITE, 0.20)

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
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 900.0)
	var edge := 12.0 if compact else 22.0
	var width := minf(1240.0, maxf(1.0, physical.x - edge * 2.0))
	var height := minf(760.0, maxf(1.0, physical.y - edge * 2.0))
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_frame.clip_contents = true
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	_title.position = Vector2(24.0, 14.0)
	_title.size = Vector2(width - 112.0, 32.0)
	_subtitle.position = Vector2(24.0, 45.0)
	_subtitle.size = Vector2(width - 112.0, 20.0)
	_status.position = Vector2(24.0, 69.0)
	_status.size = Vector2(width - 112.0, 20.0)
	_close.position = Vector2(width - 68.0, 14.0)
	_close.size = Vector2(44.0, 44.0)

	var content_y := 100.0
	var bottom := 20.0
	if compact:
		var collection_h := minf(182.0, height * 0.28)
		_collection_panel.position = Vector2(20.0, content_y)
		_collection_panel.size = Vector2(width - 40.0, collection_h)
		_detail_panel.position = Vector2(20.0, content_y + collection_h + 12.0)
		_detail_panel.size = Vector2(width - 40.0, height - content_y - collection_h - bottom - 12.0)
		_collection_list.columns = 1 if width < 560.0 else 2
	else:
		var collection_w := clampf(width * 0.255, 280.0, 320.0)
		var gap := 14.0
		_collection_panel.position = Vector2(20.0, content_y)
		_collection_panel.size = Vector2(collection_w, height - content_y - bottom)
		_detail_panel.position = Vector2(20.0 + collection_w + gap, content_y)
		_detail_panel.size = Vector2(width - collection_w - gap - 40.0, height - content_y - bottom)
		_collection_list.columns = 1

	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_collection_panel.clip_contents = true
	_detail_panel.clip_contents = true
	if compact != _compact_layout:
		_compact_layout = compact
		call_deferred("_refresh_detail")

func _section_heading(text: String, accent: Color) -> Label:
	var label := _single_line_label(text, 10, accent.lightened(0.08), true)
	label.custom_minimum_size.y = 18
	return label

func _progress(accent: Color, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.01, 0.015, 0.88)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _icon_text_button(texture: Texture2D, text: String, accent: Color) -> Button:
	var button := MENU.action_button(text, accent, 40)
	button.icon = texture
	button.expand_icon = false
	return button
