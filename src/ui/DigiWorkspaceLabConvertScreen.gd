extends "res://src/ui/DigiLabConvertScreen.gd"
class_name DigiWorkspaceLabConvertScreen

const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const WorkspaceBackdrop = preload("res://src/ui/components/DigiLabWorkspaceBackdrop.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const SegmentScript = preload("res://src/ui/components/DigiSegmentedTabs.gd")

const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.25

var _roster_page := 0
var _roster_page_count := 1
var _record_page := 0
var _record_page_count := 1
var _last_record_query := ""
var _compact_detail_open := false
var _left_trigger_down := false
var _right_trigger_down := false

var _workspace_back_button: Button
var _roster_pager: DigiPager
var _record_pager: DigiPager
var _compact_mode_bar: HBoxContainer
var _compact_reconstruct_button: Button
var _compact_records_button: Button
var _mode_segments: DigiSegmentedTabs
var _compact_segments: DigiSegmentedTabs


func open_lab() -> void:
	_compact_detail_open = false
	_left_trigger_down = false
	_right_trigger_down = false
	super.open_lab()
	WorkspaceChrome.configure_header(_header)
	_header.set_active_tab("convert")
	_layout()


func _build() -> void:
	super._build()
	var backdrop := WorkspaceBackdrop.new() as DigiLabWorkspaceBackdrop
	backdrop.name = "DigiLabWorkspaceBackdrop"
	add_child(backdrop)
	WorkspaceChrome.install_background(self, backdrop, _frame)

	WorkspaceChrome.configure_header(_header)
	WorkspaceChrome.configure_hints(
		_hint_bar,
		"Reconstruct Digimon from Digi Data or teach permanent Technique Records.",
		"Reconstruction / Records",
		false
	)
	WorkspaceChrome.style_workspace_panel(_list_panel, V2.CYAN)
	WorkspaceChrome.style_workspace_panel(_detail_panel, V2.CYAN)
	_list_header.set_workspace_mode(true)
	_detail_header.set_workspace_mode(true)
	WorkspaceChrome.disable_scroll(_list_scroll)
	WorkspaceChrome.disable_scroll(_detail_scroll)

	var list_stack := _list_panel.get_child(0) as VBoxContainer
	var pager_margin := _margin(10, 2, 10, 8)
	_roster_pager = PagerScript.new() as DigiPager
	_roster_pager.name = "DigiDataPager"
	_roster_pager.set_workspace_mode(true)
	_roster_pager.page_delta_requested.connect(_turn_roster_page)
	pager_margin.add_child(_roster_pager)
	list_stack.add_child(pager_margin)

	var legacy_mode_margin := _mode_bar.get_parent() as CanvasItem
	if legacy_mode_margin != null:
		legacy_mode_margin.visible = false
	var detail_stack := _detail_panel.get_child(0) as VBoxContainer
	var segment_margin := _margin(12, 10, 12, 6)
	_mode_segments = SegmentScript.new() as DigiSegmentedTabs
	_mode_segments.configure([
		{"id": "reconstruction", "label": "RECONSTRUCTION", "accent": V2.CYAN},
		{"id": "records", "label": "TECHNIQUE RECORDS", "accent": V2.AMBER},
	], _lab_mode)
	_mode_segments.tab_selected.connect(_set_lab_mode)
	segment_margin.add_child(_mode_segments)
	detail_stack.add_child(segment_margin)
	detail_stack.move_child(segment_margin, 1)

	_workspace_back_button = _workspace_button("‹  ARCHIVE", V2.CYAN)
	_workspace_back_button.name = "BackToDigiData"
	_workspace_back_button.custom_minimum_size = Vector2(156.0, 44.0)
	_workspace_back_button.visible = false
	_workspace_back_button.pressed.connect(_return_to_roster)
	_root.add_child(_workspace_back_button)

	_compact_mode_bar = HBoxContainer.new()
	_compact_mode_bar.name = "CompactLabModes"
	_compact_mode_bar.visible = false
	_root.add_child(_compact_mode_bar)
	_compact_segments = SegmentScript.new() as DigiSegmentedTabs
	_compact_segments.configure([
		{"id": "reconstruction", "label": "RECONSTRUCTION", "accent": V2.CYAN},
		{"id": "records", "label": "TECHNIQUE RECORDS", "accent": V2.AMBER},
	], _lab_mode)
	_compact_segments.tab_selected.connect(_set_lab_mode)
	_compact_mode_bar.add_child(_compact_segments)

	for button in [_reconstruct_mode_button, _records_mode_button]:
		button.custom_minimum_size = Vector2(150.0, 52.0)
		button.focus_mode = Control.FOCUS_NONE
	_record_search.custom_minimum_size = Vector2(180.0, 52.0)
	_style_mode_tabs()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB:
			if _header.select_adjacent_tab(1):
				get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_X and not (get_viewport().gui_get_focus_owner() is LineEdit):
			_toggle_lab_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		var joy := event as InputEventJoypadButton
		if joy.button_index == JOY_BUTTON_X:
			_toggle_lab_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT:
			_handle_page_trigger(motion.axis_value, -1, true)
		elif motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			_handle_page_trigger(motion.axis_value, 1, false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _compact_detail_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		_return_to_roster()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _toggle_lab_mode() -> void:
	_set_lab_mode("records" if _lab_mode == "reconstruction" else "reconstruction")


func _set_lab_mode(mode: String) -> void:
	if mode == _lab_mode:
		return
	_roster_page = 0
	_record_page = 0
	_compact_detail_open = false
	super._set_lab_mode(mode)
	_style_mode_tabs()
	_layout()


func _style_mode_tabs() -> void:
	super._style_mode_tabs()
	if _mode_segments != null:
		_mode_segments.set_active(_lab_mode)
	if _compact_segments != null:
		_compact_segments.set_active(_lab_mode)


func _refresh_list() -> void:
	if _lab_mode == "records":
		super._refresh_list()
		return

	_clear_children_now(_list_box)
	_data_buttons.clear()
	var entries := _reconstruction_entries()
	_list_header.set_trailing("%d KNOWN" % entries.size())

	if entries.is_empty():
		_empty_label = _empty_state("No known Digimon yet.\nDefeat Digimon in battle to discover reconstruction data.")
		_empty_label.custom_minimum_size.y = 160
		_list_box.add_child(_empty_label)
		_selected_name = ""
		_roster_page = 0
		_roster_page_count = 1
		_roster_pager.configure(0, 1)
		_sync_pagination_hint()
		return

	var selected_index := -1
	for index in range(entries.size()):
		if String(entries[index].get("name", "")).to_lower() == _selected_name.to_lower():
			selected_index = index
			break
	if selected_index < 0:
		selected_index = 0
		_selected_name = String(entries[0].get("name", ""))

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	_roster_page_count = maxi(1, ceili(float(entries.size()) / float(capacity)))
	_roster_page = clampi(selected_index / capacity, 0, _roster_page_count - 1)
	var start := _roster_page * capacity
	var finish := mini(entries.size(), start + capacity)
	for index in range(start, finish):
		var entry: Dictionary = entries[index]
		var species_name := String(entry.get("name", ""))
		var button := _data_button(species_name, int(entry.get("amount", 0)))
		_list_box.add_child(button)
		_data_buttons.append(button)
	_style_selection()
	_roster_pager.configure(_roster_page, _roster_page_count)
	_sync_pagination_hint()


func _refresh_record_roster() -> void:
	var instances: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_list_header.set_trailing("%d OWNED" % instances.size())
	if instances.is_empty():
		_list_box.add_child(_empty_state("No owned Digimon."))
		_selected_name = ""
		_roster_page = 0
		_roster_page_count = 1
		_roster_pager.configure(0, 1)
		_sync_pagination_hint()
		return

	var selected_index := -1
	for index in range(instances.size()):
		if instances[index].id == _selected_name:
			selected_index = index
			break
	if selected_index < 0:
		selected_index = 0
		_selected_name = instances[0].id

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	_roster_page_count = maxi(1, ceili(float(instances.size()) / float(capacity)))
	_roster_page = clampi(selected_index / capacity, 0, _roster_page_count - 1)
	var start := _roster_page * capacity
	var finish := mini(instances.size(), start + capacity)
	for index in range(start, finish):
		var instance := instances[index]
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", "Digimon")))
		var rank := String(species.get("rank", "Unknown"))
		var button := Button.new()
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0, 94)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_contents = true
		button.set_meta("instance_id", instance.id)
		button.pressed.connect(_select_record_instance.bind(instance.id))
		button.pressed.connect(_activate_record_instance.bind(instance.id))
		button.focus_entered.connect(_select_record_instance.bind(instance.id))
		_style_roster_button(button, instance.id == _selected_name, V2.rank_color(rank))
		var margin := _margin(10, 7, 10, 7)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(row)
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.custom_minimum_size = Vector2(64, 64)
		preview.set_species(String(species.get("name", "")))
		preview.set_active(instance.id == _selected_name)
		row.add_child(preview)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 3)
		row.add_child(copy)
		copy.add_child(_single_line_label(name, 16, V2.TEXT, true))
		copy.add_child(_single_line_label("Lv %d  ·  %s" % [instance.level, rank], 11, V2.rank_color(rank), true))
		copy.add_child(_single_line_label("%d BITS available" % OverworldState.get_bits(), 10, V2.MUTED))
		_list_box.add_child(button)
		_data_buttons.append(button)
	_style_selection()
	_roster_pager.configure(_roster_page, _roster_page_count)
	_sync_pagination_hint()


func _data_button(species_name: String, amount: int) -> Button:
	var button := super._data_button(species_name, amount)
	button.custom_minimum_size.y = 94.0
	button.pressed.connect(_activate_species.bind(species_name))
	return button


func _activate_species(species_name: String) -> void:
	_select_species(species_name)
	if WorkspaceChrome.is_compact(get_viewport()):
		_compact_detail_open = true
		_layout()
		call_deferred("_focus_first_detail_control")


func _activate_record_instance(instance_id: String) -> void:
	_select_record_instance(instance_id)
	if WorkspaceChrome.is_compact(get_viewport()):
		_compact_detail_open = true
		_layout()
		call_deferred("_focus_first_detail_control")


func _return_to_roster() -> void:
	_compact_detail_open = false
	_layout()
	call_deferred("_focus_selected_data")


func _turn_roster_page(delta: int) -> void:
	if delta == 0 or _roster_page_count <= 1:
		return
	var next_page := clampi(_roster_page + delta, 0, _roster_page_count - 1)
	if next_page == _roster_page:
		return
	_roster_page = next_page
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	if _lab_mode == "records":
		var instances: Array[DigimonInstance] = OverworldState.get_collection_instances()
		var index := mini(_roster_page * capacity, instances.size() - 1)
		if index >= 0:
			_selected_name = instances[index].id
	else:
		var entries := _reconstruction_entries()
		var index := mini(_roster_page * capacity, entries.size() - 1)
		if index >= 0:
			_selected_name = String(entries[index].get("name", ""))
	_refresh()
	call_deferred("_focus_selected_data")


func _refresh_record_detail() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_name)
	if instance == null:
		_detail_body.add_child(_empty_state("Select an owned Digimon to use Technique Records."))
		_record_page_count = 1
		_sync_pagination_hint()
		return
	var species := _database.get_by_seed(instance.species_seed)
	var name := instance.get_display_name(String(species.get("name", "Digimon")))
	var rank := String(species.get("rank", "Unknown"))

	var hero := PanelContainer.new()
	hero.custom_minimum_size.y = 96.0
	hero.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.AMBER))
	_detail_body.add_child(hero)
	var hero_margin := _margin(14, 10, 14, 10)
	hero.add_child(hero_margin)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 14)
	hero_margin.add_child(hero_row)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(72, 72)
	preview.set_species(String(species.get("name", "")))
	preview.set_active(true)
	hero_row.add_child(preview)
	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_copy.add_theme_constant_override("separation", 4)
	hero_row.add_child(hero_copy)
	hero_copy.add_child(_single_line_label(name, 20, V2.WHITE, true))
	hero_copy.add_child(_single_line_label("Lv %d · %s · Permanent Technique Library" % [instance.level, rank], 11, V2.rank_color(rank), true))
	hero_copy.add_child(_single_line_label("%d BITS AVAILABLE" % OverworldState.get_bits(), 11, V2.AMBER, true))

	var query := _record_search.text.to_lower().strip_edges()
	if query != _last_record_query:
		_last_record_query = query
		_record_page = 0
	var actions: Array[Dictionary] = []
	for action: Dictionary in OverworldState.get_teachable_techniques(instance.id):
		var action_name := String(action.get("name", action.get("id", "Technique")))
		if not query.is_empty() and not action_name.to_lower().contains(query) and not String(action.get("id", "")).to_lower().contains(query):
			continue
		var unlocked := bool(action.get("unlocked", false))
		var research := int(action.get("research", 0))
		if unlocked or research > 0:
			actions.append(action)

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	_record_page_count = maxi(1, ceili(float(actions.size()) / float(capacity)))
	_record_page = clampi(_record_page, 0, _record_page_count - 1)
	if actions.is_empty():
		_detail_body.add_child(_empty_state("No unlocked or researched Records match this search."))
	else:
		var start := _record_page * capacity
		var finish := mini(actions.size(), start + capacity)
		for index in range(start, finish):
			_detail_body.add_child(_record_row(instance, actions[index]))

	_record_pager = PagerScript.new() as DigiPager
	_record_pager.name = "TechniqueRecordPager"
	_record_pager.set_workspace_mode(true)
	_record_pager.configure(_record_page, _record_page_count)
	_record_pager.page_delta_requested.connect(_turn_record_page)
	_detail_body.add_child(_record_pager)
	_sync_pagination_hint()


func _record_row(instance: DigimonInstance, action: Dictionary) -> Control:
	var action_name := String(action.get("name", action.get("id", "Technique")))
	var unlocked := bool(action.get("unlocked", false))
	var research := int(action.get("research", 0))
	var record = action.get("record", {})
	var cost := int(record.get("bitsCost", 0)) if record is Dictionary else 0
	var compatible := bool(action.get("compatible", false))
	var learned := bool(action.get("learned", false))
	var affordable := OverworldState.get_bits() >= cost
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 78.0
	panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.AMBER if unlocked else V2.CYAN))
	var margin := _margin(12, 7, 12, 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	info.add_child(_single_line_label(action_name, 14, V2.WHITE, true))
	info.add_child(_single_line_label(
		"%s · %s · Research %d/3" % [
			String(action.get("element", "neutral")).capitalize(),
			String(record.get("recordLevel", "common")).capitalize() if record is Dictionary else "Common",
			research,
		],
		10,
		V2.MUTED
	))
	var status := "LEARNED" if learned else ("LOCKED" if not unlocked else ("INCOMPATIBLE" if not compatible else ("NEED %d BITS" % maxi(0, cost - OverworldState.get_bits()) if not affordable else "READY")))
	var teach := CommandButtonScript.new() as DigiCommandButton
	teach.custom_minimum_size.x = 210.0
	teach.configure("LEARN · %d BITS" % cost, "Teach permanently to this individual", status, "book", V2.AMBER)
	teach.set_compact(true)
	teach.set_interactive(unlocked and compatible and not learned and affordable)
	teach.pressed.connect(_teach_record.bind(instance.id, String(action.get("id", ""))))
	row.add_child(teach)
	return panel


func _turn_record_page(delta: int) -> void:
	if delta == 0 or _record_page_count <= 1:
		return
	var next_page := clampi(_record_page + delta, 0, _record_page_count - 1)
	if next_page == _record_page:
		return
	_record_page = next_page
	_refresh_detail()
	_layout()
	call_deferred("_focus_first_detail_control")


func _handle_page_trigger(value: float, delta: int, left_trigger: bool) -> void:
	var was_down := _left_trigger_down if left_trigger else _right_trigger_down
	if not was_down and value >= TRIGGER_PRESS_THRESHOLD:
		if left_trigger:
			_left_trigger_down = true
		else:
			_right_trigger_down = true
		if _compact_detail_open and _lab_mode == "records" and _record_page_count > 1:
			_turn_record_page(delta)
		else:
			_turn_roster_page(delta)
		get_viewport().set_input_as_handled()
	elif was_down and value <= TRIGGER_RELEASE_THRESHOLD:
		if left_trigger:
			_left_trigger_down = false
		else:
			_right_trigger_down = false


func _reconstruction_entries() -> Array[Dictionary]:
	var known_names: Dictionary = {}
	for raw_name in OverworldState.get_digi_data().keys():
		var name := String(raw_name).strip_edges()
		if not name.is_empty():
			known_names[name.to_lower()] = name
	for instance: DigimonInstance in OverworldState.get_collection_instances():
		var seeds: Array[String] = instance.species_history.duplicate()
		if seeds.is_empty() and not instance.species_seed.is_empty():
			seeds.append(instance.species_seed)
		for seed: String in seeds:
			var species := _database.get_by_seed(seed)
			if species.is_empty():
				continue
			var species_name := String(species.get("name", "")).strip_edges()
			if not species_name.is_empty():
				known_names[species_name.to_lower()] = species_name

	var entries: Array[Dictionary] = []
	for raw_key in known_names.keys():
		var species_name := String(known_names[raw_key])
		var amount := OverworldState.get_digi_data_for(species_name)
		var required := OverworldState.get_reconstruction_requirement(species_name)
		var state := "ready" if amount >= required else "collecting" if amount > 0 else "locked"
		entries.append({"name": species_name, "amount": amount, "required": required, "state": state})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority := {"ready": 0, "collecting": 1, "locked": 2}
		var priority_a := int(priority.get(String(a.get("state", "locked")), 3))
		var priority_b := int(priority.get(String(b.get("state", "locked")), 3))
		if priority_a != priority_b:
			return priority_a < priority_b
		var amount_a := int(a.get("amount", 0))
		var amount_b := int(b.get("amount", 0))
		if amount_a != amount_b:
			return amount_a > amount_b
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	return entries


func _sync_pagination_hint() -> void:
	if _hint_bar != null:
		_hint_bar.set_pagination_enabled(_roster_page_count > 1 or (_lab_mode == "records" and _record_page_count > 1))


func _focus_first_detail_control() -> void:
	if not visible or not _detail_panel.visible:
		return
	var controls := _focusable_descendants(_detail_body)
	if not controls.is_empty():
		controls[0].grab_focus()
	elif _workspace_back_button.visible:
		_workspace_back_button.grab_focus()


func _wire_focus_navigation() -> void:
	if _data_buttons.is_empty():
		return
	if WorkspaceChrome.is_compact(get_viewport()):
		if _compact_detail_open:
			var controls := _focusable_descendants(_detail_body)
			if not controls.is_empty():
				_workspace_back_button.focus_neighbor_bottom = _workspace_back_button.get_path_to(controls[0])
				controls[0].focus_neighbor_top = controls[0].get_path_to(_workspace_back_button)
		return
	var selected := _data_buttons[0]
	for button: Button in _data_buttons:
		if (_lab_mode == "records" and String(button.get_meta("instance_id", "")) == _selected_name) or (_lab_mode != "records" and String(button.get_meta("species_name", "")).to_lower() == _selected_name.to_lower()):
			selected = button
			break
	var detail_controls := _focusable_descendants(_detail_body)
	if not detail_controls.is_empty():
		var first_detail := detail_controls[0]
		for button: Button in _data_buttons:
			button.focus_neighbor_right = button.get_path_to(first_detail)
		first_detail.focus_neighbor_left = first_detail.get_path_to(selected)


func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var width := maxf(640.0, physical.x)
	var height := maxf(420.0, physical.y)
	var compact := WorkspaceChrome.is_compact(get_viewport())

	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(width, height)
	_root.position = Vector2.ZERO
	_root.size = Vector2(width, height)

	var header_h := WorkspaceChrome.header_height(compact)
	var footer_h := WorkspaceChrome.FOOTER_HEIGHT
	var edge := WorkspaceChrome.edge_for(compact)
	var top_gap := WorkspaceChrome.top_gap(compact)
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_header_rule.position = Vector2(0.0, header_h - 1.0)
	_header_rule.size = Vector2(width, 1.0)
	_hint_bar.position = Vector2(0.0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)

	var body_top := header_h + top_gap
	var body_bottom := height - footer_h - WorkspaceChrome.BOTTOM_GAP
	var body_h := maxf(220.0, body_bottom - body_top)

	_compact_mode_bar.visible = compact and not _compact_detail_open
	if _compact_mode_bar.visible:
		_compact_mode_bar.position = Vector2(edge, body_top)
		_compact_mode_bar.size = Vector2(width - edge * 2.0, 52.0)
		_compact_segments.size = _compact_mode_bar.size
		body_top += 56.0
		body_h = maxf(160.0, body_bottom - body_top)

	_workspace_back_button.visible = compact and _compact_detail_open
	if compact:
		_list_panel.visible = not _compact_detail_open
		_detail_panel.visible = _compact_detail_open
		if _compact_detail_open:
			_workspace_back_button.position = Vector2(edge, body_top)
			_workspace_back_button.size = Vector2(156.0, 44.0)
			var detail_top := body_top + 52.0
			_detail_panel.position = Vector2(edge, detail_top)
			_detail_panel.size = Vector2(width - edge * 2.0, maxf(160.0, body_bottom - detail_top))
		else:
			_list_panel.position = Vector2(edge, body_top)
			_list_panel.size = Vector2(width - edge * 2.0, body_h)
	else:
		_list_panel.visible = true
		_detail_panel.visible = true
		_workspace_back_button.visible = false
		var usable := width - edge * 2.0 - WorkspaceChrome.GAP
		var list_w := clampf(usable * WorkspaceChrome.ROSTER_RATIO, WorkspaceChrome.ROSTER_MIN, WorkspaceChrome.ROSTER_MAX)
		_list_panel.position = Vector2(edge, body_top)
		_list_panel.size = Vector2(list_w, body_h)
		_detail_panel.position = Vector2(edge + list_w + WorkspaceChrome.GAP, body_top)
		_detail_panel.size = Vector2(maxf(360.0, width - edge * 2.0 - list_w - WorkspaceChrome.GAP), body_h)

	WorkspaceChrome.disable_scroll(_list_scroll)
	WorkspaceChrome.disable_scroll(_detail_scroll)
	_roster_pager.set_workspace_mode(true)
	_roster_pager.set_compact(compact)
	if _mode_segments != null:
		_mode_segments.set_compact(compact)
	if _compact_segments != null:
		_compact_segments.set_compact(true)
	if _record_pager != null:
		_record_pager.set_workspace_mode(true)
		_record_pager.set_compact(compact)

	_announcement.scale = Vector2.ONE * scale_factor
	_announcement.position = Vector2(width * 0.25, header_h + 6.0) * scale_factor
	_announcement.size = Vector2(width * 0.50, 42.0)


func _workspace_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", V2.WHITE)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.MUTED)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, V2.workspace_button_style(accent, state))
	V2.apply_heading(button)
	return button


func _workspace_segment_button(text: String) -> Button:
	var button := _workspace_button(text, V2.CYAN)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _style_workspace_segment(button: Button, active: bool, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", V2.workspace_button_style(accent, "focus" if active else "normal"))
	button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
