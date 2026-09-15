extends Control
class_name PartyStorageScreen

signal close_requested
signal tab_requested(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SemanticPalette = preload("res://src/ui/components/DigiSemanticPalette.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const StatsPanelScript = preload("res://src/ui/components/DigiStatsPanel.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

const DESKTOP_BREAKPOINT := 980.0

var _database: DigimonDatabase
var _progression: DigimonProgressionService
var _selected_id := ""

var _backdrop: ColorRect
var _frame: PanelContainer
var _root: Control
var _header: DigiModalHeader
var _header_rule: ColorRect
var _hint_bar: DigiInputHintBar
var _collection_panel: PanelContainer
var _collection_header: DigiSectionHeader
var _detail_panel: PanelContainer
var _detail_header: DigiSectionHeader
var _list_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _status_text := ""
var _list_buttons: Array[Button] = []
var _list_ids: Array[String] = []
var _list_previews: Array[DigimonWalkPreview] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_progression = ProgressionServiceScript.new(_database) as DigimonProgressionService
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.active_party_changed.connect(_on_party_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_screen() -> void:
	visible = true
	_header.set_active_tab("party")
	_header.set_bits(OverworldState.get_bits())
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not collection.is_empty():
		_selected_id = collection[0].id
	_status_text = ""
	_layout()
	_refresh()
	call_deferred("_layout")
	call_deferred("_focus_selected")
	_frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close_view() -> void:
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		close_view()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = V2.BACKDROP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "PartyStorageV2"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.BACKDROP, Color.TRANSPARENT, 0))
	add_child(_frame)

	_root = Control.new()
	_root.clip_contents = true
	_frame.add_child(_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "DigiLabHeader"
	_header.configure("DIGI", "Digital Monsters", OverworldState.get_bits(), true)
	_header.configure_tabs([
		{"id": "convert", "label": "Convert Digi Data", "icon": "database", "enabled": true, "min_width": 176.0},
		{"id": "party", "label": "Party / Storage", "icon": "party", "enabled": true, "min_width": 166.0},
	], "party")
	_header.close_requested.connect(close_view)
	_header.tab_selected.connect(_on_top_tab_selected)
	_root.add_child(_header)

	_header_rule = ColorRect.new()
	_header_rule.color = Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.62)
	_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_header_rule)

	_collection_panel = PanelContainer.new()
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.74), 8))
	_root.add_child(_collection_panel)
	var collection_stack := VBoxContainer.new()
	collection_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_stack.add_theme_constant_override("separation", 0)
	_collection_panel.add_child(collection_stack)
	_collection_header = SectionHeaderScript.new() as DigiSectionHeader
	_collection_header.configure("COLLECTION", "", V2.CYAN, "party")
	collection_stack.add_child(_collection_header)
	var collection_inset := _margin(10, 10, 5, 10)
	collection_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_stack.add_child(collection_inset)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.follow_focus = true
	_list_scroll.scroll_deadzone = 8
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_inset.add_child(_list_scroll)
	SmoothScrollScript.attach(_list_scroll)
	var list_inset := _margin(0, 0, 6, 0)
	list_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(list_inset)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	list_inset.add_child(_list)

	_detail_panel = PanelContainer.new()
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.74), 8))
	_root.add_child(_detail_panel)
	var detail_stack := VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", 0)
	_detail_panel.add_child(detail_stack)
	_detail_header = SectionHeaderScript.new() as DigiSectionHeader
	_detail_header.configure("PARTY / STORAGE", "Organize your active squad and reserves", V2.GREEN, "party")
	detail_stack.add_child(_detail_header)
	var detail_inset := _margin(12, 10, 7, 12)
	detail_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(detail_inset)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.scroll_deadzone = 8
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_inset.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)
	var detail_scroll_inset := _margin(0, 0, 5, 0)
	detail_scroll_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(detail_scroll_inset)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	detail_scroll_inset.add_child(_detail)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "InputHints"
	_hint_bar.set_description("Build your active party, reorder slots and manage reserve Digimon.")
	_root.add_child(_hint_bar)


func _on_top_tab_selected(tab_id: String) -> void:
	if tab_id == "convert":
		tab_requested.emit("convert")


func _refresh() -> void:
	_header.set_bits(OverworldState.get_bits())
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_collection_header.set_trailing("ACTIVE %d / %d  ·  STORAGE %d" % [active_ids.size(), OverworldState.get_max_active_party_size(), maxi(0, collection.size() - active_ids.size())])
	_refresh_list()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _refresh_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_list_buttons.clear()
	_list_ids.clear()
	_list_previews.clear()
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if collection.is_empty():
		_list.add_child(_empty_state("No Digimon available."))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = collection[0].id
	for instance: DigimonInstance in collection:
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var active := active_ids.has(instance.id)
		var button := _collection_button(instance, species, active, active_ids)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(instance.id)
	_style_list_selection()


func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool, active_ids: Array[String]) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := V2.rank_color(rank)
	var selected := instance.id == _selected_id
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_select.bind(instance.id))
	button.focus_entered.connect(_select.bind(instance.id))
	button.tooltip_text = "Select %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	_style_list_button(button, selected, rank_color)

	var margin := _margin(11, 8, 11, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(62, 62)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	row.add_child(preview)
	_list_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := instance.get_display_name(String(species.get("name", "Unknown")))
	var location := "PARTY SLOT %d" % (active_ids.find(instance.id) + 1) if active else "STORAGE"
	var location_color := V2.AMBER if active else V2.CYAN
	copy.add_child(_single_line_label(name, 15, V2.TEXT, true))
	copy.add_child(_single_line_label("Lv %d  ·  %s" % [instance.level, rank], 10, rank_color, true))
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	copy.add_child(meta_row)
	var location_label := _single_line_label(location, 9, location_color, true)
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(location_label)
	meta_row.add_child(_single_line_label("POT %d · LINK %d" % [instance.potential, instance.link], 9, V2.MUTED, true))
	return button


func _style_list_selection() -> void:
	var active_ids := OverworldState.get_active_party_ids()
	for index in range(_list_buttons.size()):
		var id := _list_ids[index] if index < _list_ids.size() else ""
		var instance := OverworldState.get_instance_by_id(id)
		var species := _database.get_by_seed(instance.species_seed) if instance != null else {}
		var accent := V2.rank_color(String(species.get("rank", "Unknown")))
		var selected := id == _selected_id
		_style_list_button(_list_buttons[index], selected, V2.AMBER if active_ids.has(id) else accent)
		if index < _list_previews.size():
			_list_previews[index].set_active(selected)


func _focus_selected() -> void:
	if not visible:
		return
	for index in range(_list_ids.size()):
		if _list_ids[index] == _selected_id and index < _list_buttons.size():
			_list_buttons[index].grab_focus()
			return
	if not _list_buttons.is_empty():
		_list_buttons[0].grab_focus()


func _select(instance_id: String) -> void:
	if instance_id.is_empty() or OverworldState.get_instance_by_id(instance_id) == null:
		return
	if _selected_id == instance_id:
		_style_list_selection()
		return
	_selected_id = instance_id
	_status_text = ""
	_style_list_selection()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
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

	_detail.add_child(_identity_card(instance, species, display_name, rank, accent, active, party_index))

	var lower_grid := GridContainer.new()
	lower_grid.columns = 2
	lower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_grid.add_theme_constant_override("h_separation", 10)
	lower_grid.add_theme_constant_override("v_separation", 10)
	_detail.add_child(lower_grid)

	var stats_panel := StatsPanelScript.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.configure(_progression.get_final_stats(instance), instance.current_hp, instance.current_mp)
	lower_grid.add_child(stats_panel)
	lower_grid.add_child(_party_actions_panel(instance, active_ids, party_index, active))


func _identity_card(instance: DigimonInstance, species: Dictionary, display_name: String, rank: String, accent: Color, active: bool, party_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(accent.r, accent.g, accent.b, 0.42), 8))
	var margin := _margin(16, 14, 16, 14)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(174, 166)
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(0.015, 0.030, 0.044, 1.0), Color(accent.r, accent.g, accent.b, 0.54), 8))
	row.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(158, 150)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 7)
	row.add_child(info)
	info.add_child(_label(display_name.to_upper(), 27, V2.TEXT, true))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 7)
	info.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	chips.add_child(_pill(attribute.to_upper(), SemanticPalette.data_attribute_color(attribute)))
	chips.add_child(_pill(family.to_upper(), SemanticPalette.family_color(family)))

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 14)
	info.add_child(status_row)
	status_row.add_child(_label("Lv %d" % instance.level, 19, V2.AMBER, true))
	status_row.add_child(_label("POTENTIAL %d" % instance.potential, 10, V2.PURPLE, true))
	status_row.add_child(_label("LINK %d / %d" % [instance.link, DigimonInstance.MAX_LINK], 10, V2.CYAN, true))
	var location := "ACTIVE PARTY · SLOT %d" % (party_index + 1) if active else "STORAGE"
	info.add_child(_pill(location, V2.AMBER if active else V2.CYAN))
	var id_label := _label("ID %s" % instance.id.substr(0, mini(8, instance.id.length())), 9, V2.SUBTLE)
	info.add_child(id_label)
	return panel


func _party_actions_panel(instance: DigimonInstance, active_ids: Array[String], party_index: int, active: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.30), 8))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("PARTY ACTIONS", _status_text, V2.AMBER, "party")
	stack.add_child(header)
	var inset := _margin(12, 10, 12, 12)
	stack.add_child(inset)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	inset.add_child(actions)

	if active:
		var remove := _button("MOVE TO STORAGE", V2.ORANGE)
		remove.custom_minimum_size.y = 48
		remove.disabled = active_ids.size() <= 1
		remove.tooltip_text = "At least one Digimon must remain active." if remove.disabled else "Move this Digimon to Storage."
		remove.pressed.connect(_remove_from_party.bind(instance.id))
		actions.add_child(remove)
		var order := HBoxContainer.new()
		order.add_theme_constant_override("separation", 8)
		actions.add_child(order)
		var up := _button("MOVE UP", V2.CYAN)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.custom_minimum_size.y = 44
		up.disabled = party_index <= 0
		up.pressed.connect(_move.bind(instance.id, party_index - 1))
		order.add_child(up)
		var down := _button("MOVE DOWN", V2.CYAN)
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		down.custom_minimum_size.y = 44
		down.disabled = party_index >= active_ids.size() - 1
		down.pressed.connect(_move.bind(instance.id, party_index + 1))
		order.add_child(down)
	else:
		var add := _button("ADD TO PARTY", V2.GREEN)
		add.custom_minimum_size.y = 48
		add.disabled = active_ids.size() >= OverworldState.get_max_active_party_size()
		add.tooltip_text = "Party is full. Choose a slot to swap." if add.disabled else "Add this Digimon to the active party."
		add.pressed.connect(_add_to_party.bind(instance.id))
		actions.add_child(add)
		if add.disabled:
			actions.add_child(_label("PARTY FULL · CHOOSE A SLOT TO REPLACE", 9, V2.MUTED, true))
			for active_id: String in active_ids:
				var active_instance: DigimonInstance = OverworldState.get_instance_by_id(active_id)
				if active_instance == null:
					continue
				var active_species := _database.get_by_seed(active_instance.species_seed)
				var active_name := active_instance.get_display_name(String(active_species.get("name", "Digimon")))
				var slot := active_ids.find(active_id) + 1
				var swap := _button("REPLACE SLOT %d · %s" % [slot, active_name.to_upper()], V2.PURPLE)
				swap.custom_minimum_size.y = 40
				swap.pressed.connect(_swap.bind(active_id, instance.id))
				actions.add_child(swap)
	return panel


func _add_to_party(instance_id: String) -> void:
	var ok := OverworldState.add_to_active_party(instance_id)
	_status_text = "Added to active party" if ok else "Could not add this Digimon"
	_refresh()
	call_deferred("_focus_selected")


func _remove_from_party(instance_id: String) -> void:
	var ok := OverworldState.remove_from_active_party(instance_id)
	_status_text = "Moved to Storage" if ok else "At least one Digimon must remain active"
	_refresh()
	call_deferred("_focus_selected")


func _swap(active_id: String, reserve_id: String) -> void:
	var ok := OverworldState.swap_party_with_reserve(active_id, reserve_id)
	_status_text = "Party slot updated" if ok else "Could not swap these Digimon"
	_refresh()
	call_deferred("_focus_selected")


func _move(instance_id: String, new_index: int) -> void:
	var ok := OverworldState.move_active_party_member(instance_id, new_index)
	_status_text = "Party order updated" if ok else "Could not change party order"
	_refresh()
	call_deferred("_focus_selected")


func _on_state_changed() -> void:
	if visible:
		_refresh()


func _on_party_changed(_party: Array) -> void:
	if visible:
		_refresh()


func _wire_focus_navigation() -> void:
	if _list_buttons.is_empty():
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
	var active_tab := _header.get_tab_button("party")
	if active_tab != null:
		active_tab.focus_neighbor_bottom = active_tab.get_path_to(selected)
		selected.focus_neighbor_top = selected.get_path_to(active_tab)


func _focusable_descendants(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
				result.append(control)
		result.append_array(_focusable_descendants(child))
	return result


func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := V2.is_compact(get_viewport(), DESKTOP_BREAKPOINT)
	var width := maxf(320.0, physical.x)
	var height := maxf(300.0, physical.y)
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(width, height)
	_root.position = Vector2.ZERO
	_root.size = Vector2(width, height)

	var header_h := 60.0
	var footer_h := 76.0 if not compact else 58.0
	var top_gap := 18.0 if not compact else 10.0
	var bottom_gap := 18.0 if not compact else 10.0
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_header_rule.position = Vector2(0.0, header_h - 1.0)
	_header_rule.size = Vector2(width, 1.0)
	_hint_bar.position = Vector2(0.0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)

	var body_top := header_h + top_gap
	var body_bottom := height - footer_h - bottom_gap
	var body_h := maxf(120.0, body_bottom - body_top)
	if compact:
		var edge := 10.0
		var list_h := clampf(body_h * 0.32, 145.0, 220.0)
		_collection_panel.position = Vector2(edge, body_top)
		_collection_panel.size = Vector2(width - edge * 2.0, list_h)
		_detail_panel.position = Vector2(edge, body_top + list_h + 10.0)
		_detail_panel.size = Vector2(width - edge * 2.0, maxf(100.0, body_h - list_h - 10.0))
	else:
		var edge := 22.0
		var gap := 12.0
		var collection_w := clampf(width * 0.34, 330.0, 520.0)
		_collection_panel.position = Vector2(edge, body_top)
		_collection_panel.size = Vector2(collection_w, body_h)
		_detail_panel.position = Vector2(edge + collection_w + gap, body_top)
		_detail_panel.size = Vector2(width - edge * 2.0 - collection_w - gap, body_h)


func _style_list_button(button: Button, selected: bool, accent: Color) -> void:
	if selected:
		var style := V2.surface_style(Color(0.055, 0.145, 0.180, 0.985), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.96), 7)
		style.set_border_width_all(2)
		style.shadow_color = Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.15)
		style.shadow_size = 6
		button.add_theme_stylebox_override("normal", style)
	else:
		button.add_theme_stylebox_override("normal", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.76), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.58), 7))
	button.add_theme_stylebox_override("hover", V2.button_style(V2.CYAN, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_color_override("font_color", V2.TEXT)


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 7))
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.45))
	V2.apply_heading(button)
	return button


func _pill(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label


func _empty_state(text: String) -> Label:
	var label := _label(text, 12, V2.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = 120
	return label


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


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
