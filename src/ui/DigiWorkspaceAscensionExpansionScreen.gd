extends "res://src/ui/DigiIconAscensionExpansionScreen.gd"
class_name DigiWorkspaceAscensionExpansionScreen

const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const WorkspaceBackdrop = preload("res://src/ui/components/DigiLabWorkspaceBackdrop.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const ConfirmationScript = preload("res://src/ui/components/DigiConfirmationModal.gd")

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
	_workspace_pager = PagerScript.new() as DigiPager
	_workspace_pager.name = "AscensionCollectionPager"
	_workspace_pager.set_workspace_mode(true)
	_workspace_pager.page_delta_requested.connect(_turn_workspace_page)
	collection_stack.add_child(_workspace_pager)

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

	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 4, 3, 2)
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
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 4, 3, 2)
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

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var identity := _identity_card(instance, species, display_name, rank, accent)
	identity.add_theme_stylebox_override("panel", V2.workspace_panel_style(accent))
	_detail.add_child(identity)
	if not _status_text.is_empty():
		_detail.add_child(_status_banner(_status_text))

	_section_tabs = HBoxContainer.new()
	_section_tabs.name = "AscensionSectionTabs"
	_section_tabs.add_theme_constant_override("separation", 8)
	_detail.add_child(_section_tabs)
	_tier_tab_button = _section_tab_button("TIER ASCENSION", _section_mode == "tier", V2.PURPLE)
	_tier_tab_button.pressed.connect(_set_section_mode.bind("tier"))
	_section_tabs.add_child(_tier_tab_button)
	_expansion_tab_button = _section_tab_button("EXPANSION", _section_mode == "expansion", V2.ORANGE)
	_expansion_tab_button.pressed.connect(_set_section_mode.bind("expansion"))
	_section_tabs.add_child(_expansion_tab_button)

	var section := _tier_panel(instance) if _section_mode == "tier" else _expansion_panel(instance)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(section)
	_set_workspace_headers(section)


func _set_section_mode(mode: String) -> void:
	if mode == _section_mode or not ["tier", "expansion"].has(mode):
		return
	_section_mode = mode
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
