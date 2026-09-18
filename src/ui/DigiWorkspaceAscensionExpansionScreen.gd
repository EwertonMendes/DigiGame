extends "res://src/ui/DigiIconAscensionExpansionScreen.gd"
class_name DigiWorkspaceAscensionExpansionScreen

const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const WorkspaceBackdrop = preload("res://src/ui/components/DigiLabWorkspaceBackdrop.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const ConfirmationScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const SegmentScript = preload("res://src/ui/components/DigiSegmentedTabs.gd")
const CommandButtonScript = preload("res://src/ui/components/DigiCommandButton.gd")
const ProfilePanelScript = preload("res://src/ui/components/DigiCompactProfilePanel.gd")
const PickerScript = preload("res://src/ui/components/DigiRosterPickerModal.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const CHANGE_ARROW_ICON = preload("res://assets/ui/icons/hp_change_arrow.svg")

const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.25

var _workspace_page := 0
var _workspace_page_count := 1
var _compact_detail_open := false
var _section_mode := "tier"
var _left_trigger_down := false
var _right_trigger_down := false

var _workspace_pager: DigiPager
var _workspace_back_button: Button
var _section_tabs: HBoxContainer
var _tier_tab_button: Button
var _expansion_tab_button: Button
var _workspace_confirmation: DigiConfirmationModal
var _section_segments: DigiSegmentedTabs
var _donor_picker: DigiRosterPickerModal
var _workspace_progression: DigimonProgressionService


func open_screen(preferred_instance_id: String = "") -> void:
	_compact_detail_open = false
	_left_trigger_down = false
	_right_trigger_down = false
	super.open_screen(preferred_instance_id)
	WorkspaceChrome.configure_header(_header)
	_header.set_active_tab("ascension")
	_layout()


func _build() -> void:
	super._build()
	_workspace_progression = ProgressionServiceScript.new(_database) as DigimonProgressionService
	var backdrop := WorkspaceBackdrop.new() as DigiLabWorkspaceBackdrop
	backdrop.name = "DigiLabWorkspaceBackdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
	_backdrop.color = Color(V2.BACKDROP.r, V2.BACKDROP.g, V2.BACKDROP.b, 0.72)

	WorkspaceChrome.configure_header(_header)
	WorkspaceChrome.configure_hints(
		_hint_bar,
		"Raise individual Tier or configure permanent tactical Expansion.",
		"Tier Ascension / Expansion",
		false
	)
	WorkspaceChrome.style_workspace_panel(_collection_panel, V2.CYAN)
	WorkspaceChrome.style_workspace_panel(_detail_panel, V2.PURPLE)
	_collection_header.set_workspace_mode(true)
	_detail_header.set_workspace_mode(true)
	WorkspaceChrome.disable_scroll(_list_scroll)
	WorkspaceChrome.disable_scroll(_detail_scroll)

	var collection_stack := _collection_panel.get_child(0) as VBoxContainer
	var pager_margin := _margin(10, 2, 10, 8)
	_workspace_pager = PagerScript.new() as DigiPager
	_workspace_pager.name = "AscensionCollectionPager"
	_workspace_pager.set_workspace_mode(true)
	_workspace_pager.page_delta_requested.connect(_turn_workspace_page)
	pager_margin.add_child(_workspace_pager)
	collection_stack.add_child(pager_margin)

	_donor_picker = PickerScript.new() as DigiRosterPickerModal
	_donor_picker.name = "AscensionDonorPicker"
	_donor_picker.entry_selected.connect(_on_donor_picked)
	add_child(_donor_picker)

	_workspace_back_button = _workspace_button("‹  INDIVIDUALS", V2.CYAN)
	_workspace_back_button.name = "BackToIndividuals"
	_workspace_back_button.custom_minimum_size = Vector2(168.0, 44.0)
	_workspace_back_button.visible = false
	_workspace_back_button.pressed.connect(_return_to_collection)
	_root.add_child(_workspace_back_button)

	_workspace_confirmation = ConfirmationScript.new() as DigiConfirmationModal
	_workspace_confirmation.name = "AscensionWorkspaceConfirmation"
	_workspace_confirmation.confirmed.connect(_confirm_promotion)
	add_child(_workspace_confirmation)


func _input(event: InputEvent) -> void:
	if not visible or (_workspace_confirmation != null and _workspace_confirmation.visible):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB:
			if _header.select_adjacent_tab(1):
				get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_X and (not WorkspaceChrome.is_compact(get_viewport()) or _compact_detail_open):
			_toggle_section_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed:
		var joy := event as InputEventJoypadButton
		if joy.button_index == JOY_BUTTON_X and (not WorkspaceChrome.is_compact(get_viewport()) or _compact_detail_open):
			_toggle_section_mode()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT:
			_handle_page_trigger(motion.axis_value, -1, true)
		elif motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			_handle_page_trigger(motion.axis_value, 1, false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_workspace_confirmation != null and _workspace_confirmation.visible):
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

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	_workspace_page_count = maxi(1, ceili(float(collection.size()) / float(capacity)))
	_workspace_page = clampi(selected_index / capacity, 0, _workspace_page_count - 1)
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var start := _workspace_page * capacity
	var finish := mini(collection.size(), start + capacity)
	for index in range(start, finish):
		var instance := collection[index]
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var button := _collection_button(instance, species, active_ids)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(instance.id)
	_style_list_selection()
	_workspace_pager.configure(_workspace_page, _workspace_page_count)
	_hint_bar.set_pagination_enabled(_workspace_page_count > 1)


func _collection_button(instance: DigimonInstance, species: Dictionary, active_ids: Array[String]) -> Button:
	var button := super._collection_button(instance, species, active_ids)
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
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 3, 3, 2)
	var index := mini(_workspace_page * capacity, collection.size() - 1)
	if index >= 0:
		_selected_id = collection[index].id
	_pending_donor_id = ""
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

	var physical := V2.physical_window_size(get_viewport())
	var dense := WorkspaceChrome.is_compact(get_viewport()) or physical.y < 760.0
	var profile := ProfilePanelScript.new() as DigiCompactProfilePanel
	profile.configure(instance, species, _workspace_progression, true, dense)
	_detail.add_child(profile)

	if not _status_text.is_empty():
		_detail.add_child(_status_banner(_status_text))

	_section_segments = SegmentScript.new() as DigiSegmentedTabs
	_section_segments.name = "AscensionSectionTabs"
	_section_segments.configure([
		{"id": "tier", "label": "TIER ASCENSION", "accent": V2.PURPLE},
		{"id": "expansion", "label": "EXPANSION", "accent": V2.ORANGE},
	], _section_mode)
	_section_segments.tab_selected.connect(_set_section_mode)
	_section_segments.set_compact(dense)
	_detail.add_child(_section_segments)

	var section := _tier_workspace(instance) if _section_mode == "tier" else _expansion_workspace(instance)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(section)


func _tier_workspace(instance: DigimonInstance) -> Control:
	var dense := V2.physical_window_size(get_viewport()).y < 760.0 or WorkspaceChrome.is_compact(get_viewport())
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.PURPLE))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TIER ASCENSION", "Permanent individual progression", V2.PURPLE, "evolution")
	header.set_workspace_mode(true)
	stack.add_child(header)

	var inset := _margin(10, 6, 10, 8) if dense else _margin(12, 10, 12, 12)
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(inset)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6 if dense else 9)
	inset.add_child(body)

	var initial := OverworldState.get_tier_promotion_preview(instance.id)
	var next_tier := String(initial.get("target_tier", ""))
	if next_tier.is_empty():
		body.add_child(_info_card("MAXIMUM TIER", "This individual has reached Tier SSS.", V2.GREEN))
		return panel

	var compare := HBoxContainer.new()
	compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare.custom_minimum_size.y = 66.0 if dense else 82.0
	compare.add_theme_constant_override("separation", 12)
	body.add_child(compare)
	compare.add_child(_tier_compare_card("CURRENT", instance.tier, _tier_bonus_copy(instance.tier), V2.CYAN, dense))
	var arrow := TextureRect.new()
	arrow.name = "TierTransitionArrow"
	arrow.texture = CHANGE_ARROW_ICON
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.custom_minimum_size = Vector2(26.0, 26.0) if dense else Vector2(34.0, 34.0)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.modulate = V2.PURPLE
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compare.add_child(arrow)
	compare.add_child(_tier_compare_card("NEXT", next_tier, _tier_bonus_copy(next_tier), V2.PURPLE, dense))

	var requirements := HFlowContainer.new()
	requirements.add_theme_constant_override("h_separation", 8)
	requirements.add_theme_constant_override("v_separation", 6)
	body.add_child(requirements)
	requirements.add_child(_pill("%d BITS" % int(initial.get("bits_cost", 0)), V2.AMBER))
	requirements.add_child(_pill("%s+ FORM" % String(initial.get("minimum_rank", "Fresh")).to_upper(), V2.CYAN))
	var needs_donor := bool(initial.get("fusion_required", false))
	if needs_donor:
		requirements.add_child(_pill("SAME-SPECIES DONOR", V2.PURPLE))

	var action_grid := GridContainer.new()
	action_grid.columns = 2 if _detail_panel != null and _detail_panel.size.x >= 620.0 else 1
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 9)
	action_grid.add_theme_constant_override("v_separation", 9)
	body.add_child(action_grid)

	if needs_donor:
		var donor_name := "NONE SELECTED"
		if not _pending_donor_id.is_empty():
			var donor := OverworldState.get_instance_by_id(_pending_donor_id)
			if donor != null:
				var donor_species := _database.get_by_seed(donor.species_seed)
				donor_name = donor.get_display_name(String(donor_species.get("name", "Digimon")))
		var donor_button := _command_button(
			"SELECT DONOR",
			"Choose the exact Storage individual that will be consumed",
			donor_name.to_upper(),
			"party",
			V2.PURPLE,
			true
		)
		donor_button.pressed.connect(_open_donor_picker.bind(instance.id))
		action_grid.add_child(donor_button)

	var preview := OverworldState.get_tier_promotion_preview(instance.id, _pending_donor_id)
	var ready := bool(preview.get("success", false))
	var reason := "READY" if ready else _reason_text(String(preview.get("reason", "invalid"))).to_upper()
	var promote := _command_button(
		"ASCEND TO TIER %s" % next_tier,
		"Permanently raise this individual's Tier",
		reason,
		"evolution",
		V2.PURPLE,
		ready
	)
	promote.pressed.connect(_request_promotion)
	action_grid.add_child(promote)
	return panel


func _expansion_workspace(instance: DigimonInstance) -> Control:
	var dense := V2.physical_window_size(get_viewport()).y < 760.0 or WorkspaceChrome.is_compact(get_viewport())
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.ORANGE))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("EXPANSION", "Permanent tactical footprint configuration", V2.ORANGE, "move")
	header.set_workspace_mode(true)
	stack.add_child(header)

	var inset := _margin(10, 6, 10, 8) if dense else _margin(12, 10, 12, 12)
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(inset)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6 if dense else 9)
	inset.add_child(body)

	var footprint := PanelContainer.new()
	footprint.custom_minimum_size.y = 64.0 if dense else 82.0
	footprint.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.ORANGE.r, V2.ORANGE.g, V2.ORANGE.b, 0.06), Color(V2.ORANGE.r, V2.ORANGE.g, V2.ORANGE.b, 0.35), 8))
	var fm := _margin(10, 6, 10, 6) if dense else _margin(14, 10, 14, 10)
	footprint.add_child(fm)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 14)
	fm.add_child(fr)
	var footprint_value := _single_line_label("2×2" if instance.is_expanded() else "1×1", 23 if dense else 28, V2.ORANGE, true)
	footprint_value.custom_minimum_size.x = 90
	fr.add_child(footprint_value)
	var footprint_copy := VBoxContainer.new()
	footprint_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(footprint_copy)
	footprint_copy.add_child(_single_line_label("CURRENT FOOTPRINT", 10 if dense else 11, V2.TEXT, true))
	footprint_copy.add_child(_label("+20% max HP and normal forced-movement immunity while 2×2 is active.", 9 if dense else 10, V2.MUTED))
	body.add_child(footprint)

	var required_tier := _balance.expansion_string("requiredTier", "S")
	var core_id := _balance.expansion_string("coreItemId", "expansion_core")
	var fragment_id := _balance.expansion_string("fragmentItemId", "expansion_fragment")
	var core_count := OverworldState.get_item_count(core_id)
	var fragment_count := OverworldState.get_item_count(fragment_id)
	var tier_ready := _balance.tier_index(instance.tier) >= _balance.tier_index(required_tier)

	var reqs := HFlowContainer.new()
	reqs.add_theme_constant_override("h_separation", 8)
	reqs.add_theme_constant_override("v_separation", 6)
	body.add_child(reqs)
	reqs.add_child(_pill("TIER %s · %s" % [required_tier, "READY" if tier_ready else "REQUIRED"], V2.GREEN if tier_ready else V2.MUTED))
	reqs.add_child(_pill("CORES · %d" % core_count, V2.ORANGE))
	reqs.add_child(_pill("FRAGMENTS · %d" % fragment_count, V2.CYAN))

	var action_grid := GridContainer.new()
	action_grid.columns = 2 if _detail_panel != null and _detail_panel.size.x >= 620.0 else 1
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 9)
	action_grid.add_theme_constant_override("v_separation", 9)
	body.add_child(action_grid)

	if not instance.expansion_unlocked:
		var unlock := _command_button(
			"UNLOCK EXPANSION",
			"Consume one Expansion Core for this individual",
			"READY" if tier_ready and core_count >= 1 else "TIER %s + 1 CORE REQUIRED" % required_tier,
			"move",
			V2.ORANGE,
			tier_ready and core_count >= 1
		)
		unlock.pressed.connect(_unlock_expansion)
		action_grid.add_child(unlock)
	else:
		var toggle := _command_button(
			"SWITCH TO %s" % ("1×1" if instance.is_expanded() else "2×2"),
			"Switch freely outside combat after permanent unlock",
			"UNLOCKED",
			"move",
			V2.ORANGE,
			true
		)
		toggle.pressed.connect(_toggle_expansion.bind(not instance.is_expanded()))
		action_grid.add_child(toggle)

	var can_craft := fragment_count >= 5 and OverworldState.get_bits() >= 50000
	var craft := _command_button(
		"CRAFT EXPANSION CORE",
		"5 Fragments + 50,000 Bits",
		"READY" if can_craft else "%d / 5 FRAGMENTS · %d BITS" % [fragment_count, OverworldState.get_bits()],
		"database",
		V2.CYAN,
		can_craft
	)
	craft.pressed.connect(_craft_core)
	action_grid.add_child(craft)
	return panel


func _tier_compare_card(caption: String, tier_name: String, bonus: String, accent: Color, dense: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(accent.r, accent.g, accent.b, 0.06), Color(accent.r, accent.g, accent.b, 0.32), 8))
	var margin := _margin(9, 5, 9, 5) if dense else _margin(12, 8, 12, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var tier_icon := TierIconScript.new() as DigiTierIcon
	tier_icon.configure(tier_name, Vector2(32, 24) if dense else Vector2(38, 28))
	row.add_child(tier_icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.add_child(_single_line_label("%s · TIER %s" % [caption, tier_name], 11 if dense else 12, accent, true))
	copy.add_child(_single_line_label(bonus, 8 if dense else 9, V2.MUTED))
	return panel


func _command_button(title: String, subtitle: String, status: String, icon_kind: String, accent: Color, interactive: bool) -> DigiCommandButton:
	var button := CommandButtonScript.new() as DigiCommandButton
	button.configure(title, subtitle, status, icon_kind, accent)
	button.set_compact(true)
	button.custom_minimum_size.y = 54.0 if V2.physical_window_size(get_viewport()).y < 760.0 or WorkspaceChrome.is_compact(get_viewport()) else 62.0
	button.set_interactive(interactive)
	return button


func _open_donor_picker(target_id: String) -> void:
	var entries: Array[Dictionary] = []
	for donor: DigimonInstance in OverworldState.get_tier_donors(target_id):
		var species := _database.get_by_seed(donor.species_seed)
		entries.append({
			"id": donor.id,
			"title": donor.get_display_name(String(species.get("name", "Digimon"))),
			"subtitle": "Lv %d · Storage donor · permanently consumed" % donor.level,
			"species": String(species.get("name", "")),
			"accent": V2.PURPLE,
		})
	_donor_picker.configure("SELECT FUSION DONOR", "Only valid exact-species Storage donors are shown.", entries, V2.PURPLE)
	_donor_picker.open_picker(get_viewport().gui_get_focus_owner())


func _on_donor_picked(donor_id: String) -> void:
	_pending_donor_id = donor_id
	_status_text = "Fusion donor selected."
	_refresh_detail()
	_layout()
	call_deferred("_focus_first_detail_control")


func _set_section_mode(mode: String) -> void:
	if mode == _section_mode or not ["tier", "expansion"].has(mode):
		return
	_section_mode = mode
	if _section_segments != null:
		_section_segments.set_active(mode)
	_refresh_detail()
	_layout()
	call_deferred("_focus_first_detail_control")


func _toggle_section_mode() -> void:
	_set_section_mode("expansion" if _section_mode == "tier" else "tier")


func _section_tab_button(text: String, active: bool, accent: Color) -> Button:
	var button := _workspace_button(text, accent)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", V2.workspace_button_style(accent, "focus" if active else "normal"))
	button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
	return button


func _request_promotion(picker: OptionButton = null) -> void:
	var donor_id := _pending_donor_id
	if picker != null and picker.selected >= 0:
		donor_id = String(picker.get_item_metadata(picker.selected))
	var preview: Dictionary = OverworldState.get_tier_promotion_preview(_selected_id, donor_id)
	if not bool(preview.get("success", false)):
		_status_text = _reason_text(String(preview.get("reason", "invalid")))
		_refresh_detail()
		call_deferred("_wire_focus_navigation")
		return

	_pending_donor_id = donor_id
	var target: DigimonInstance = OverworldState.get_instance_by_id(_selected_id)
	var target_species: Dictionary = _database.get_by_seed(target.species_seed)
	var target_name := target.get_display_name(String(target_species.get("name", "Digimon")))
	var target_tier := String(preview.get("target_tier", ""))
	var copy := "Ascend %s to Tier %s for %d Bits?" % [
		target_name,
		target_tier,
		int(preview.get("bits_cost", 0)),
	]
	if bool(preview.get("fusion_required", false)):
		var donor: DigimonInstance = OverworldState.get_instance_by_id(donor_id)
		if donor != null:
			var donor_species: Dictionary = _database.get_by_seed(donor.species_seed)
			copy += "\n\nThis permanently consumes %s." % donor.get_display_name(String(donor_species.get("name", "Digimon")))
	_workspace_confirmation.configure(
		"ASCEND TO TIER %s?" % target_tier,
		copy,
		"ASCEND",
		"CANCEL",
		V2.PURPLE,
		"DIGI LAB · TIER ASCENSION"
	)
	_workspace_confirmation.open_dialog(get_viewport().gui_get_focus_owner())


func _confirm_promotion() -> void:
	var result: Dictionary = OverworldState.promote_digimon_tier(_selected_id, _pending_donor_id)
	_status_text = "Ascension complete." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_pending_donor_id = ""
	_refresh()


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
	if _section_segments != null:
		_section_segments.set_compact(compact)
	_hint_bar.set_secondary_tabs_enabled(not compact or _compact_detail_open)
	_hint_bar.set_secondary_tabs_label("Tier Ascension / Expansion")
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


func _set_workspace_headers(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is DigiSectionHeader:
			(child as DigiSectionHeader).set_workspace_mode(true)
		_set_workspace_headers(child)
