extends "res://src/ui/DigiIconPartyStorageScreen.gd"
class_name DigiWorkspacePartyStorageScreen

const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const WorkspaceBackdrop = preload("res://src/ui/components/DigiLabWorkspaceBackdrop.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")

const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.25

var _workspace_page := 0
var _workspace_page_count := 1
var _compact_detail_open := false
var _compact_detail_tab := "stats"
var _left_trigger_down := false
var _right_trigger_down := false

var _workspace_pager: DigiPager
var _workspace_back_button: Button
var _compact_detail_tabs: HBoxContainer
var _stats_tab_button: Button
var _actions_tab_button: Button


func open_screen() -> void:
	_compact_detail_open = false
	_compact_detail_tab = "stats"
	_left_trigger_down = false
	_right_trigger_down = false
	super.open_screen()
	WorkspaceChrome.configure_header(_header)
	_header.set_active_tab("party")
	_layout()


func _build() -> void:
	super._build()
	var backdrop := WorkspaceBackdrop.new() as DigiLabWorkspaceBackdrop
	backdrop.name = "DigiLabWorkspaceBackdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
	_backdrop.color = Color(V2.BACKDROP.r, V2.BACKDROP.g, V2.BACKDROP.b, 0.72)

	WorkspaceChrome.configure_header(_header)
	WorkspaceChrome.configure_hints(
		_hint_bar,
		"Organize the active Party, Storage and individual progression.",
		"",
		false
	)
	WorkspaceChrome.style_workspace_panel(_collection_panel, V2.CYAN)
	WorkspaceChrome.style_workspace_panel(_detail_panel, V2.CYAN)
	_collection_header.set_workspace_mode(true)
	_detail_header.set_workspace_mode(true)
	WorkspaceChrome.disable_scroll(_list_scroll)
	WorkspaceChrome.disable_scroll(_detail_scroll)

	var collection_stack := _collection_panel.get_child(0) as VBoxContainer
	_workspace_pager = PagerScript.new() as DigiPager
	_workspace_pager.name = "CollectionPager"
	_workspace_pager.set_workspace_mode(true)
	_workspace_pager.page_delta_requested.connect(_turn_workspace_page)
	collection_stack.add_child(_workspace_pager)

	_workspace_back_button = _workspace_button("‹  COLLECTION", V2.CYAN)
	_workspace_back_button.name = "BackToCollection"
	_workspace_back_button.custom_minimum_size = Vector2(168.0, 44.0)
	_workspace_back_button.visible = false
	_workspace_back_button.pressed.connect(_return_to_collection)
	_root.add_child(_workspace_back_button)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB:
			if _header.select_adjacent_tab(1):
				get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_X and _compact_detail_open:
			_toggle_compact_detail_tab()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		var joy := event as InputEventJoypadButton
		if joy.button_index == JOY_BUTTON_X and _compact_detail_open:
			_toggle_compact_detail_tab()
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
		_return_to_collection()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _refresh_list() -> void:
	_clear_children_now(_list)
	_list_buttons.clear()
	_list_ids.clear()
	_list_previews.clear()
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if collection.is_empty():
		_list.add_child(_empty_state("No Digimon available."))
		_selected_id = ""
		_workspace_page = 0
		_workspace_page_count = 1
		_workspace_pager.configure(0, 1)
		_hint_bar.set_pagination_enabled(false)
		return

	var selected_index := -1
	for index in range(collection.size()):
		if collection[index].id == _selected_id:
			selected_index = index
			break
	if selected_index < 0:
		selected_index = 0
		_selected_id = collection[0].id

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 4, 3, 2)
	_workspace_page_count = maxi(1, ceili(float(collection.size()) / float(capacity)))
	_workspace_page = clampi(selected_index / capacity, 0, _workspace_page_count - 1)
	var start := _workspace_page * capacity
	var finish := mini(collection.size(), start + capacity)
	for index in range(start, finish):
		var instance := collection[index]
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var active := active_ids.has(instance.id)
		var button := _collection_button(instance, species, active, active_ids)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(instance.id)
	_style_list_selection()
	_workspace_pager.configure(_workspace_page, _workspace_page_count)
	_hint_bar.set_pagination_enabled(_workspace_page_count > 1)


func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool, active_ids: Array[String]) -> Button:
	var button := super._collection_button(instance, species, active, active_ids)
	button.custom_minimum_size.y = 100.0
	button.pressed.connect(_open_compact_detail.bind(instance.id))
	return button


func _style_list_button(button: Button, selected: bool, _accent: Color) -> void:
	button.add_theme_stylebox_override("normal", V2.workspace_panel_style(V2.CYAN, selected))
	button.add_theme_stylebox_override("hover", V2.workspace_button_style(V2.CYAN, "hover"))
	button.add_theme_stylebox_override("focus", V2.workspace_button_style(V2.CYAN, "focus"))
	button.add_theme_stylebox_override("pressed", V2.workspace_button_style(V2.CYAN, "pressed"))
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)


func _open_compact_detail(instance_id: String) -> void:
	_select(instance_id)
	if WorkspaceChrome.is_compact(get_viewport()):
		_compact_detail_open = true
		_layout()
		call_deferred("_focus_first_detail_control")


func _return_to_collection() -> void:
	_compact_detail_open = false
	_layout()
	call_deferred("_focus_selected")


func _turn_workspace_page(delta: int) -> void:
	if delta == 0 or _workspace_page_count <= 1:
		return
	var next_page := clampi(_workspace_page + delta, 0, _workspace_page_count - 1)
	if next_page == _workspace_page:
		return
	_workspace_page = next_page
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 4, 3, 2)
	var index := mini(_workspace_page * capacity, collection.size() - 1)
	if index >= 0:
		_selected_id = collection[index].id
	_status_text = ""
	_refresh()
	call_deferred("_focus_selected")


func _handle_page_trigger(value: float, delta: int, left_trigger: bool) -> void:
	var was_down := _left_trigger_down if left_trigger else _right_trigger_down
	if not was_down and value >= TRIGGER_PRESS_THRESHOLD:
		if left_trigger:
			_left_trigger_down = true
		else:
			_right_trigger_down = true
		if not (WorkspaceChrome.is_compact(get_viewport()) and _compact_detail_open):
			_turn_workspace_page(delta)
		get_viewport().set_input_as_handled()
	elif was_down and value <= TRIGGER_RELEASE_THRESHOLD:
		if left_trigger:
			_left_trigger_down = false
		else:
			_right_trigger_down = false


func _refresh_detail() -> void:
	_clear_children_now(_detail)
	var instance: DigimonInstance = OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_empty_state("Select a Digimon from your collection."))
		return
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_detail.add_child(_empty_state("Species data unavailable."))
		return

	var species_name := String(species.get("name", "Unknown"))
	var display_name := instance.get_display_name(species_name)
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var party_index := active_ids.find(instance.id)
	var active := party_index >= 0

	var identity := _identity_card(instance, species, display_name, rank, accent, active, party_index)
	identity.add_theme_stylebox_override("panel", V2.workspace_panel_style(accent))
	_detail.add_child(identity)

	var compact := WorkspaceChrome.is_compact(get_viewport())
	if compact:
		_compact_detail_tabs = HBoxContainer.new()
		_compact_detail_tabs.name = "PartyDetailTabs"
		_compact_detail_tabs.add_theme_constant_override("separation", 8)
		_detail.add_child(_compact_detail_tabs)
		_stats_tab_button = _detail_tab_button("STATS", _compact_detail_tab == "stats")
		_stats_tab_button.pressed.connect(_set_compact_detail_tab.bind("stats"))
		_compact_detail_tabs.add_child(_stats_tab_button)
		_actions_tab_button = _detail_tab_button("PARTY ACTIONS", _compact_detail_tab == "actions")
		_actions_tab_button.pressed.connect(_set_compact_detail_tab.bind("actions"))
		_compact_detail_tabs.add_child(_actions_tab_button)
		if _compact_detail_tab == "stats":
			var stats := StatsPanelScript.new()
			stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stats.set_workspace_mode(true, true)
			stats.configure(_progression.get_final_stats(instance), instance.current_hp, instance.current_mp)
			_detail.add_child(stats)
		else:
			_detail.add_child(_party_actions_panel(instance, active_ids, party_index, active))
	else:
		var lower_grid := GridContainer.new()
		lower_grid.columns = 2
		lower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lower_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lower_grid.add_theme_constant_override("h_separation", WorkspaceChrome.GAP)
		lower_grid.add_theme_constant_override("v_separation", WorkspaceChrome.GAP)
		_detail.add_child(lower_grid)
		var stats := StatsPanelScript.new()
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats.set_workspace_mode(true, false)
		stats.configure(_progression.get_final_stats(instance), instance.current_hp, instance.current_mp)
		lower_grid.add_child(stats)
		lower_grid.add_child(_party_actions_panel(instance, active_ids, party_index, active))


func _party_actions_panel(instance: DigimonInstance, active_ids: Array[String], party_index: int, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.AMBER))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("PARTY ACTIONS", _status_text, V2.AMBER, "party")
	header.set_workspace_mode(true)
	stack.add_child(header)
	var inset := _margin(12, 10, 12, 12)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(inset)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	inset.add_child(actions)

	var ascension := _workspace_button("ASCENSION / EXPANSION", V2.PURPLE)
	ascension.custom_minimum_size.y = 52
	ascension.tooltip_text = "Raise Tier, assimilate duplicate techniques and configure tactical size."
	ascension.pressed.connect(func(): ascension_requested.emit())
	actions.add_child(ascension)

	if active:
		var remove := _workspace_button("MOVE TO STORAGE", V2.ORANGE)
		remove.custom_minimum_size.y = 52
		remove.disabled = active_ids.size() <= 1
		remove.tooltip_text = "At least one Digimon must remain active." if remove.disabled else "Move this Digimon to Storage."
		remove.pressed.connect(_remove_from_party.bind(instance.id))
		actions.add_child(remove)
		var order := HBoxContainer.new()
		order.add_theme_constant_override("separation", 8)
		actions.add_child(order)
		var up := _workspace_button("MOVE UP", V2.CYAN)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.custom_minimum_size.y = 52
		up.disabled = party_index <= 0
		up.pressed.connect(_move.bind(instance.id, party_index - 1))
		order.add_child(up)
		var down := _workspace_button("MOVE DOWN", V2.CYAN)
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		down.custom_minimum_size.y = 52
		down.disabled = party_index >= active_ids.size() - 1
		down.pressed.connect(_move.bind(instance.id, party_index + 1))
		order.add_child(down)
	else:
		var add := _workspace_button("ADD TO PARTY", V2.GREEN)
		add.custom_minimum_size.y = 52
		add.disabled = active_ids.size() >= OverworldState.get_max_active_party_size()
		add.tooltip_text = "Party is full. Choose a slot to replace." if add.disabled else "Add this Digimon to the active party."
		add.pressed.connect(_add_to_party.bind(instance.id))
		actions.add_child(add)
		if add.disabled:
			var warning := _single_line_label("PARTY FULL · CHOOSE A SLOT TO REPLACE", 10, V2.AMBER, true)
			warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			actions.add_child(warning)
			var replacements := GridContainer.new()
			replacements.columns = 2
			replacements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			replacements.add_theme_constant_override("h_separation", 8)
			replacements.add_theme_constant_override("v_separation", 8)
			actions.add_child(replacements)
			for active_id: String in active_ids:
				var active_instance: DigimonInstance = OverworldState.get_instance_by_id(active_id)
				if active_instance == null:
					continue
				var active_species := _database.get_by_seed(active_instance.species_seed)
				var active_name := active_instance.get_display_name(String(active_species.get("name", "Digimon")))
				var slot := active_ids.find(active_id) + 1
				var swap := _workspace_button("SLOT %d · %s" % [slot, active_name.to_upper()], V2.PURPLE)
				swap.custom_minimum_size.y = 52
				swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				swap.pressed.connect(_swap.bind(active_id, instance.id))
				replacements.add_child(swap)
	return panel


func _set_compact_detail_tab(tab_id: String) -> void:
	if tab_id == _compact_detail_tab or not ["stats", "actions"].has(tab_id):
		return
	_compact_detail_tab = tab_id
	_refresh_detail()
	_layout()
	call_deferred("_focus_first_detail_control")


func _toggle_compact_detail_tab() -> void:
	_set_compact_detail_tab("actions" if _compact_detail_tab == "stats" else "stats")


func _detail_tab_button(text: String, active: bool) -> Button:
	var button := _workspace_button(text, V2.CYAN)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", V2.workspace_button_style(V2.CYAN, "focus" if active else "normal"))
	button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
	return button


func _focus_first_detail_control() -> void:
	if not visible or not _detail_panel.visible:
		return
	var controls := _focusable_descendants(_detail)
	if not controls.is_empty():
		controls[0].grab_focus()
	elif _workspace_back_button.visible:
		_workspace_back_button.grab_focus()


func _wire_focus_navigation() -> void:
	if _list_buttons.is_empty():
		return
	if WorkspaceChrome.is_compact(get_viewport()):
		if _compact_detail_open:
			var controls := _focusable_descendants(_detail)
			if not controls.is_empty():
				_workspace_back_button.focus_neighbor_bottom = _workspace_back_button.get_path_to(controls[0])
				controls[0].focus_neighbor_top = controls[0].get_path_to(_workspace_back_button)
		return
	var selected := _list_buttons[0]
	for index in range(_list_ids.size()):
		if _list_ids[index] == _selected_id and index < _list_buttons.size():
			selected = _list_buttons[index]
			break
	var detail_controls := _focusable_descendants(_detail)
	if not detail_controls.is_empty():
		var first_detail := detail_controls[0]
		for button: Button in _list_buttons:
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
	var top := header_h + WorkspaceChrome.top_gap(compact)
	var bottom := height - footer_h - WorkspaceChrome.BOTTOM_GAP
	var body_h := maxf(220.0, bottom - top)
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_header_rule.position = Vector2(0.0, header_h - 1.0)
	_header_rule.size = Vector2(width, 1.0)
	_hint_bar.position = Vector2(0.0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)

	_workspace_back_button.visible = compact and _compact_detail_open
	if compact:
		_collection_panel.visible = not _compact_detail_open
		_detail_panel.visible = _compact_detail_open
		if _compact_detail_open:
			_workspace_back_button.position = Vector2(edge, top)
			_workspace_back_button.size = Vector2(168.0, 44.0)
			var detail_top := top + 52.0
			_detail_panel.position = Vector2(edge, detail_top)
			_detail_panel.size = Vector2(width - edge * 2.0, maxf(160.0, bottom - detail_top))
		else:
			_collection_panel.position = Vector2(edge, top)
			_collection_panel.size = Vector2(width - edge * 2.0, body_h)
	else:
		_collection_panel.visible = true
		_detail_panel.visible = true
		_workspace_back_button.visible = false
		var usable := width - edge * 2.0 - WorkspaceChrome.GAP
		var collection_w := clampf(usable * WorkspaceChrome.ROSTER_RATIO, WorkspaceChrome.ROSTER_MIN, WorkspaceChrome.ROSTER_MAX)
		_collection_panel.position = Vector2(edge, top)
		_collection_panel.size = Vector2(collection_w, body_h)
		_detail_panel.position = Vector2(edge + collection_w + WorkspaceChrome.GAP, top)
		_detail_panel.size = Vector2(maxf(360.0, width - edge * 2.0 - collection_w - WorkspaceChrome.GAP), body_h)

	WorkspaceChrome.disable_scroll(_list_scroll)
	WorkspaceChrome.disable_scroll(_detail_scroll)
	_workspace_pager.set_workspace_mode(true)
	_workspace_pager.set_compact(compact)
	_hint_bar.set_secondary_tabs_enabled(compact and _compact_detail_open)
	_hint_bar.set_secondary_tabs_label("Stats / Party Actions")
	_hint_bar.set_scroll_hint_enabled(false)
	_hint_bar.set_hide_hints_on_touch(true)


func _workspace_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", V2.WHITE)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.MUTED)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, V2.workspace_button_style(accent, state))
	V2.apply_heading(button)
	return button
