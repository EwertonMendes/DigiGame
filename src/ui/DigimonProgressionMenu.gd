extends "res://src/ui/DigimonCollectionMenu.gd"
class_name DigimonProgressionMenu

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const ActionCardScript = preload("res://src/ui/components/DigiActionCard.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const ProfileHeroScript = preload("res://src/ui/components/DigiProfileHero.gd")
const StatsPanelScript = preload("res://src/ui/components/DigiStatsPanel.gd")
const DevelopmentPanelScript = preload("res://src/ui/components/DigiDevelopmentPanel.gd")
const EvolutionChartScript = preload("res://src/ui/EvolutionChart.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")

var _constellation: EvolutionChart
var _menu_root: Control
var _header: DigiModalHeader
var _header_rule: ColorRect
var _hint_bar: Control
var _body_grid: GridContainer
var _action_grid: GridContainer
var _primary_column: VBoxContainer
var _sidebar_column: VBoxContainer
var _technique_panel: Control
var _development_panel: Control
var _action_cards: Array[Control] = []
var _techniques_expanded := false


func _build() -> void:
	super._build()
	_backdrop.color = V2.BACKDROP
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(V2.BASE, Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.82), 14, Vector4.ZERO, 0.22)
	)

	_menu_root = Control.new()
	_menu_root.name = "DigimonV2Content"
	_menu_root.clip_contents = true
	_panel.add_child(_menu_root)
	for control: Control in [_title, _account, _close_button, _collection_panel, _detail_panel]:
		remove_child(control)
		_menu_root.add_child(control)

	# The legacy header controls remain alive for base-class compatibility, but
	# V2 uses one reusable header component shared by future modal migrations.
	_title.visible = false
	_account.visible = false
	_close_button.visible = false
	_close_button.focus_mode = Control.FOCUS_NONE

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "ModalHeader"
	_header.configure("DIGIMON", "Choose how you want to develop your Digimon.", OverworldState.get_bits(), true)
	_header.close_requested.connect(func(): close_requested.emit())
	_menu_root.add_child(_header)
	_header_rule = ColorRect.new()
	_header_rule.color = V2.separator_color(0.48)
	_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(_header_rule)

	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE_SOFT, V2.BORDER_SOFT, 12))
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.76), V2.BORDER_SOFT, 12))
	_set_panel_content_margin(_collection_panel, 10)
	_set_panel_content_margin(_detail_panel, 10)
	_detail_list.add_theme_constant_override("separation", 10)
	_collection_scroll.follow_focus = true
	_detail_scroll.follow_focus = true
	_detail_scroll.clip_contents = true
	_collection_scroll.scroll_deadzone = 8
	_detail_scroll.scroll_deadzone = 8
	SmoothScrollScript.attach(_collection_scroll)
	SmoothScrollScript.attach(_detail_scroll)

	_hint_bar = InputHintBarScript.new()
	_hint_bar.name = "InputHints"
	_menu_root.add_child(_hint_bar)

	_constellation = EvolutionChartScript.new() as EvolutionChart
	_constellation.name = "EvolutionChart"
	_constellation.visible = false
	_constellation.close_requested.connect(_close_constellation)
	_constellation.evolution_applied.connect(_on_evolution_state_changed)
	add_child(_constellation)


func open_menu() -> void:
	if _constellation != null:
		_constellation.visible = false
	super.open_menu()


func has_nested_view_open() -> bool:
	return _constellation != null and _constellation.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _constellation != null and _constellation.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_close_constellation()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _select_index(index: int) -> void:
	if index != _selected_index:
		_techniques_expanded = false
	super._select_index(index)


func _collection_button(instance: DigimonInstance, species: Dictionary, index: int) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := V2.rank_color(rank)
	var selected := index == _selected_index
	var button := Button.new()
	button.name = "Collection%02d" % index
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(226.0, 82.0)
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_select_index.bind(index))
	button.focus_entered.connect(_select_index.bind(index))
	_style_collection_button(button, selected, rank_color)

	var margin := _margin(10, 7, 10, 7)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(56.0, 56.0)
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	row.add_child(preview)
	_walk_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name_label := _label(display_name, 15, V2.TEXT, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name_label)
	var sub := _label("Lv %d  ·  %s" % [instance.level, rank], 10, rank_color.lightened(0.08), true)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(sub)
	var xp_required := _progression.exp_to_next_level(instance)
	var progress := _mini_progress(V2.AMBER if selected else rank_color)
	progress.max_value = maxf(1.0, float(xp_required))
	progress.value = float(instance.exp if xp_required > 0 else xp_required)
	progress.custom_minimum_size = Vector2(90.0, 6.0)
	copy.add_child(progress)
	_buttons.append(button)
	return button


func _refresh_details() -> void:
	if _detail_list == null:
		return
	for child in _detail_list.get_children():
		child.queue_free()
	_adaptive_stat_grids.clear()
	_section_grid = null
	_body_grid = null
	_action_grid = null
	_primary_column = null
	_sidebar_column = null
	_technique_panel = null
	_development_panel = null
	_action_cards.clear()

	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if collection.is_empty():
		var empty := _label("No Digimon yet. Convert Digi Data to create your first partner.", 15, V2.MUTED)
		empty.custom_minimum_size.y = 150.0
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_list.add_child(empty)
		return

	var instance: DigimonInstance = collection[clampi(_selected_index, 0, collection.size() - 1)]
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	var compact := V2.is_compact(get_viewport(), 900.0)
	var compact_hero := V2.physical_window_size(get_viewport()).x < 680.0

	# Desktop mirrors the approved prototype: identity + actions on the left and
	# compact combat/development information beside it from the very top.
	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 12)
	_body_grid.add_theme_constant_override("v_separation", 10)
	_detail_list.add_child(_body_grid)

	_primary_column = VBoxContainer.new()
	_primary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_column.size_flags_stretch_ratio = 1.72
	_primary_column.custom_minimum_size.x = 500.0
	_primary_column.add_theme_constant_override("separation", 10)
	_body_grid.add_child(_primary_column)
	_sidebar_column = VBoxContainer.new()
	_sidebar_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_column.size_flags_stretch_ratio = 0.84
	_sidebar_column.custom_minimum_size.x = 286.0
	_sidebar_column.add_theme_constant_override("separation", 10)
	_body_grid.add_child(_sidebar_column)

	var hero := ProfileHeroScript.new()
	hero.configure(instance, species, _progression, compact_hero)
	_primary_column.add_child(hero)
	_build_action_area(instance)
	_technique_panel = _build_skills_card(instance)
	_technique_panel.visible = _techniques_expanded
	_primary_column.add_child(_technique_panel)

	var stats_panel := StatsPanelScript.new()
	stats_panel.configure(_progression.get_final_stats(instance), instance.current_hp, instance.current_mp)
	_sidebar_column.add_child(stats_panel)
	_development_panel = DevelopmentPanelScript.new()
	_development_panel.configure(instance)
	_sidebar_column.add_child(_development_panel)

	_apply_adaptive_detail_layout(compact)
	call_deferred("_wire_focus_navigation")


func _build_action_area(instance: DigimonInstance) -> void:
	_primary_column.add_child(_label("ACTIONS", 11, V2.MUTED, true))
	var prompt := _label("What would you like to work on?", 9, V2.SUBTLE)
	_primary_column.add_child(prompt)
	_action_grid = GridContainer.new()
	_action_grid.columns = 3
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", 9)
	_action_grid.add_theme_constant_override("v_separation", 9)
	_primary_column.add_child(_action_grid)

	var learned := instance.learned_skills.size()
	var favorites := instance.favorite_skills.size()
	var techniques := ActionCardScript.new()
	techniques.configure(
		"TECHNIQUES",
		"View and manage learned techniques, favorites and mastery.",
		"%d learned · %d favorite%s" % [learned, favorites, "" if favorites == 1 else "s"],
		"techniques",
		V2.CYAN
	)
	techniques.pressed.connect(_toggle_technique_library)
	_action_grid.add_child(techniques)
	_action_cards.append(techniques)

	var evolutions: Array[Dictionary] = _progression.get_evolution_routes(instance)
	var degenerations: Array[Dictionary] = _progression.get_degeneration_routes(instance)
	var ready := 0
	for route: Dictionary in evolutions:
		if bool(route.get("unlocked", false)):
			ready += 1
	for route: Dictionary in degenerations:
		if bool(route.get("unlocked", false)):
			ready += 1
	var evolution := ActionCardScript.new()
	evolution.configure(
		"EVOLUTION",
		"Explore Digivolution and Degeneration routes and requirements.",
		"%d route%s available" % [ready, "" if ready == 1 else "s"],
		"evolution",
		V2.GREEN
	)
	evolution.pressed.connect(_open_constellation.bind(instance.id))
	_action_grid.add_child(evolution)
	_action_cards.append(evolution)

	var development := ActionCardScript.new()
	development.configure(
		"DEVELOPMENT",
		"Review aptitude, permanent training and Potential at a glance.",
		"Potential %d / %d" % [instance.potential, DigimonInstance.MAX_POTENTIAL],
		"training",
		V2.AMBER
	)
	development.pressed.connect(_show_development)
	_action_grid.add_child(development)
	_action_cards.append(development)


func _section_card(title: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(accent.r, accent.g, accent.b, 0.24), 10))
	var margin := _margin(11, 9, 11, 9)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)
	body.add_child(_label(title, 11, accent, true))
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1.0
	divider.color = V2.separator_color(0.26)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(divider)
	panel.set_meta("body", body)
	return panel


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 9))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 9))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 9))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 9))
	button.add_theme_stylebox_override("hover_pressed", V2.button_style(accent, "pressed", 9))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 9))
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.45))
	button.add_theme_color_override("icon_normal_color", V2.MUTED)
	button.add_theme_color_override("icon_hover_color", accent)
	button.add_theme_color_override("icon_focus_color", accent)
	button.add_theme_color_override("icon_pressed_color", accent)
	V2.apply_body(button)
	return button


func _style_collection_button(button: Button, selected: bool, rank_color: Color) -> void:
	var accent := V2.AMBER if selected else rank_color
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "selected" if selected else "normal", 10))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 10))
	button.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 10))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 10))
	button.add_theme_color_override("font_color", V2.TEXT)


func _mini_progress(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	return bar


func _toggle_technique_library() -> void:
	if _technique_panel == null:
		return
	_techniques_expanded = not _techniques_expanded
	_technique_panel.visible = _techniques_expanded
	call_deferred("_wire_focus_navigation")
	if _technique_panel.visible:
		call_deferred("_scroll_to_control", _technique_panel)


func _show_development() -> void:
	if _development_panel != null:
		call_deferred("_scroll_to_control", _development_panel)


func _scroll_to_control(control: Control) -> void:
	if _detail_scroll != null and control != null and control.is_inside_tree():
		_detail_scroll.ensure_control_visible(control)


func _open_constellation(instance_id: String) -> void:
	if _constellation == null:
		return
	var instance := OverworldState.get_instance_by_id(instance_id)
	if instance != null:
		_constellation.open_for(instance)


func _close_constellation() -> void:
	if _constellation != null:
		_constellation.visible = false
	_refresh_collection()
	if not _buttons.is_empty():
		_buttons[clampi(_selected_index, 0, _buttons.size() - 1)].grab_focus()


func _on_evolution_state_changed(_instance: DigimonInstance) -> void:
	OverworldState.notify_collection_changed()
	_refresh_collection()


func _wire_focus_navigation() -> void:
	if _buttons.is_empty() or _action_cards.is_empty():
		return
	var selected_button := _buttons[clampi(_selected_index, 0, _buttons.size() - 1)]
	var first_action := _action_cards[0]
	var compact := V2.is_compact(get_viewport(), 900.0)
	if not compact:
		for button in _buttons:
			if button != null and is_instance_valid(button):
				button.focus_neighbor_right = button.get_path_to(first_action)
		for card in _action_cards:
			if card != null and is_instance_valid(card):
				card.focus_neighbor_left = card.get_path_to(selected_button)

	var close_button := _header.get_close_button() if _header != null else null
	if close_button != null and is_instance_valid(close_button):
		close_button.focus_neighbor_down = close_button.get_path_to(first_action)
		for card in _action_cards:
			if card != null and is_instance_valid(card):
				card.focus_neighbor_up = card.get_path_to(close_button)

	if _techniques_expanded and _technique_panel != null:
		var technique_controls := _focusable_descendants(_technique_panel)
		if not technique_controls.is_empty():
			var first_technique := technique_controls[0]
			first_action.focus_neighbor_down = first_action.get_path_to(first_technique)
			first_technique.focus_neighbor_up = first_technique.get_path_to(first_action)


func _focusable_descendants(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
				result.append(control)
		result.append_array(_focusable_descendants(child))
	return result


func _apply_adaptive_detail_layout(compact: bool) -> void:
	if _body_grid != null:
		_body_grid.columns = 1 if compact else 2
	if _primary_column != null:
		_primary_column.custom_minimum_size.x = 0.0 if compact else 500.0
	if _sidebar_column != null:
		_sidebar_column.custom_minimum_size.x = 0.0 if compact else 286.0
	if _action_grid != null:
		var physical := V2.physical_window_size(get_viewport())
		_action_grid.columns = 1 if physical.x < 560.0 else (2 if compact else 3)


func _layout() -> void:
	if _panel == null or _menu_root == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := V2.is_compact(get_viewport(), 900.0)
	var edge := 10.0 if compact else 22.0
	var width := minf(1680.0, maxf(320.0, physical.x - edge * 2.0))
	var height := minf(940.0, maxf(300.0, physical.y - edge * 2.0))
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor

	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = origin
	_panel.size = Vector2(width, height)
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	var header_h := 66.0 if not compact else 58.0
	var footer_h := 52.0 if not compact else 46.0
	_header.position = Vector2(22.0, 8.0)
	_header.size = Vector2(maxf(0.0, width - 44.0), 50.0)
	_header_rule.position = Vector2(20.0, header_h - 1.0)
	_header_rule.size = Vector2(maxf(0.0, width - 40.0), 1.0)
	_hint_bar.position = Vector2(16.0, height - footer_h + 4.0)
	_hint_bar.size = Vector2(maxf(0.0, width - 32.0), footer_h - 8.0)

	var body_top := header_h + 7.0
	var body_bottom := height - footer_h - 4.0
	var body_h := maxf(100.0, body_bottom - body_top)
	if compact:
		var collection_h := clampf(body_h * 0.27, 82.0, 180.0)
		_collection_panel.position = Vector2(14.0, body_top)
		_collection_panel.size = Vector2(width - 28.0, collection_h)
		_detail_panel.position = Vector2(14.0, body_top + collection_h + 9.0)
		_detail_panel.size = Vector2(width - 28.0, maxf(90.0, body_h - collection_h - 9.0))
		_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_collection_grid.columns = 1 if width < 520.0 else (2 if width < 760.0 else 3)
	else:
		var collection_w := clampf(width * 0.205, 270.0, 310.0)
		var detail_x := 16.0 + collection_w + 12.0
		_collection_panel.position = Vector2(16.0, body_top)
		_collection_panel.size = Vector2(collection_w, body_h)
		_detail_panel.position = Vector2(detail_x, body_top)
		_detail_panel.size = Vector2(width - detail_x - 16.0, body_h)
		_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_collection_grid.columns = 1

	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_apply_adaptive_detail_layout(compact)
	if compact != _last_compact:
		_last_compact = compact
		call_deferred("_refresh_details")


func _update_account() -> void:
	var bits := OverworldState.get_bits()
	if _account != null:
		_account.text = "%d BITS" % bits
	if _header != null:
		_header.set_bits(bits)


func _set_panel_content_margin(panel: PanelContainer, value: int) -> void:
	if panel == null or panel.get_child_count() == 0:
		return
	var margin := panel.get_child(0) as MarginContainer
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", value)
	margin.add_theme_constant_override("margin_top", value)
	margin.add_theme_constant_override("margin_right", value)
	margin.add_theme_constant_override("margin_bottom", value)
