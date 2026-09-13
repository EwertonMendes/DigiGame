extends Control
class_name TrainingCenterScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const TrainingStatRowScript = preload("res://src/ui/TrainingStatRow.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")
const CONFIRM_ICON := preload("res://assets/ui/icons/confirm.svg")
const UNDO_ICON := preload("res://assets/ui/icons/undo.svg")
const MOVE_ICON := preload("res://assets/ui/icons/move.svg")

const STAT_META := {
	"hp": ["HP", Color(0.36, 0.95, 0.55)],
	"mp": ["SP", Color(0.38, 0.74, 1.0)],
	"atk": ["ATK", Color(1.0, 0.78, 0.28)],
	"def": ["DEF", Color(0.35, 0.90, 1.0)],
	"int": ["INT", Color(0.76, 0.54, 1.0)],
	"speed": ["SPD", Color(1.0, 0.56, 0.26)],
}

var _database: DigimonDatabase
var _training: DigimonTrainingService
var _calculator: DigimonStatCalculator
var _selected_id := ""
var _pending_stats: Dictionary = {}
var _pending_mobility := 0

var _frame: PanelContainer
var _body: GridContainer
var _collection_panel: PanelContainer
var _collection_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail: VBoxContainer
var _status: Label
var _capacity_label: Label
var _capacity_bar: ProgressBar
var _potential_label: Label
var _potential_bar: ProgressBar
var _apply_button: Button
var _discard_button: Button
var _stat_rows: Dictionary = {}
var _mobility_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_training = TrainingServiceScript.new() as DigimonTrainingService
	_calculator = StatCalculatorScript.new() as DigimonStatCalculator
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.roster_changed.connect(_on_collection_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false

func open_screen() -> void:
	visible = true
	var collection: Array[DigimonInstance] = OverworldState.get_roster_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not collection.is_empty():
		_selected_id = collection[0].id
	_clear_plan()
	_refresh()
	call_deferred("_layout")
	_animate_open()

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

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.003, 0.010, 0.026, 0.975)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.045, 0.085, 0.14, 0.99), Vector4.ZERO, 14.0))
	add_child(_frame)
	var outer := _margin(20, 18, 20, 20)
	_frame.add_child(outer)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	outer.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	heading.add_child(_label("TRAINING CENTER", 26, UI.TEXT, true))
	heading.add_child(_label("Build permanent strengths using this Digimon's Potential-based Training Capacity.", 11, UI.MUTED))
	var close := _icon_button(CLOSE_ICON, UI.MUTED, "Close Training Center")
	close.custom_minimum_size = Vector2(44, 44)
	close.pressed.connect(close_view)
	header.add_child(close)
	_status = _label("Plan training, preview the result, then apply it.", 11, UI.CYAN, true)
	_status.custom_minimum_size.y = 20
	root.add_child(_status)
	_body = GridContainer.new()
	_body.columns = 2
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 12)
	_body.add_theme_constant_override("v_separation", 12)
	root.add_child(_body)
	_build_collection_panel()
	_build_detail_panel()

func _build_collection_panel() -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.CYAN, Vector4(12, 12, 12, 12), 10.0))
	_body.add_child(_collection_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_collection_panel.add_child(root)
	root.add_child(_section_label("DIGIMON COLLECTION", UI.CYAN))
	root.add_child(_label("Select the individual you want to develop.", 10, UI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_collection_list)

func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.GOLD, Vector4(14, 14, 14, 14), 10.0))
	_body.add_child(_detail_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	scroll.add_child(_detail)

func _refresh() -> void:
	_refresh_collection_list()
	_refresh_detail()

func _refresh_collection_list() -> void:
	for child in _collection_list.get_children():
		child.queue_free()
	var collection: Array[DigimonInstance] = OverworldState.get_roster_instances()
	if collection.is_empty():
		_collection_list.add_child(_label("No Digimon available.", 12, UI.MUTED))
		return
	var active_ids := OverworldState.get_active_party_ids()
	for instance: DigimonInstance in collection:
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", "Unknown")))
		var active := active_ids.has(instance.id)
		var place := "PARTY" if active else "STORAGE"
		var button := _button("%s\nLv. %d   %s   POT %d" % [name.to_upper(), instance.level, place, instance.potential], UI.GOLD if active else UI.CYAN)
		button.custom_minimum_size = Vector2(0, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_instance.bind(instance.id))
		if instance.id == _selected_id:
			button.add_theme_stylebox_override("normal", SKIN.border_style(UI.GREEN, Vector4(13, 9, 13, 9), 9.0))
		_collection_list.add_child(button)

func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	_stat_rows.clear()
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_label("Select a Digimon from your collection.", 13, UI.MUTED))
		return
	var species := _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_detail.add_child(_label("Species data unavailable.", 13, UI.RED))
		return
	var preview := DigimonInstance.from_dict(instance.to_dict())
	if _has_plan():
		_training.apply_plan(preview, _pending_stats, _pending_mobility)
	var current_stats := _calculator.get_all_stats(instance, species)
	var preview_stats := _calculator.get_all_stats(preview, species)
	_build_identity(instance, species)
	_build_capacity(instance)
	_detail.add_child(_section_label("ATTRIBUTE TRAINING", UI.CYAN))
	_detail.add_child(_label("Each point costs 1 Training Capacity and grants +%.1f%% to that attribute." % _training.stat_bonus_percent(1), 10, UI.MUTED))
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var meta: Array = STAT_META[stat_key]
		var row := TrainingStatRowScript.new() as TrainingStatRow
		row.add_requested.connect(_add_stat)
		row.remove_requested.connect(_remove_stat)
		_detail.add_child(row)
		_stat_rows[stat_key] = row
		var test_plan := _pending_stats.duplicate(true)
		test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
		row.configure(stat_key, String(meta[0]), int(current_stats.get(stat_key, 0)), int(preview_stats.get(stat_key, 0)), int(instance.training.get(stat_key, 0)), int(_pending_stats.get(stat_key, 0)), _training.max_points_per_stat(), _training.can_apply_plan(instance, test_plan, _pending_mobility), meta[1] as Color)
	_build_mobility(instance, current_stats, preview_stats)
	_build_actions(instance)

func _build_identity(instance: DigimonInstance, species: Dictionary) -> void:
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	_detail.add_child(hero)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(124, 110)
	portrait_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.055, 0.10, 0.16, 0.96), Vector4(5, 5, 5, 5), 8.0))
	hero.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(116, 102)
	portrait.set_species(String(species.get("name", "Unknown")))
	portrait_frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	hero.add_child(info)
	info.add_child(_label(instance.get_display_name(String(species.get("name", "Unknown"))).to_upper(), 22, UI.TEXT, true))
	info.add_child(_label("%s   Lv. %d" % [String(species.get("rank", "Unknown")).to_upper(), instance.level], 11, UI.rank_color(String(species.get("rank", "Unknown"))), true))
	info.add_child(_label("Training is permanent across Digivolution and Degeneration.", 10, UI.SUBTLE))

func _build_capacity(instance: DigimonInstance) -> void:
	var summary := GridContainer.new()
	summary.columns = 2
	summary.add_theme_constant_override("h_separation", 12)
	summary.add_theme_constant_override("v_separation", 6)
	_detail.add_child(summary)
	var potential_box := VBoxContainer.new()
	potential_box.add_theme_constant_override("separation", 4)
	summary.add_child(potential_box)
	_potential_label = _label("POTENTIAL %d / 100" % instance.potential, 11, UI.PURPLE, true)
	potential_box.add_child(_potential_label)
	_potential_bar = _progress(UI.PURPLE)
	_potential_bar.max_value = 100
	_potential_bar.value = instance.potential
	potential_box.add_child(_potential_bar)
	var capacity_box := VBoxContainer.new()
	capacity_box.add_theme_constant_override("separation", 4)
	summary.add_child(capacity_box)
	var total := _training.capacity_for(instance)
	var used := _training.used_capacity(instance)
	var planned := _training.plan_cost(instance, _pending_stats, _pending_mobility)
	_capacity_label = _label("CAPACITY %d / %d   +%d planned" % [used + planned, total, planned], 11, UI.GOLD, true)
	capacity_box.add_child(_capacity_label)
	_capacity_bar = _progress(UI.GOLD)
	_capacity_bar.max_value = maxf(1, total)
	_capacity_bar.value = used + planned
	capacity_box.add_child(_capacity_bar)

func _build_mobility(instance: DigimonInstance, current_stats: Dictionary, preview_stats: Dictionary) -> void:
	_detail.add_child(_section_label("TACTICAL MOBILITY", UI.GOLD))
	_mobility_box = VBoxContainer.new()
	_mobility_box.add_theme_constant_override("separation", 7)
	_detail.add_child(_mobility_box)
	var current_level := _training.mobility_level(instance)
	var target_level := current_level + _pending_mobility
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	_mobility_box.add_child(line)
	var icon := TextureRect.new()
	icon.texture = MOVE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	icon.modulate = UI.GOLD
	line.add_child(icon)
	var copy := _label("MOV %d" % int(current_stats.get("mov", 0)), 15, UI.TEXT, true)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(preview_stats.get("mov", 0)) != int(current_stats.get("mov", 0)):
		copy.text += "   PREVIEW %d" % int(preview_stats.get("mov", 0))
		copy.add_theme_color_override("font_color", UI.GREEN)
	line.add_child(copy)
	line.add_child(_label("MOBILITY %d / 2" % target_level, 10, UI.MUTED, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_mobility_box.add_child(actions)
	var undo := _button("UNDO PLANNED MOV", UI.MUTED)
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.disabled = _pending_mobility <= 0
	undo.pressed.connect(_remove_mobility)
	actions.add_child(undo)
	var add := _button("TRAIN MOV +1", UI.GOLD)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var test_steps := _pending_mobility + 1
	add.disabled = not _training.can_apply_plan(instance, _pending_stats, test_steps)
	add.pressed.connect(_add_mobility)
	actions.add_child(add)
	if target_level < 2:
		var next_level := target_level + 1
		_mobility_box.add_child(_label("Next MOV training: Potential %d, Capacity cost %d." % [_training.mobility_potential_for_level(next_level), _training.mobility_cost_for_level(next_level)], 10, UI.MUTED))
	else:
		_mobility_box.add_child(_label("Maximum permanent mobility training reached.", 10, UI.GREEN, true))

func _build_actions(instance: DigimonInstance) -> void:
	_detail.add_child(_section_label("TRAINING PLAN", UI.GREEN))
	var validation := _training.validate_plan(instance, _pending_stats, _pending_mobility)
	var has_plan := _has_plan()
	var message := "Ready to apply this plan." if has_plan and validation.is_empty() else (validation if has_plan else "No pending changes.")
	_detail.add_child(_label(message, 10, UI.GREEN if has_plan and validation.is_empty() else UI.MUTED, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_detail.add_child(actions)
	_discard_button = _icon_text_button(UNDO_ICON, "DISCARD PLAN", UI.MUTED)
	_discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_button.disabled = not has_plan
	_discard_button.pressed.connect(_discard_plan)
	actions.add_child(_discard_button)
	_apply_button = _icon_text_button(CONFIRM_ICON, "APPLY TRAINING", UI.GREEN)
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.disabled = not has_plan or not validation.is_empty()
	_apply_button.pressed.connect(_apply_plan)
	actions.add_child(_apply_button)

func _select_instance(instance_id: String) -> void:
	_selected_id = instance_id
	_clear_plan()
	_status.text = "Training plan cleared for the new selection."
	_refresh()

func _add_stat(stat_key: String) -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var test_plan := _pending_stats.duplicate(true)
	test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
	if not _training.can_apply_plan(instance, test_plan, _pending_mobility):
		_status.text = _training.validate_plan(instance, test_plan, _pending_mobility)
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
	if not _training.can_apply_plan(instance, _pending_stats, test_steps):
		_status.text = _training.validate_plan(instance, _pending_stats, test_steps)
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
	if not _training.apply_plan(instance, _pending_stats, _pending_mobility):
		_status.text = "Training could not be applied."
		return
	OverworldState.notify_roster_changed()
	_clear_plan()
	_status.text = "Training applied and saved."
	_refresh()
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate", Color(1.18, 1.18, 1.18, 1.0), 0.08)
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
		_refresh()

func _animate_open() -> void:
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_frame, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _layout() -> void:
	if _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 900.0)
	var edge := 10.0 if compact else 20.0
	var width := minf(1180.0, physical.x - edge * 2.0)
	var height := minf(690.0, physical.y - edge * 2.0)
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_body.columns = 1 if compact else 2
	_collection_panel.custom_minimum_size = Vector2(0, 170 if compact else 0)
	_detail_panel.custom_minimum_size = Vector2(0, 370 if compact else 0)

func _progress(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.015, 0.025, 0.9)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	UI.apply_label(label, size, color, bold)
	return label

func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent, true)
	label.add_theme_constant_override("outline_size", 1)
	return label

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	UI.apply_button(button, accent)
	button.focus_mode = Control.FOCUS_ALL
	return button

func _icon_button(texture: Texture2D, accent: Color, tooltip: String) -> Button:
	var button := Button.new()
	button.icon = texture
	button.expand_icon = true
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	UI.apply_button(button, accent)
	return button

func _icon_text_button(texture: Texture2D, text: String, accent: Color) -> Button:
	var button := _button(text, accent)
	button.icon = texture
	button.expand_icon = true
	button.icon_max_width = 20
	return button

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
