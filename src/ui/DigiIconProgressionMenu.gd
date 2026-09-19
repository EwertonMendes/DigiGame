extends "res://src/ui/DigimonProgressionMenu.gd"
class_name DigiIconProgressionMenu

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const CommandButtonScript = preload("res://src/ui/components/DigiCommandButton.gd")
const ProfilePanelScript = preload("res://src/ui/components/DigiRosterProfilePanel.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")
const MENU_BACKGROUND = preload("res://assets/ui/backgrounds/digimon_menu.png")

const ROSTER_PAGE_SIZE := 3
const TECHNIQUE_PAGE_SIZE := 4
const TECHNIQUE_PAGE_SIZE_COMPACT := 3
const COMPACT_WIDTH := 1100.0
const COMPACT_HEIGHT := 680.0

enum MenuMode {
	ROSTER,
	ACTIONS,
	TECHNIQUES,
}

var _mode := MenuMode.ROSTER
var _roster_page := 0
var _visible_party_indices: Array[int] = []
var _roster_pager: DigiPager
var _pointer_card_press := false
var _overview_tab := "stats"
var _overview_tab_buttons: Dictionary = {}
var _overview_content: VBoxContainer
var _profile_panel: DigiRosterProfilePanel
var _stats_panel: DigiStatsPanel
var _command_buttons: Array[Button] = []
var _technique_page := 0
var _technique_pager: DigiPager
var _technique_focus_rows: Array[Array] = []
var _technique_page_size := TECHNIQUE_PAGE_SIZE
var _density_compact := false
var _analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate
var _right_analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate
var _main_tab := "party"
var _soon_label: Label
var _squad_swap_source_id := ""
var _squad_swap_source_name := ""
var _squad_role_mutation_in_progress := false


func open_menu() -> void:
	if _constellation != null:
		_constellation.visible = false
	visible = true
	_mode = MenuMode.ROSTER
	_main_tab = "party"
	_squad_swap_source_id = ""
	_squad_swap_source_name = ""
	_header.set_active_tab(_main_tab)
	_analog_gate.reset()
	_right_analog_gate.reset()
	_refresh_collection()
	call_deferred("_focus_selected_roster_card")
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = V2.BACKDROP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "DigimonMainMenuV2"
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	add_child(_panel)
	var background := TextureRect.new()
	background.name = "DigimonMenuBackground"
	background.texture = MENU_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(background)
	var shade := ColorRect.new()
	shade.name = "BackgroundShade"
	shade.color = Color(0.005, 0.019, 0.032, 0.36)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(shade)

	_menu_root = Control.new()
	_menu_root.name = "DigimonMainContent"
	_menu_root.clip_contents = true
	_panel.add_child(_menu_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "DigimonHeader"
	_header.configure("DIGIMON", "Party & Progression", OverworldState.get_bits(), true)
	_header.configure_tabs([
		{"id": "party", "label": "Party", "icon": "party", "angled": true},
		{"id": "digipedia", "label": "Digipedia", "icon": "book", "angled": true},
		{"id": "system", "label": "System", "icon": "gear", "angled": true},
	], _main_tab)
	_header.tab_selected.connect(_set_main_tab)
	_header.close_requested.connect(func(): close_requested.emit())
	_menu_root.add_child(_header)
	var close := _header.get_close_button()
	if close != null:
		close.focus_mode = Control.FOCUS_NONE
	for tab_id in ["party", "digipedia", "system"]:
		var main_tab_button := _header.get_tab_button(tab_id)
		if main_tab_button != null:
			main_tab_button.focus_mode = Control.FOCUS_NONE

	_header_rule = ColorRect.new()
	_header_rule.color = Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.62)
	_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(_header_rule)

	_collection_panel = PanelContainer.new()
	_collection_panel.name = "PartyRosterPanel"
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.78), 9))
	_menu_root.add_child(_collection_panel)

	var roster_stack := VBoxContainer.new()
	roster_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_stack.add_theme_constant_override("separation", 0)
	_collection_panel.add_child(roster_stack)

	var roster_inset := _margin(10, 8, 10, 4)
	roster_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_stack.add_child(roster_inset)

	_collection_scroll = ScrollContainer.new()
	_collection_scroll.name = "RosterViewport"
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.follow_focus = false
	_collection_scroll.clip_contents = true
	_collection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_inset.add_child(_collection_scroll)

	_collection_grid = GridContainer.new()
	_collection_grid.name = "RosterCards"
	_collection_grid.columns = 1
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_grid.add_theme_constant_override("v_separation", 8)
	_collection_scroll.add_child(_collection_grid)

	_roster_pager = PagerScript.new() as DigiPager
	_roster_pager.name = "RosterPager"
	_roster_pager.page_delta_requested.connect(_turn_roster_page)
	roster_stack.add_child(_roster_pager)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DigimonWorkspace"
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.58), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 9))
	_menu_root.add_child(_detail_panel)

	var detail_margin := _margin(10, 10, 10, 10)
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detail_margin)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailViewport"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = false
	_detail_scroll.clip_contents = true
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)

	_detail_list = VBoxContainer.new()
	_detail_list.name = "DetailContent"
	_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_list.add_theme_constant_override("separation", 0)
	_detail_scroll.add_child(_detail_list)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "InputHints"
	_hint_bar.set_description("Review your active Digimon, growth and techniques.")
	_hint_bar.set_scroll_hint_enabled(false)
	_hint_bar.set_hide_hints_on_touch(true)
	_hint_bar.set_primary_tabs_enabled(true)
	_menu_root.add_child(_hint_bar)
	_soon_label = _empty_message("Soon")
	_soon_label.name = "ComingSoon"
	_soon_label.add_theme_font_size_override("font_size", 34)
	_soon_label.add_theme_color_override("font_color", V2.WHITE)
	V2.apply_heading(_soon_label)
	_soon_label.visible = false
	_menu_root.add_child(_soon_label)

	_constellation = EvolutionChartScript.new() as EvolutionChart
	_constellation.name = "EvolutionChart"
	_constellation.visible = false
	_constellation.close_requested.connect(_close_constellation)
	_constellation.evolution_applied.connect(_on_evolution_state_changed)
	add_child(_constellation)


func _input(event: InputEvent) -> void:
	if not visible or (_constellation != null and _constellation.is_open()):
		return
	if _main_tab != "party":
		if event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_Y:
			var step := _analog_gate.vertical_step(motion.axis_value)
			if step != 0:
				_move_vertical(step)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_RIGHT_Y:
			var step := _right_analog_gate.vertical_step(motion.axis_value)
			if step != 0:
				_move_vertical(step)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_RIGHT_X:
			var step := _right_analog_gate.horizontal_step(motion.axis_value)
			if step != 0:
				_move_horizontal(step)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_LEFT_X:
			var step := _analog_gate.horizontal_step(motion.axis_value)
			if step != 0:
				_move_horizontal(step)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var page_step := _analog_gate.trigger_step(motion.axis, motion.axis_value)
			if page_step != 0:
				_turn_active_page(page_step)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_up"):
		_move_vertical(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_move_vertical(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_move_horizontal(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_move_horizontal(1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _constellation != null and _constellation.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_close_constellation()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var joy := event as InputEventJoypadButton
		if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_header.select_adjacent_tab(-1)
			get_viewport().set_input_as_handled()
			return
		if joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_header.select_adjacent_tab(1)
			get_viewport().set_input_as_handled()
			return
		if joy.button_index == JOY_BUTTON_X and _main_tab == "party":
			_switch_overview_tab(1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_header.select_adjacent_tab(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X and _main_tab == "party":
			_switch_overview_tab(1)
			get_viewport().set_input_as_handled()
			return
	if _main_tab != "party":
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_set_main_tab("party")
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("game_menu"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if not _squad_swap_source_id.is_empty():
			_cancel_squad_swap()
		elif _mode == MenuMode.TECHNIQUES:
			_leave_techniques()
		elif _mode == MenuMode.ACTIONS:
			_return_to_roster()
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()


func _on_active_party_changed(active_party: Array) -> void:
	# Squad-role actions below mutate through OverworldState, which emits the
	# shared party signal synchronously. The menu owns the resulting refresh and
	# must not rebuild itself re-entrantly in the middle of that transaction.
	if _squad_role_mutation_in_progress:
		return
	super._on_active_party_changed(active_party)


func _refresh_collection() -> void:
	if _collection_grid == null:
		return
	_clear_children(_collection_grid)
	_buttons.clear()
	_walk_previews.clear()
	_visible_party_indices.clear()

	var party := _party_instances()
	if party.is_empty():
		_selected_index = 0
		_roster_page = 0
		_collection_grid.add_child(_empty_message("No Digimon in your Squad."))
		_roster_pager.configure(0, 1)
		_refresh_details()
		_update_footer_hints()
		return

	_selected_index = clampi(_selected_index, 0, party.size() - 1)
	var page_count := _squad_roster_page_count()
	_roster_page = clampi(_roster_page, 0, page_count - 1)
	var selected_page := _squad_page_for_index(_selected_index)
	if selected_page != _roster_page and not _is_index_on_roster_page(_selected_index):
		_roster_page = selected_page

	var page_indices := _squad_indices_for_page(_roster_page)
	if page_indices.is_empty():
		_collection_grid.add_child(_empty_message(
			"No Active Digimon assigned." if _roster_page == 0 else "No Reserve Digimon assigned."
		))
	else:
		for global_index: int in page_indices:
			var instance: DigimonInstance = party[global_index]
			var species := _database.get_by_seed(instance.species_seed)
			var card := _collection_button(instance, species, global_index)
			_collection_grid.add_child(card)
			_visible_party_indices.append(global_index)

	_roster_pager.configure(_roster_page, page_count)
	_roster_pager.set_compact(_density_compact)
	_update_account()
	_refresh_details()
	_style_collection_selection()
	_update_footer_hints()


func _collection_button(instance: DigimonInstance, species: Dictionary, index: int) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := V2.rank_color(rank)
	var selected := index == _selected_index
	var button := Button.new()
	button.name = "PartyCard%02d" % index
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(0.0, _roster_card_height())
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("party_index", index)
	button.gui_input.connect(_on_roster_card_gui_input)
	button.pressed.connect(_confirm_index.bind(index))
	button.focus_entered.connect(_preview_index.bind(index))
	button.mouse_entered.connect(_hover_index.bind(index))
	_style_collection_button(button, selected, rank_color)

	var margin := _margin(10, 8, 10, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(58.0 if _density_compact else 66.0, 58.0 if _density_compact else 66.0)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	_walk_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name := _label(display_name, 15 if not _density_compact else 13, V2.TEXT, true)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 7)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(meta)
	var squad_role := OverworldState.get_squad_role(instance.id)
	var role_label := "ACTIVE" if squad_role == PlayerCollection.SQUAD_ROLE_ACTIVE else "RESERVE"
	var level_rank := _label("%s · Lv. %d · %s" % [role_label, instance.level, rank], 10, rank_color, true)
	level_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_rank.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_child(level_rank)
	var tier := TierIconScript.new() as DigiTierIcon
	tier.configure(instance.tier, Vector2(26.0, 18.0))
	meta.add_child(tier)

	var stats := _progression.get_final_stats(instance)
	var max_hp := maxi(1, int(stats.get("hp", 1)))
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(hp_row)
	var hp := _label("HP %d / %d" % [clampi(instance.current_hp, 0, max_hp), max_hp], 9, V2.MUTED, true)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp)

	var hp_bar := _mini_progress(V2.GREEN)
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(clampi(instance.current_hp, 0, max_hp))
	hp_bar.custom_minimum_size = Vector2(90.0, 6.0)
	copy.add_child(hp_bar)

	_buttons.append(button)
	return button


func _select_index(index: int) -> void:
	var party := _party_instances()
	if index < 0 or index >= party.size():
		return
	if _selected_index == index and _detail_list.get_child_count() > 0:
		_style_collection_selection()
		return
	_selected_index = index
	_style_collection_selection()
	_refresh_details()


func _preview_index(index: int) -> void:
	if _mode != MenuMode.ROSTER:
		return
	_select_index(index)


func _hover_index(index: int) -> void:
	if _mode == MenuMode.ROSTER:
		_select_index(index)


func _on_roster_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_pointer_card_press = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_pointer_card_press = true


func _confirm_index(index: int) -> void:
	var pointer := _pointer_card_press
	_pointer_card_press = false
	_select_index(index)
	if not _squad_swap_source_id.is_empty():
		_complete_squad_swap(index)
		return
	if _mode == MenuMode.TECHNIQUES:
		_technique_page = 0
		_refresh_details()
		if not pointer:
			call_deferred("_focus_first_technique_control")
		return
	_mode = MenuMode.ACTIONS
	_refresh_details()
	if not pointer:
		call_deferred("_focus_action", 0)


func _style_collection_selection() -> void:
	var party := _party_instances()
	for local_index in range(_buttons.size()):
		var global_index := _visible_party_indices[local_index] if local_index < _visible_party_indices.size() else -1
		var rank_color := V2.CYAN
		if global_index >= 0 and global_index < party.size():
			var species := _database.get_by_seed(party[global_index].species_seed)
			rank_color = V2.rank_color(String(species.get("rank", "Unknown")))
		var selected := global_index == _selected_index
		_style_collection_button(_buttons[local_index], selected, rank_color)
		if local_index < _walk_previews.size():
			_walk_previews[local_index].set_active(selected)


func _refresh_details() -> void:
	if _detail_list == null:
		return
	_clear_children(_detail_list)
	_command_buttons.clear()
	_action_cards.clear()
	_technique_focus_rows.clear()
	# These controls belong to the detail subtree that was just queued for
	# deletion. Clear every reference before any alternate detail mode (such as
	# the Squad swap picker) can return early without rebuilding Overview.
	_overview_tab_buttons.clear()
	_overview_content = null
	_profile_panel = null
	_stats_panel = null
	_development_panel = null
	_action_panel = null
	_technique_panel = null
	_body_grid = null
	_primary_column = null
	_sidebar_column = null

	var party := _party_instances()
	if party.is_empty():
		_detail_list.add_child(_empty_message("Add a Digimon to your Party to review its progression."))
		return
	_selected_index = clampi(_selected_index, 0, party.size() - 1)
	var instance: DigimonInstance = party[_selected_index]
	var species := _database.get_by_seed(instance.species_seed)

	if not _squad_swap_source_id.is_empty():
		_build_squad_swap_prompt(instance)
		_update_footer_hints()
		return

	if _mode == MenuMode.TECHNIQUES:
		_build_technique_view(instance)
		_update_footer_hints()
		return

	_body_grid = GridContainer.new()
	_body_grid.name = "ProfileWorkspace"
	_body_grid.columns = 2
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 10)
	_detail_list.add_child(_body_grid)

	_primary_column = VBoxContainer.new()
	_primary_column.name = "ProfileColumn"
	_primary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_primary_column.size_flags_stretch_ratio = 1.72
	_primary_column.custom_minimum_size.x = 300.0 if _density_compact else 500.0
	_primary_column.add_theme_constant_override("separation", 10)
	_body_grid.add_child(_primary_column)

	_sidebar_column = VBoxContainer.new()
	_sidebar_column.name = "OverviewColumn"
	_sidebar_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar_column.size_flags_stretch_ratio = 1.0
	_sidebar_column.custom_minimum_size.x = 205.0 if _density_compact else 280.0
	_sidebar_column.add_theme_constant_override("separation", 10)
	_body_grid.add_child(_sidebar_column)

	_profile_panel = ProfilePanelScript.new() as DigiRosterProfilePanel
	_profile_panel.configure(instance, species, _progression, _density_compact)
	_profile_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_primary_column.add_child(_profile_panel)

	_build_command_area(instance)
	_build_overview_column(instance)
	_update_action_state()
	call_deferred("_wire_focus_navigation")
	_update_footer_hints()


func _build_command_area(instance: DigimonInstance) -> void:
	_action_panel = PanelContainer.new()
	_action_panel.name = "CommandsPanel"
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_action_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))
	_primary_column.add_child(_action_panel)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_action_panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.name = "CommandsHeader"
	header.configure("COMMANDS", "", V2.CYAN, "evolution")
	stack.add_child(header)

	# Commands must stay fully inside the no-scroll workspace. Keep all three
	# actions on one compact row and reserve descriptions/status for tooltips.
	var inset := _margin(10, 7, 10, 9)
	stack.add_child(inset)
	var row := HBoxContainer.new()
	row.name = "CommandRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	inset.add_child(row)

	var techniques := CommandButtonScript.new() as DigiCommandButton
	techniques.name = "TechniquesCommand"
	techniques.configure(
		"TECHNIQUES",
		"Manage learned techniques and favorite shortcuts.",
		"",
		"techniques",
		V2.CYAN
	)
	techniques.set_minimal(true)
	techniques.set_compact(_density_compact)
	techniques.pressed.connect(_open_techniques)
	row.add_child(techniques)
	_command_buttons.append(techniques)
	_action_cards.append(techniques)

	var evolution := CommandButtonScript.new() as DigiCommandButton
	evolution.name = "EvolutionCommand"
	evolution.configure(
		"EVOLUTION",
		"Review Digivolution and Degeneration routes.",
		"",
		"evolution",
		V2.GREEN
	)
	evolution.set_minimal(true)
	evolution.set_compact(_density_compact)
	evolution.pressed.connect(_open_constellation.bind(instance.id))
	row.add_child(evolution)
	_command_buttons.append(evolution)
	_action_cards.append(evolution)

	var squad_state := _squad_role_action_state(instance)
	var squad_action := CommandButtonScript.new() as DigiCommandButton
	squad_action.name = "SquadRoleCommand"
	squad_action.configure(
		String(squad_state.get("label", "SQUAD ROLE")),
		String(squad_state.get("description", "Change this Digimon's Squad role.")),
		"",
		"party",
		V2.PURPLE
	)
	squad_action.set_minimal(true)
	squad_action.set_compact(_density_compact)
	var allowed := bool(squad_state.get("allowed", false))
	squad_action.set_meta("action_allowed", allowed)
	squad_action.set_interactive(allowed)
	squad_action.pressed.connect(_request_squad_role_change.bind(instance.id))
	row.add_child(squad_action)
	_command_buttons.append(squad_action)
	_action_cards.append(squad_action)

func _squad_role_action_state(instance: DigimonInstance) -> Dictionary:
	if instance == null:
		return {"allowed": false, "label": "SQUAD ROLE UNAVAILABLE", "description": "No Digimon selected."}
	var role := OverworldState.get_squad_role(instance.id)
	var active := OverworldState.get_active_instances()
	var reserve := OverworldState.get_reserve_party_instances()
	if role == PlayerCollection.SQUAD_ROLE_ACTIVE:
		if reserve.size() < OverworldState.get_max_reserve_party_size() and active.size() > 1:
			return {"allowed": true, "label": "MOVE TO RESERVE", "description": "Move this Digimon to an open Reserve slot."}
		if not reserve.is_empty():
			return {"allowed": true, "label": "SWAP WITH RESERVE", "description": "Choose a Reserve Digimon to exchange Squad roles."}
		return {"allowed": false, "label": "RESERVE UNAVAILABLE", "description": "Keep at least one Active Digimon and add a Reserve member before swapping."}
	if role == PlayerCollection.SQUAD_ROLE_RESERVE:
		if active.size() < OverworldState.get_max_active_party_size():
			return {"allowed": true, "label": "MOVE TO ACTIVE", "description": "Promote this Digimon into an open Active slot."}
		if not active.is_empty():
			return {"allowed": true, "label": "SWAP WITH ACTIVE", "description": "Choose an Active Digimon to exchange Squad roles."}
	return {"allowed": false, "label": "SQUAD ROLE UNAVAILABLE", "description": "This Digimon is not assigned to the Squad."}


func _request_squad_role_change(instance_id: String) -> void:
	var instance := OverworldState.get_instance_by_id(instance_id)
	if instance == null:
		return
	var role := OverworldState.get_squad_role(instance_id)
	var active := OverworldState.get_active_instances()
	var reserve := OverworldState.get_reserve_party_instances()
	if role == PlayerCollection.SQUAD_ROLE_ACTIVE:
		if reserve.size() < OverworldState.get_max_reserve_party_size() and active.size() > 1:
			_squad_role_mutation_in_progress = true
			var moved := OverworldState.add_to_reserve_party(instance_id)
			_squad_role_mutation_in_progress = false
			if moved:
				_finish_squad_role_change(instance_id)
			return
		if not reserve.is_empty():
			_begin_squad_swap(instance_id)
		return
	if role == PlayerCollection.SQUAD_ROLE_RESERVE:
		if active.size() < OverworldState.get_max_active_party_size():
			_squad_role_mutation_in_progress = true
			var moved := OverworldState.add_to_active_party(instance_id)
			_squad_role_mutation_in_progress = false
			if moved:
				_finish_squad_role_change(instance_id)
			return
		if not active.is_empty():
			_begin_squad_swap(instance_id)


func _begin_squad_swap(instance_id: String) -> void:
	var source := OverworldState.get_instance_by_id(instance_id)
	if source == null:
		return
	var source_role := OverworldState.get_squad_role(instance_id)
	if source_role not in [PlayerCollection.SQUAD_ROLE_ACTIVE, PlayerCollection.SQUAD_ROLE_RESERVE]:
		return
	var species := _database.get_by_seed(source.species_seed)
	_squad_swap_source_id = instance_id
	_squad_swap_source_name = source.get_display_name(String(species.get("name", "Digimon")))
	_mode = MenuMode.ROSTER
	_roster_page = 1 if source_role == PlayerCollection.SQUAD_ROLE_ACTIVE else 0
	var first_index := _first_index_for_roster_page(_roster_page)
	if first_index >= 0:
		_selected_index = first_index
	_refresh_collection()
	call_deferred("_focus_selected_roster_card")


func _complete_squad_swap(target_index: int) -> void:
	var party := _party_instances()
	if target_index < 0 or target_index >= party.size():
		return
	var source_id := _squad_swap_source_id
	var source_role := OverworldState.get_squad_role(source_id)
	var target: DigimonInstance = party[target_index]
	var target_role := OverworldState.get_squad_role(target.id)
	if source_role == target_role:
		return
	var active_id := source_id if source_role == PlayerCollection.SQUAD_ROLE_ACTIVE else target.id
	var reserve_id := source_id if source_role == PlayerCollection.SQUAD_ROLE_RESERVE else target.id
	_squad_role_mutation_in_progress = true
	var swapped := OverworldState.swap_party_with_reserve(active_id, reserve_id)
	_squad_role_mutation_in_progress = false
	if not swapped:
		return
	_finish_squad_role_change(source_id)


func _finish_squad_role_change(instance_id: String) -> void:
	_squad_swap_source_id = ""
	_squad_swap_source_name = ""
	_mode = MenuMode.ROSTER
	var party := _party_instances()
	for index in range(party.size()):
		if party[index].id == instance_id:
			_selected_index = index
			_roster_page = _squad_page_for_index(index)
			break
	_refresh_collection()
	call_deferred("_focus_selected_roster_card")


func _cancel_squad_swap() -> void:
	var source_id := _squad_swap_source_id
	_squad_swap_source_id = ""
	_squad_swap_source_name = ""
	_mode = MenuMode.ROSTER
	var party := _party_instances()
	for index in range(party.size()):
		if party[index].id == source_id:
			_selected_index = index
			_roster_page = _squad_page_for_index(index)
			break
	_refresh_collection()
	call_deferred("_focus_selected_roster_card")


func _build_squad_swap_prompt(target: DigimonInstance) -> void:
	var source := OverworldState.get_instance_by_id(_squad_swap_source_id)
	if source == null or target == null:
		_cancel_squad_swap()
		return
	var source_species := _database.get_by_seed(source.species_seed)
	var target_species := _database.get_by_seed(target.species_seed)
	var source_name := source.get_display_name(String(source_species.get("name", "Digimon")))
	var target_name := target.get_display_name(String(target_species.get("name", "Digimon")))
	var target_role := OverworldState.get_squad_role(target.id)
	var target_role_label := "ACTIVE" if target_role == PlayerCollection.SQUAD_ROLE_ACTIVE else "RESERVE"

	var panel := PanelContainer.new()
	panel.name = "SquadSwapPrompt"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.PURPLE))
	_detail_list.add_child(panel)
	var margin := _margin(24, 24, 24, 24)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	var title := _label("SWAP SQUAD ROLE", 22 if not _density_compact else 18, V2.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var instruction := _label(
		"%s  ↔  %s" % [source_name, target_name],
		16 if not _density_compact else 14,
		V2.CYAN,
		true
	)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(instruction)
	var description := _label(
		"Select a %s Digimon from the roster to confirm the swap." % target_role_label.capitalize(),
		12,
		V2.MUTED
	)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	var cancel := Button.new()
	cancel.name = "CancelSquadSwap"
	cancel.text = "CANCEL SWAP"
	cancel.custom_minimum_size = Vector2(220.0, V2.TOUCH_TARGET)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.add_theme_font_size_override("font_size", 13)
	cancel.add_theme_color_override("font_color", V2.WHITE)
	for state_name in ["normal", "hover", "pressed"]:
		cancel.add_theme_stylebox_override(state_name, V2.hospital_button_style(V2.PURPLE, state_name))
	V2.apply_heading(cancel)
	cancel.pressed.connect(_cancel_squad_swap)
	stack.add_child(cancel)


func _build_overview_column(instance: DigimonInstance) -> void:
	var panel := PanelContainer.new()
	panel.name = "OverviewPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))
	_sidebar_column.add_child(panel)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("OVERVIEW", "", V2.CYAN, "info")
	stack.add_child(header)

	var tabs_margin := _margin(8, 7, 8, 5)
	stack.add_child(tabs_margin)
	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 5)
	tabs_margin.add_child(tabs)
	_overview_tab_buttons.clear()
	for spec in [["stats", "STATS"], ["development", "DEVELOPMENT"]]:
		var tab_id := String(spec[0])
		var button := _overview_button(String(spec[1]), tab_id == _overview_tab)
		button.pressed.connect(_set_overview_tab.bind(tab_id))
		tabs.add_child(button)
		_overview_tab_buttons[tab_id] = button

	var content_margin := _margin(8, 4, 8, 8)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(content_margin)
	_overview_content = VBoxContainer.new()
	_overview_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_overview_content)

	if _overview_tab == "development":
		_development_panel = DevelopmentPanelScript.new()
		_development_panel.set_workspace_mode(true, _density_compact)
		_development_panel.configure(instance)
		_development_panel.custom_minimum_size.y = 0.0
		_development_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_overview_content.add_child(_development_panel)
	else:
		_stats_panel = StatsPanelScript.new()
		_stats_panel.set_workspace_mode(true, _density_compact)
		_stats_panel.configure(_progression.get_final_stats(instance), instance.current_hp, instance.current_mp)
		_stats_panel.custom_minimum_size.y = 0.0
		_stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_overview_content.add_child(_stats_panel)


func _overview_button(text: String, active: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 40.0 if not _density_compact else 36.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
	button.add_theme_stylebox_override("normal", V2.pill_style(V2.CYAN, active))
	button.add_theme_stylebox_override("hover", V2.hospital_button_style(V2.CYAN, "hover"))
	button.add_theme_stylebox_override("pressed", V2.hospital_button_style(V2.CYAN, "pressed"))
	V2.apply_heading(button)
	return button


func _set_overview_tab(tab_id: String) -> void:
	if tab_id == _overview_tab:
		return
	_overview_tab = tab_id
	var action_focus := _current_action_index()
	_refresh_details()
	if _mode == MenuMode.ACTIONS:
		call_deferred("_focus_action", action_focus)


func _switch_overview_tab(direction: int) -> void:
	if _mode == MenuMode.TECHNIQUES:
		return
	var next := "development" if _overview_tab == "stats" else "stats"
	if direction != 0:
		_set_overview_tab(next)


func _set_main_tab(tab_id: String) -> void:
	if tab_id == _main_tab or not ["party", "digipedia", "system"].has(tab_id):
		return
	_main_tab = tab_id
	_header.set_active_tab(tab_id)
	_layout()
	_update_footer_hints()
	if tab_id == "party":
		if _mode == MenuMode.ACTIONS:
			call_deferred("_focus_action", 0)
		elif _mode == MenuMode.TECHNIQUES:
			call_deferred("_focus_first_technique_control")
		else:
			call_deferred("_focus_selected_roster_card")
	else:
		get_viewport().gui_release_focus()


func _sync_main_tab_visibility() -> void:
	if _soon_label == null:
		return
	var party_visible := _main_tab == "party"
	_soon_label.visible = not party_visible
	if not party_visible:
		_collection_panel.visible = false
		_detail_panel.visible = false
		var compact_back := _menu_root.get_node_or_null("CompactBackToParty") as Control
		if compact_back != null:
			compact_back.visible = false


func _update_action_state() -> void:
	var active := _mode == MenuMode.ACTIONS
	for button in _command_buttons:
		var allowed := bool(button.get_meta("action_allowed", true))
		button.disabled = not active or not allowed
		button.focus_mode = Control.FOCUS_ALL if active and allowed else Control.FOCUS_NONE


func _return_to_roster() -> void:
	_mode = MenuMode.ROSTER
	_refresh_details()
	call_deferred("_focus_selected_roster_card")


func _open_techniques() -> void:
	_mode = MenuMode.TECHNIQUES
	_technique_page = 0
	_refresh_details()
	call_deferred("_focus_first_technique_control")


func _leave_techniques() -> void:
	_mode = MenuMode.ACTIONS
	_refresh_details()
	call_deferred("_focus_action", 0)


func _build_technique_view(instance: DigimonInstance) -> void:
	var panel := PanelContainer.new()
	panel.name = "TechniqueLibraryView"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.78), 9))
	_detail_list.add_child(panel)
	_technique_panel = panel

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TECHNIQUE LIBRARY", "Favorite shortcuts and archived knowledge", V2.CYAN, "techniques")
	stack.add_child(header)

	var ordered := _ordered_techniques(instance)
	_technique_page_size = TECHNIQUE_PAGE_SIZE_COMPACT if _density_compact else TECHNIQUE_PAGE_SIZE
	var page_count := _page_count(ordered.size(), _technique_page_size)
	_technique_page = clampi(_technique_page, 0, page_count - 1)

	var summary_margin := _margin(12, 8, 12, 7)
	stack.add_child(summary_margin)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	summary_margin.add_child(summary)
	var title := _label("%d LEARNED" % instance.learned_skills.size(), 11, V2.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_child(title)
	summary.add_child(_label("FAVORITES %d / %d" % [instance.favorite_skills.size(), DigimonInstance.MAX_FAVORITE_SKILLS], 10, V2.AMBER, true))

	var list_margin := _margin(12, 0, 12, 4)
	list_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(list_margin)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_BEGIN
	list.add_theme_constant_override("separation", 7)
	list_margin.add_child(list)

	if ordered.is_empty():
		list.add_child(_empty_message("No learned techniques yet."))
	else:
		var start := _technique_page * _technique_page_size
		var finish := mini(ordered.size(), start + _technique_page_size)
		for index in range(start, finish):
			var skill_id := String(ordered[index])
			var wrapper := PanelContainer.new()
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.custom_minimum_size.y = 58.0 if _density_compact else 66.0
			wrapper.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.74), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.58), 7))
			list.add_child(wrapper)
			var row_margin := _margin(10, 6, 10, 6)
			wrapper.add_child(row_margin)
			var technique_row := _technique_row(instance, skill_id)
			row_margin.add_child(technique_row)
			var controls := _focusable_descendants(technique_row)
			for control_index in range(controls.size()):
				controls[control_index].set_meta("technique_skill", skill_id)
				controls[control_index].set_meta("technique_column", control_index)
			_technique_focus_rows.append(controls)

	_technique_pager = PagerScript.new() as DigiPager
	_technique_pager.name = "TechniquePager"
	_technique_pager.configure(_technique_page, page_count)
	_technique_pager.set_compact(_density_compact)
	_technique_pager.page_delta_requested.connect(_turn_technique_page)
	stack.add_child(_technique_pager)
	call_deferred("_wire_technique_focus")


func _ordered_techniques(instance: DigimonInstance) -> Array[String]:
	var ordered: Array[String] = []
	for skill_id: String in instance.favorite_skills:
		if not ordered.has(skill_id):
			ordered.append(skill_id)
	for skill_id: String in instance.learned_skills:
		if not ordered.has(skill_id) and not instance.archived_skills.has(skill_id):
			ordered.append(skill_id)
	for skill_id: String in instance.archived_skills:
		if not ordered.has(skill_id):
			ordered.append(skill_id)
	return ordered


func _toggle_favorite(instance_id: String, skill_id: String, was_favorite: bool) -> void:
	var column := _focused_technique_column(skill_id)
	if was_favorite:
		OverworldState.unfavorite_technique(instance_id, skill_id)
	else:
		OverworldState.favorite_technique(instance_id, skill_id)
	_restore_technique_after_mutation(instance_id, skill_id, column)


func _toggle_archive(instance_id: String, skill_id: String, was_archived: bool) -> void:
	var column := _focused_technique_column(skill_id)
	if was_archived:
		OverworldState.restore_technique(instance_id, skill_id)
	else:
		OverworldState.archive_technique(instance_id, skill_id)
	_restore_technique_after_mutation(instance_id, skill_id, column)


func _move_favorite(instance_id: String, skill_id: String, new_index: int) -> void:
	var column := _focused_technique_column(skill_id)
	OverworldState.move_favorite_technique(instance_id, skill_id, new_index)
	_restore_technique_after_mutation(instance_id, skill_id, column)


func _restore_technique_after_mutation(instance_id: String, skill_id: String, column: int) -> void:
	var instance := OverworldState.get_instance_by_id(instance_id)
	if instance != null:
		var ordered := _ordered_techniques(instance)
		var position := ordered.find(skill_id)
		if position >= 0:
			_technique_page = position / maxi(1, _technique_page_size)
	_refresh_details()
	call_deferred("_restore_technique_focus", skill_id, column)


func _focused_technique_column(skill_id: String) -> int:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and String(owner.get_meta("technique_skill", "")) == skill_id:
		return int(owner.get_meta("technique_column", 0))
	return 0


func _restore_technique_focus(skill_id: String, column: int) -> void:
	for row in _technique_focus_rows:
		for control in row:
			if String((control as Control).get_meta("technique_skill", "")) == skill_id:
				var target_index := clampi(column, 0, row.size() - 1)
				(row[target_index] as Control).grab_focus()
				return
	_focus_first_technique_control()


func _wire_technique_focus() -> void:
	for row_index in range(_technique_focus_rows.size()):
		var row := _technique_focus_rows[row_index]
		if row.is_empty():
			continue
		for column in range(row.size()):
			var control := row[column] as Control
			var left := row[posmod(column - 1, row.size())] as Control
			var right := row[posmod(column + 1, row.size())] as Control
			control.focus_neighbor_left = control.get_path_to(left)
			control.focus_neighbor_right = control.get_path_to(right)
			if _technique_focus_rows.size() > 1:
				var previous_row := _technique_focus_rows[posmod(row_index - 1, _technique_focus_rows.size())]
				var next_row := _technique_focus_rows[posmod(row_index + 1, _technique_focus_rows.size())]
				if not previous_row.is_empty():
					var up := previous_row[mini(column, previous_row.size() - 1)] as Control
					control.focus_neighbor_top = control.get_path_to(up)
				if not next_row.is_empty():
					var down := next_row[mini(column, next_row.size() - 1)] as Control
					control.focus_neighbor_bottom = control.get_path_to(down)


func _focus_first_technique_control() -> void:
	for row in _technique_focus_rows:
		if not row.is_empty():
			(row[0] as Control).grab_focus()
			return


func _move_technique_vertical(direction: int) -> void:
	if _technique_focus_rows.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var row_index := -1
	var column := 0
	for index in range(_technique_focus_rows.size()):
		var row := _technique_focus_rows[index]
		var found := row.find(owner)
		if found >= 0:
			row_index = index
			column = found
			break
	if row_index < 0:
		_focus_first_technique_control()
		return
	var target_row := _technique_focus_rows[posmod(row_index + direction, _technique_focus_rows.size())]
	if not target_row.is_empty():
		(target_row[mini(column, target_row.size() - 1)] as Control).grab_focus()


func _move_technique_horizontal(direction: int) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	for row in _technique_focus_rows:
		var index := row.find(owner)
		if index >= 0 and not row.is_empty():
			(row[posmod(index + direction, row.size())] as Control).grab_focus()
			return
	_focus_first_technique_control()


func _turn_technique_page(delta: int) -> void:
	var party := _party_instances()
	if party.is_empty():
		return
	var instance := party[clampi(_selected_index, 0, party.size() - 1)]
	var ordered := _ordered_techniques(instance)
	var count := _page_count(ordered.size(), _technique_page_size)
	if count <= 1:
		return
	_technique_page = posmod(_technique_page + delta, count)
	_refresh_details()
	call_deferred("_focus_first_technique_control")


func _turn_roster_page(delta: int) -> void:
	if not _squad_swap_source_id.is_empty():
		return
	var party := _party_instances()
	var count := _squad_roster_page_count()
	if party.is_empty() or count <= 1:
		return
	_roster_page = posmod(_roster_page + delta, count)
	var first_index := _first_index_for_roster_page(_roster_page)
	if first_index >= 0:
		_selected_index = first_index
	_mode = MenuMode.ROSTER
	_refresh_collection()
	call_deferred("_focus_selected_roster_card")


func _turn_active_page(delta: int) -> void:
	if _mode == MenuMode.TECHNIQUES:
		_turn_technique_page(delta)
	elif _mode == MenuMode.ROSTER:
		_turn_roster_page(delta)


func _move_vertical(direction: int) -> void:
	if direction == 0:
		return
	match _mode:
		MenuMode.ROSTER:
			_move_roster_focus(direction)
		MenuMode.TECHNIQUES:
			_move_technique_vertical(direction)
		MenuMode.ACTIONS:
			_move_action_vertical(direction)


func _move_horizontal(direction: int) -> void:
	if direction == 0:
		return
	match _mode:
		MenuMode.ACTIONS:
			_move_action_focus(direction)
		MenuMode.TECHNIQUES:
			_move_technique_horizontal(direction)
		MenuMode.ROSTER:
			# The Party list is vertical. Left/right never aliases up/down.
			pass


func _move_roster_focus(direction: int) -> void:
	if _visible_party_indices.is_empty():
		return
	var local := _visible_party_indices.find(_selected_index)
	if local < 0:
		local = 0
	local = posmod(local + direction, _visible_party_indices.size())
	_selected_index = _visible_party_indices[local]
	_style_collection_selection()
	_refresh_details()
	if local < _buttons.size():
		_buttons[local].grab_focus()


func _move_action_focus(direction: int) -> void:
	if _command_buttons.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var index := _command_buttons.find(owner)
	if index < 0:
		index = 0
	for offset in range(1, _command_buttons.size() + 1):
		var candidate := posmod(index + direction * offset, _command_buttons.size())
		if not _command_buttons[candidate].disabled:
			_command_buttons[candidate].grab_focus()
			return


func _move_action_vertical(direction: int) -> void:
	# The redesigned command surface is a single row. Supporting both axes keeps
	# controller navigation forgiving without introducing a hidden second row.
	_move_action_focus(direction)

func _focus_action(index: int) -> void:
	if _command_buttons.is_empty():
		return
	var start := clampi(index, 0, _command_buttons.size() - 1)
	for offset in range(_command_buttons.size()):
		var candidate := posmod(start + offset, _command_buttons.size())
		if not _command_buttons[candidate].disabled:
			_command_buttons[candidate].grab_focus()
			return


func _current_action_index() -> int:
	var owner := get_viewport().gui_get_focus_owner()
	var index := _command_buttons.find(owner)
	return maxi(0, index)


func _focus_selected_roster_card() -> void:
	var local := _visible_party_indices.find(_selected_index)
	if local >= 0 and local < _buttons.size():
		_buttons[local].grab_focus()
	elif not _buttons.is_empty():
		_buttons[0].grab_focus()


func _wire_focus_navigation() -> void:
	# Focus movement is explicit in _input so the D-pad never escapes into the
	# header, pager or informational overview tabs.
	var close := _header.get_close_button() if _header != null else null
	if close != null:
		close.focus_mode = Control.FOCUS_NONE
	for button in _overview_tab_buttons.values():
		(button as Button).focus_mode = Control.FOCUS_NONE
	if _roster_pager != null:
		for child in _roster_pager.get_children():
			if child is Button:
				(child as Button).focus_mode = Control.FOCUS_NONE


func _close_constellation() -> void:
	if _constellation != null:
		_constellation.visible = false
	_refresh_collection()
	_mode = MenuMode.ACTIONS
	_refresh_details()
	call_deferred("_focus_action", 1)


func _update_account() -> void:
	if _header != null:
		_header.set_bits(OverworldState.get_bits())


func _on_account_rewards_changed(_bits: int, _digi_data: Dictionary) -> void:
	_update_account()


func _update_footer_hints() -> void:
	if _hint_bar == null:
		return
	_hint_bar.set_primary_tabs_enabled(true)
	_hint_bar.set_secondary_tabs_enabled(_main_tab == "party" and _mode != MenuMode.TECHNIQUES and _squad_swap_source_id.is_empty())
	if _main_tab != "party":
		_hint_bar.set_pagination_enabled(false)
		_hint_bar.set_description("%s · Soon" % _main_tab.capitalize())
		return
	var pages := 1
	if not _squad_swap_source_id.is_empty():
		pages = 1
	elif _mode == MenuMode.TECHNIQUES:
		var party := _party_instances()
		if not party.is_empty():
			var instance := party[clampi(_selected_index, 0, party.size() - 1)]
			pages = _page_count(_ordered_techniques(instance).size(), maxi(1, _technique_page_size))
	else:
		pages = _squad_roster_page_count()
	_hint_bar.set_pagination_enabled(pages > 1)
	_hint_bar.set_scroll_hint_enabled(false)
	_hint_bar.set_hide_hints_on_touch(true)
	if not _squad_swap_source_id.is_empty():
		var target_label := "Reserve" if _roster_page == 1 else "Active"
		_hint_bar.set_description("Swap %s · choose a %s Digimon. Back cancels." % [_squad_swap_source_name, target_label])
	elif _mode == MenuMode.TECHNIQUES:
		_hint_bar.set_description("Technique Library · favorite, reorder or archive learned techniques.")
	elif _mode == MenuMode.ACTIONS:
		_hint_bar.set_description("Choose a command for the selected Digimon.")
	else:
		var roster_label := "Active" if _roster_page == 0 else "Reserve"
		_hint_bar.set_description("Browse %s Squad members. Confirm a Digimon to access commands." % roster_label)


func _layout() -> void:
	if _panel == null or _menu_root == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var width := maxf(640.0, physical.x)
	var height := maxf(420.0, physical.y)
	var compact := width < COMPACT_WIDTH or height < COMPACT_HEIGHT
	var density_changed := compact != _density_compact
	_density_compact = compact

	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(width, height)
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	var header_h := 60.0 if not compact else 54.0
	var footer_h := 62.0 if not compact else 52.0
	var edge := 20.0 if not compact else 10.0
	var gap := 10.0
	var top_gap := 12.0 if not compact else 8.0
	var bottom_gap := 12.0 if not compact else 8.0

	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_header_rule.position = Vector2(0.0, header_h - 1.0)
	_header_rule.size = Vector2(width, 1.0)
	_hint_bar.position = Vector2(0.0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)

	var body_top := header_h + top_gap
	var body_bottom := height - footer_h - bottom_gap
	var body_h := maxf(300.0, body_bottom - body_top)
	var roster_w := clampf(width * (0.29 if compact else 0.225), 210.0 if compact else 270.0, 320.0)
	_collection_panel.position = Vector2(edge, body_top)
	_collection_panel.size = Vector2(roster_w, body_h)
	_detail_panel.position = Vector2(edge + roster_w + gap, body_top)
	_detail_panel.size = Vector2(maxf(360.0, width - edge * 2.0 - roster_w - gap), body_h)

	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roster_pager.set_compact(compact)

	if density_changed:
		call_deferred("_refresh_collection")
	elif _mode != MenuMode.TECHNIQUES:
		call_deferred("_refresh_details")


func _roster_card_height() -> float:
	return 108.0 if _density_compact else 128.0


func _is_index_on_roster_page(index: int) -> bool:
	return _squad_indices_for_page(_roster_page).has(index)


func _squad_roster_page_count() -> int:
	var reserve_count := OverworldState.get_reserve_party_instances().size()
	# Active is always page zero. Reserve gets a dedicated second page whenever
	# it contains at least one member, regardless of how many Active slots are
	# filled. This prevents role mixing when Active has fewer than three.
	return 2 if reserve_count > 0 else 1


func _squad_page_for_index(index: int) -> int:
	var active_count := OverworldState.get_active_instances().size()
	return 0 if index < active_count else 1


func _squad_indices_for_page(page: int) -> Array[int]:
	var result: Array[int] = []
	var active_count := OverworldState.get_active_instances().size()
	var reserve_count := OverworldState.get_reserve_party_instances().size()
	if page <= 0:
		for index in range(active_count):
			result.append(index)
	else:
		for reserve_index in range(reserve_count):
			result.append(active_count + reserve_index)
	return result


func _first_index_for_roster_page(page: int) -> int:
	var indices := _squad_indices_for_page(page)
	return indices[0] if not indices.is_empty() else -1


func _page_count(item_count: int, page_size: int) -> int:
	if item_count <= 0:
		return 1
	return int(ceil(float(item_count) / float(maxi(1, page_size))))


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _empty_message(text: String) -> Label:
	var label := _label(text, 13, V2.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
