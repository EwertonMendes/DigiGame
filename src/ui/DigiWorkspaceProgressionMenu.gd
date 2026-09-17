extends "res://src/ui/DigiIconProgressionMenu.gd"
class_name DigiWorkspaceProgressionMenu

const UI = preload("res://src/ui/components/DigiUiTheme.gd")
const WorkspaceWalkPreview = preload("res://src/ui/DigimonWalkPreview.gd")
const WorkspaceTierIcon = preload("res://src/ui/components/DigiTierIcon.gd")
const WorkspacePager = preload("res://src/ui/components/DigiPager.gd")
const WorkspaceSectionHeader = preload("res://src/ui/components/DigiSectionHeader.gd")

const WORKSPACE_HEADER_HEIGHT := 86.0
const COMPACT_HEADER_HEIGHT := 72.0
const WORKSPACE_FOOTER_HEIGHT := 54.0
const WORKSPACE_EDGE := 24.0
const COMPACT_EDGE := 10.0
const WORKSPACE_GAP := 12.0
const WORKSPACE_TOP_GAP := 16.0
const COMPACT_TOP_GAP := 12.0
const WORKSPACE_BOTTOM_GAP := 12.0
const WORKSPACE_ROSTER_RATIO := 0.255
const WORKSPACE_ROSTER_MIN := 290.0
const WORKSPACE_ROSTER_MAX := 430.0
const WORKSPACE_COMPACT_WIDTH := 980.0
const WORKSPACE_COMPACT_HEIGHT := 600.0
const WORKSPACE_TECHNIQUE_PAGE_SIZE := 4
const WORKSPACE_TECHNIQUE_PAGE_SIZE_COMPACT := 3

var _compact_back_button: Button
var _technique_back_button: Button


func open_menu() -> void:
	super.open_menu()
	_layout()


func _build() -> void:
	super._build()

	_header.set_workspace_mode(true)
	_collection_panel.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
	_detail_panel.add_theme_stylebox_override("panel", UI.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))

	# The Hospital/DigiLab workspace keeps one shared outer inset around the
	# complete roster column. Re-parenting the already-built stack keeps the base
	# interaction logic intact while moving spacing responsibility to one place.
	var roster_stack := _collection_panel.get_child(0) as VBoxContainer
	if roster_stack != null:
		_collection_panel.remove_child(roster_stack)
		var roster_margin := _margin(10, 10, 10, 10)
		roster_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_collection_panel.add_child(roster_margin)
		roster_margin.add_child(roster_stack)
		roster_stack.add_theme_constant_override("separation", 10)

	_collection_header.set_workspace_mode(true)
	_collection_header.custom_minimum_size.y = 56.0
	_collection_header.add_theme_stylebox_override("panel", UI.hospital_button_style(UI.CYAN, "focus"))

	var roster_inset := _collection_scroll.get_parent() as MarginContainer
	if roster_inset != null:
		_set_margin(roster_inset, 0, 0, 0, 0)
	_collection_grid.add_theme_constant_override("v_separation", 9)
	_roster_pager.set_workspace_mode(true)

	var detail_margin := _detail_scroll.get_parent() as MarginContainer
	if detail_margin != null:
		_set_margin(detail_margin, 0, 0, 0, 0)

	_compact_back_button = _workspace_button("‹  PARTY", UI.CYAN)
	_compact_back_button.name = "CompactBackToParty"
	_compact_back_button.custom_minimum_size = Vector2(148.0, 44.0)
	_compact_back_button.visible = false
	_compact_back_button.pressed.connect(_return_to_roster)
	_menu_root.add_child(_compact_back_button)


func _collection_button(instance: DigimonInstance, species: Dictionary, index: int) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := UI.rank_color(rank)
	var selected := index == _selected_index
	var button := Button.new()
	button.name = "PartyCard%02d" % index
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WorkspaceWalkPreview.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(76.0, 76.0) if _density_compact else Vector2(92.0, 92.0)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	var name := _label(display_name, 17 if _density_compact else 20, UI.WHITE, true)
	name.name = "Name"
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(meta)
	var level_rank := _label("Lv. %d · %s" % [instance.level, rank], 12 if _density_compact else 14, rank_color, true)
	level_rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_rank.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_child(level_rank)
	var tier := WorkspaceTierIcon.new() as DigiTierIcon
	tier.configure(instance.tier, Vector2(30.0, 22.0) if _density_compact else Vector2(34.0, 24.0))
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(tier)

	var stats := _progression.get_final_stats(instance)
	var max_hp := maxi(1, int(stats.get("hp", 1)))
	var hp := _label("HP  %d / %d" % [clampi(instance.current_hp, 0, max_hp), max_hp], 12 if _density_compact else 14, UI.TEXT, false)
	hp.name = "Health"
	copy.add_child(hp)

	var hp_bar := _mini_progress(UI.GREEN)
	hp_bar.name = "HpBar"
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(clampi(instance.current_hp, 0, max_hp))
	hp_bar.custom_minimum_size = Vector2(90.0, 8.0)
	copy.add_child(hp_bar)

	_buttons.append(button)
	return button


func _style_collection_button(button: Button, selected: bool, _rank_color: Color) -> void:
	button.add_theme_stylebox_override("normal", UI.hospital_panel_style(UI.CYAN, selected))
	button.add_theme_stylebox_override("hover", UI.hospital_button_style(UI.CYAN, "hover"))
	button.add_theme_stylebox_override("focus", UI.hospital_button_style(UI.CYAN, "focus"))
	button.add_theme_stylebox_override("pressed", UI.hospital_button_style(UI.CYAN, "pressed"))
	button.add_theme_stylebox_override("hover_pressed", UI.hospital_button_style(UI.CYAN, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.hospital_button_style(UI.CYAN, "disabled"))


func _refresh_details() -> void:
	super._refresh_details()
	_restyle_detail_surface()


func _restyle_detail_surface() -> void:
	if _mode == MenuMode.TECHNIQUES:
		return
	if _body_grid != null:
		_body_grid.add_theme_constant_override("h_separation", WORKSPACE_GAP)
	if _primary_column != null:
		_primary_column.size_flags_stretch_ratio = 1.36
		_primary_column.custom_minimum_size.x = 300.0 if _density_compact else 430.0
		_primary_column.add_theme_constant_override("separation", WORKSPACE_GAP)
	if _sidebar_column != null:
		_sidebar_column.size_flags_stretch_ratio = 1.0
		_sidebar_column.custom_minimum_size.x = 220.0 if _density_compact else 340.0
		_sidebar_column.add_theme_constant_override("separation", WORKSPACE_GAP)

	if _action_panel != null:
		_action_panel.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
		_set_workspace_headers(_action_panel)

	if _sidebar_column != null:
		var overview := _sidebar_column.get_node_or_null("OverviewPanel") as PanelContainer
		if overview != null:
			overview.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
			_set_workspace_headers(overview)

	for raw_button in _overview_tab_buttons.values():
		var button := raw_button as Button
		if button == null:
			continue
		button.custom_minimum_size.y = 44.0 if not _density_compact else 40.0
		button.add_theme_font_size_override("font_size", 12 if not _density_compact else 11)

	if _stats_panel != null:
		_stats_panel.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
		_set_workspace_headers(_stats_panel)
	if _development_panel != null:
		_development_panel.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.PURPLE))
		_set_workspace_headers(_development_panel)


func _build_technique_view(instance: DigimonInstance) -> void:
	var panel := PanelContainer.new()
	panel.name = "TechniqueLibraryView"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
	_detail_list.add_child(panel)
	_technique_panel = panel

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var header := WorkspaceSectionHeader.new() as DigiSectionHeader
	header.configure("TECHNIQUE LIBRARY", "Favorite shortcuts and archived knowledge", UI.CYAN, "techniques")
	header.set_workspace_mode(true)
	stack.add_child(header)

	var ordered := _ordered_techniques(instance)
	_technique_page_size = WORKSPACE_TECHNIQUE_PAGE_SIZE_COMPACT if _density_compact else WORKSPACE_TECHNIQUE_PAGE_SIZE
	var page_count := _page_count(ordered.size(), _technique_page_size)
	_technique_page = clampi(_technique_page, 0, page_count - 1)

	var summary_margin := _margin(12, 10, 12, 8)
	stack.add_child(summary_margin)
	var summary := HBoxContainer.new()
	summary.custom_minimum_size.y = 44.0
	summary.add_theme_constant_override("separation", 12)
	summary_margin.add_child(summary)

	_technique_back_button = _workspace_button("‹  DETAILS", UI.CYAN)
	_technique_back_button.name = "TechniqueBack"
	_technique_back_button.custom_minimum_size = Vector2(148.0, 44.0)
	_technique_back_button.pressed.connect(_leave_techniques)
	summary.add_child(_technique_back_button)
	_technique_focus_rows.append([_technique_back_button])

	var learned := _label("%d LEARNED" % instance.learned_skills.size(), 12 if _density_compact else 14, UI.TEXT, true)
	learned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_child(learned)
	var favorites := _label("FAVORITES %d / %d" % [instance.favorite_skills.size(), DigimonInstance.MAX_FAVORITE_SKILLS], 11 if _density_compact else 13, UI.AMBER, true)
	favorites.size_flags_horizontal = Control.SIZE_SHRINK_END
	summary.add_child(favorites)

	var list_margin := _margin(12, 0, 12, 6)
	list_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(list_margin)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_BEGIN
	list.add_theme_constant_override("separation", 9)
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
			wrapper.custom_minimum_size.y = 66.0 if _density_compact else 76.0
			wrapper.add_theme_stylebox_override("panel", UI.hospital_panel_style(UI.CYAN))
			list.add_child(wrapper)
			var row_margin := _margin(12, 7, 12, 7)
			wrapper.add_child(row_margin)
			var technique_row := _technique_row(instance, skill_id)
			row_margin.add_child(technique_row)
			var controls := _focusable_descendants(technique_row)
			for control_index in range(controls.size()):
				controls[control_index].set_meta("technique_skill", skill_id)
				controls[control_index].set_meta("technique_column", control_index)
			_technique_focus_rows.append(controls)

	_technique_pager = WorkspacePager.new() as DigiPager
	_technique_pager.name = "TechniquePager"
	_technique_pager.set_workspace_mode(true)
	_technique_pager.set_compact(_density_compact)
	_technique_pager.configure(_technique_page, page_count)
	_technique_pager.page_delta_requested.connect(_turn_technique_page)
	stack.add_child(_technique_pager)
	call_deferred("_wire_technique_focus")


func _focus_first_technique_control() -> void:
	# Opening the library should land on content, not on the escape affordance.
	# The explicit Back button remains one D-pad step above the first technique.
	if _technique_focus_rows.size() > 1 and not _technique_focus_rows[1].is_empty():
		(_technique_focus_rows[1][0] as Control).grab_focus()
		return
	if not _technique_focus_rows.is_empty() and not _technique_focus_rows[0].is_empty():
		(_technique_focus_rows[0][0] as Control).grab_focus()


func _confirm_index(index: int) -> void:
	super._confirm_index(index)
	_layout()


func _return_to_roster() -> void:
	super._return_to_roster()
	_layout()


func _open_techniques() -> void:
	super._open_techniques()
	_layout()


func _leave_techniques() -> void:
	super._leave_techniques()
	_layout()


func _turn_roster_page(delta: int) -> void:
	var party := _party_instances()
	var count := _page_count(party.size(), ROSTER_PAGE_SIZE)
	if count <= 1:
		return
	var next_page := clampi(_roster_page + delta, 0, count - 1)
	if next_page == _roster_page:
		return
	_roster_page = next_page
	_selected_index = mini(_roster_page * ROSTER_PAGE_SIZE, party.size() - 1)
	_mode = MenuMode.ROSTER
	_refresh_collection()
	_layout()
	call_deferred("_focus_selected_roster_card")


func _turn_technique_page(delta: int) -> void:
	var party := _party_instances()
	if party.is_empty():
		return
	var instance := party[clampi(_selected_index, 0, party.size() - 1)]
	var ordered := _ordered_techniques(instance)
	var count := _page_count(ordered.size(), _technique_page_size)
	if count <= 1:
		return
	var next_page := clampi(_technique_page + delta, 0, count - 1)
	if next_page == _technique_page:
		return
	_technique_page = next_page
	_refresh_details()
	_layout()
	call_deferred("_focus_first_technique_control")


func _layout() -> void:
	if _panel == null or _menu_root == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var width := maxf(640.0, physical.x)
	var height := maxf(420.0, physical.y)
	var compact := width < WORKSPACE_COMPACT_WIDTH or height < WORKSPACE_COMPACT_HEIGHT
	var density_changed := compact != _density_compact
	_density_compact = compact

	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(width, height)
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	var header_h := COMPACT_HEADER_HEIGHT if compact else WORKSPACE_HEADER_HEIGHT
	var footer_h := WORKSPACE_FOOTER_HEIGHT
	var edge := COMPACT_EDGE if compact else WORKSPACE_EDGE
	var top_gap := COMPACT_TOP_GAP if compact else WORKSPACE_TOP_GAP

	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_header_rule.position = Vector2(0.0, header_h - 1.0)
	_header_rule.size = Vector2(width, 1.0)
	_hint_bar.position = Vector2(0.0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)

	var body_top := header_h + top_gap
	var body_bottom := height - footer_h - WORKSPACE_BOTTOM_GAP
	var body_h := maxf(220.0, body_bottom - body_top)

	if compact:
		var detail_open := _mode != MenuMode.ROSTER
		_collection_panel.visible = not detail_open
		_detail_panel.visible = detail_open
		_compact_back_button.visible = detail_open
		if not detail_open:
			_collection_panel.position = Vector2(edge, body_top)
			_collection_panel.size = Vector2(width - edge * 2.0, body_h)
		else:
			_compact_back_button.position = Vector2(edge, body_top)
			_compact_back_button.size = Vector2(148.0, 44.0)
			var detail_top := body_top + 52.0
			_detail_panel.position = Vector2(edge, detail_top)
			_detail_panel.size = Vector2(width - edge * 2.0, maxf(160.0, body_bottom - detail_top))
	else:
		_collection_panel.visible = true
		_detail_panel.visible = true
		_compact_back_button.visible = false
		var usable := width - edge * 2.0 - WORKSPACE_GAP * 2.0
		var roster_w := clampf(usable * WORKSPACE_ROSTER_RATIO, WORKSPACE_ROSTER_MIN, WORKSPACE_ROSTER_MAX)
		_collection_panel.position = Vector2(edge, body_top)
		_collection_panel.size = Vector2(roster_w, body_h)
		_detail_panel.position = Vector2(edge + roster_w + WORKSPACE_GAP, body_top)
		_detail_panel.size = Vector2(maxf(360.0, width - edge * 2.0 - roster_w - WORKSPACE_GAP), body_h)

	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roster_pager.set_workspace_mode(true)
	_roster_pager.set_compact(compact)

	if density_changed:
		call_deferred("_refresh_collection")


func _roster_card_height() -> float:
	return 102.0 if _density_compact else 116.0


func _workspace_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UI.WHITE)
	button.add_theme_color_override("font_hover_color", UI.WHITE)
	button.add_theme_color_override("font_focus_color", UI.WHITE)
	button.add_theme_color_override("font_disabled_color", UI.MUTED)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UI.hospital_button_style(accent, state))
	UI.apply_heading(button)
	return button


func _set_workspace_headers(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is DigiSectionHeader:
			(child as DigiSectionHeader).set_workspace_mode(true)
		_set_workspace_headers(child)


func _set_margin(margin: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
