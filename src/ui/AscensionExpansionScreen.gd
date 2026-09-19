extends Control
class_name AscensionExpansionScreen

signal close_requested
signal tab_requested(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SemanticPalette = preload("res://src/ui/components/DigiSemanticPalette.gd")
const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const TransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

const DESKTOP_BREAKPOINT := 980.0

var _database: DigimonDatabase
var _balance = BalanceScript.new()
var _selected_id := ""
var _pending_donor_id := ""
var _status_text := ""

var _backdrop: ColorRect
var _frame: PanelContainer
var _root: Control
var _transition_surface: DigiUiTransitionSurface = null
var _close_lifecycle_managed := false
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
var _confirmation: ConfirmationDialog
var _list_buttons: Array[Button] = []
var _list_ids: Array[String] = []
var _list_previews: Array[DigimonWalkPreview] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.collection_changed.connect(_on_collection_changed)
	OverworldState.inventory_changed.connect(_on_inventory_changed)
	OverworldState.account_rewards_changed.connect(_on_account_rewards_changed)
	OverworldState.active_party_changed.connect(_on_active_party_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func get_transition_surface() -> DigiUiTransitionSurface:
	return _transition_surface


func set_close_lifecycle_managed(value: bool) -> void:
	_close_lifecycle_managed = value


func open_screen(preferred_instance_id: String = "") -> void:
	visible = true
	_header.configure_tabs(PrimaryTabs.specs(), "ascension")
	_header.set_active_tab("ascension")
	_header.set_bits(OverworldState.get_bits())
	_hint_bar.set_primary_tabs_enabled(true)
	if not preferred_instance_id.is_empty() and OverworldState.get_instance_by_id(preferred_instance_id) != null:
		_selected_id = preferred_instance_id
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not collection.is_empty():
		_selected_id = collection[0].id
	_pending_donor_id = ""
	_status_text = ""
	_layout()
	_refresh()
	if _detail_scroll != null:
		_detail_scroll.scroll_vertical = 0
	call_deferred("_layout")
	call_deferred("_focus_selected")
	# The parent DigiLab service owns the full-screen digital transition.
	# Sub-workspaces stay opaque so changing tabs never replays a competing fade.
	_frame.modulate.a = 1.0


func _request_close() -> void:
	if _close_lifecycle_managed:
		close_requested.emit()
	else:
		close_view()


func close_view() -> void:
	# Immediate/programmatic close remains available for tests and tools. Normal
	# player input requests a close so the parent service can animate first.
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func get_selected_instance_id() -> String:
	return _selected_id


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		_request_close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_transition_surface = TransitionSurfaceScript.new() as DigiUiTransitionSurface
	_transition_surface.name = "WorkspaceTransition"
	add_child(_transition_surface)

	_backdrop = ColorRect.new()
	_backdrop.color = V2.BACKDROP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_transition_surface.add_transition_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "AscensionExpansionV2"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.BACKDROP, Color.TRANSPARENT, 0))
	_transition_surface.add_transition_child(_frame)

	_root = Control.new()
	_root.clip_contents = true
	_frame.add_child(_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "DigiLabHeader"
	_header.configure("DIGI", "Digital Monsters", OverworldState.get_bits(), true)
	_header.configure_tabs(PrimaryTabs.specs(), "ascension")
	_header.close_requested.connect(_request_close)
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
	_collection_header.configure("INDIVIDUALS", "", V2.PURPLE, "evolution")
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
	_detail_header.configure("ASCENSION / EXPANSION", "Raise Tier and configure tactical size", V2.PURPLE, "evolution")
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
	_hint_bar.set_description("Raise an individual Tier, assimilate duplicate knowledge and configure tactical size.")
	_hint_bar.set_primary_tabs_enabled(true)
	_root.add_child(_hint_bar)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm Tier Ascension"
	_confirmation.ok_button_text = "ASCEND"
	_confirmation.dialog_text = ""
	_confirmation.confirmed.connect(_confirm_promotion)
	add_child(_confirmation)
	_style_confirmation_dialog()


func _on_top_tab_selected(tab_id: String) -> void:
	if tab_id != "ascension":
		tab_requested.emit(tab_id)


func _refresh() -> void:
	if not is_node_ready():
		return
	_header.set_bits(OverworldState.get_bits())
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_collection_header.set_trailing("%d OWNED" % collection.size())
	_refresh_list()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _clear_children_now(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_list() -> void:
	_clear_children_now(_list)
	_list_buttons.clear()
	_list_ids.clear()
	_list_previews.clear()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if collection.is_empty():
		_list.add_child(_empty_state("No Digimon available."))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = collection[0].id
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	for instance: DigimonInstance in collection:
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var button := _collection_button(instance, species, active_ids)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(instance.id)
	_style_list_selection()


func _collection_button(instance: DigimonInstance, species: Dictionary, active_ids: Array[String]) -> Button:
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
	var footprint := "2×2" if instance.is_expanded() else "1×1"
	var active_index := active_ids.find(instance.id)
	var location := "PARTY SLOT %d" % (active_index + 1) if active_index >= 0 else "STORAGE"
	copy.add_child(_single_line_label(name, 15, V2.TEXT, true))
	copy.add_child(_single_line_label("Lv %d  ·  %s" % [instance.level, rank], 10, rank_color, true))
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	copy.add_child(meta_row)
	var progression := _single_line_label("TIER %s · %s · POT %d" % [instance.tier, footprint, instance.potential], 9, V2.PURPLE, true)
	progression.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(progression)
	meta_row.add_child(_single_line_label(location, 9, V2.AMBER if active_index >= 0 else V2.CYAN, true))
	return button


func _style_list_selection() -> void:
	for index in range(_list_buttons.size()):
		var id := _list_ids[index] if index < _list_ids.size() else ""
		var instance := OverworldState.get_instance_by_id(id)
		var species := _database.get_by_seed(instance.species_seed) if instance != null else {}
		var accent := V2.rank_color(String(species.get("rank", "Unknown")))
		var selected := id == _selected_id
		_style_list_button(_list_buttons[index], selected, accent)
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
	_pending_donor_id = ""
	_status_text = ""
	_style_list_selection()
	_refresh_detail()
	if _detail_scroll != null:
		_detail_scroll.scroll_vertical = 0
	call_deferred("_wire_focus_navigation")


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
	_detail.add_child(_identity_card(instance, species, display_name, rank, accent))
	if not _status_text.is_empty():
		_detail.add_child(_status_banner(_status_text))

	var lower_grid := GridContainer.new()
	lower_grid.columns = 1 if _detail_panel.size.x < 760.0 else 2
	lower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower_grid.add_theme_constant_override("h_separation", 10)
	lower_grid.add_theme_constant_override("v_separation", 10)
	_detail.add_child(lower_grid)
	lower_grid.add_child(_tier_panel(instance))
	lower_grid.add_child(_expansion_panel(instance))


func _identity_card(instance: DigimonInstance, species: Dictionary, display_name: String, rank: String, accent: Color) -> Control:
	var narrow := _detail_panel != null and _detail_panel.size.x < 660.0
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(accent.r, accent.g, accent.b, 0.42), 8))
	var margin := _margin(16, 14, 16, 14)
	panel.add_child(margin)
	var row: BoxContainer
	if narrow:
		row = VBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(158, 150) if narrow else Vector2(174, 166)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if narrow else Control.SIZE_SHRINK_BEGIN
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(0.015, 0.030, 0.044, 1.0), Color(accent.r, accent.g, accent.b, 0.54), 8))
	row.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(142, 134) if narrow else Vector2(158, 150)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 7)
	row.add_child(info)
	var name_label := _single_line_label(display_name.to_upper(), 27, V2.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_label)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 6)
	info.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	chips.add_child(_pill(attribute.to_upper(), SemanticPalette.data_attribute_color(attribute)))
	chips.add_child(_pill(family.to_upper(), SemanticPalette.family_color(family)))

	var status_row := HFlowContainer.new()
	status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_theme_constant_override("h_separation", 14)
	status_row.add_theme_constant_override("v_separation", 5)
	info.add_child(status_row)
	var footprint := "2×2" if instance.is_expanded() else "1×1"
	status_row.add_child(_semantic_label("Lv %d" % instance.level, 19, V2.AMBER, true))
	status_row.add_child(_semantic_label("TIER %s" % instance.tier, 10, V2.PURPLE, true))
	status_row.add_child(_semantic_label(footprint, 10, V2.ORANGE, true))
	status_row.add_child(_semantic_label("POTENTIAL %d" % instance.potential, 10, V2.PURPLE, true))
	status_row.add_child(_semantic_label("LINK %d / %d" % [instance.link, DigimonInstance.MAX_LINK], 10, V2.CYAN, true))

	var resources := HFlowContainer.new()
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.add_theme_constant_override("h_separation", 7)
	resources.add_theme_constant_override("v_separation", 5)
	info.add_child(resources)
	resources.add_child(_pill("%d BITS" % OverworldState.get_bits(), V2.AMBER))
	resources.add_child(_pill("%d CORES" % OverworldState.get_item_count(_balance.expansion_string("coreItemId", "expansion_core")), V2.ORANGE))
	resources.add_child(_pill("%d FRAGMENTS" % OverworldState.get_item_count(_balance.expansion_string("fragmentItemId", "expansion_fragment")), V2.CYAN))
	return panel


func _tier_panel(instance: DigimonInstance) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.PURPLE.r, V2.PURPLE.g, V2.PURPLE.b, 0.32), 8))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TIER ASCENSION", "Permanent individual progression", V2.PURPLE, "evolution")
	stack.add_child(header)
	var inset := _margin(12, 10, 12, 12)
	stack.add_child(inset)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	inset.add_child(body)

	var current_row := HFlowContainer.new()
	current_row.add_theme_constant_override("h_separation", 8)
	current_row.add_theme_constant_override("v_separation", 6)
	body.add_child(current_row)
	current_row.add_child(_pill("CURRENT · TIER %s" % instance.tier, V2.PURPLE))
	current_row.add_child(_semantic_label(_tier_bonus_copy(instance.tier), 9, V2.MUTED, false))

	var initial_preview: Dictionary = OverworldState.get_tier_promotion_preview(instance.id)
	var next_tier := String(initial_preview.get("target_tier", ""))
	if next_tier.is_empty():
		body.add_child(_info_card("MAXIMUM TIER", "This individual has reached Tier SSS.", V2.GREEN))
		return panel

	var requirement_copy := "%d BITS · %s+" % [int(initial_preview.get("bits_cost", 0)), String(initial_preview.get("minimum_rank", "Fresh"))]
	if bool(initial_preview.get("fusion_required", false)):
		requirement_copy += " · SAME-SPECIES DONOR"
	body.add_child(_info_card("NEXT · TIER %s" % next_tier, requirement_copy, V2.PURPLE))
	body.add_child(_single_line_label("NEXT BONUS · %s" % _tier_bonus_copy(next_tier), 9, V2.PURPLE.lightened(0.18), true))

	var donor_picker: OptionButton = null
	if bool(initial_preview.get("fusion_required", false)):
		body.add_child(_single_line_label("FUSION DONOR", 9, V2.MUTED, true))
		donor_picker = OptionButton.new()
		donor_picker.name = "DonorPicker"
		donor_picker.custom_minimum_size = Vector2(0, 44)
		donor_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		donor_picker.focus_mode = Control.FOCUS_ALL
		donor_picker.add_item("Select exact-species donor")
		donor_picker.set_item_metadata(0, "")
		var selected_index := 0
		for donor: DigimonInstance in OverworldState.get_tier_donors(instance.id):
			var donor_species := _database.get_by_seed(donor.species_seed)
			var donor_name := donor.get_display_name(String(donor_species.get("name", "Unknown")))
			donor_picker.add_item("%s · Lv %d · %s" % [donor_name, donor.level, donor.id.substr(0, mini(8, donor.id.length()))])
			donor_picker.set_item_metadata(donor_picker.item_count - 1, donor.id)
			if donor.id == _pending_donor_id:
				selected_index = donor_picker.item_count - 1
		donor_picker.select(selected_index)
		donor_picker.item_selected.connect(_on_donor_selected.bind(donor_picker))
		_style_option_button(donor_picker, V2.PURPLE)
		body.add_child(donor_picker)

	var promote := _button("ASCEND TO TIER %s" % next_tier, V2.PURPLE)
	promote.name = "PromoteButton"
	promote.custom_minimum_size.y = 48
	promote.tooltip_text = "Review requirements and permanently raise this individual's Tier."
	promote.pressed.connect(_request_promotion.bind(donor_picker))
	body.add_child(promote)
	return panel


func _expansion_panel(instance: DigimonInstance) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.ORANGE.r, V2.ORANGE.g, V2.ORANGE.b, 0.32), 8))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("EXPANSION", "Tactical footprint configuration", V2.ORANGE, "move")
	stack.add_child(header)
	var inset := _margin(12, 10, 12, 12)
	stack.add_child(inset)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	inset.add_child(body)

	var state_row := HFlowContainer.new()
	state_row.add_theme_constant_override("h_separation", 8)
	state_row.add_theme_constant_override("v_separation", 6)
	body.add_child(state_row)
	state_row.add_child(_pill("CURRENT · %s" % ("2×2" if instance.is_expanded() else "1×1"), V2.ORANGE))
	state_row.add_child(_pill("UNLOCKED" if instance.expansion_unlocked else "LOCKED", V2.GREEN if instance.expansion_unlocked else V2.MUTED))

	var required_tier := _balance.expansion_string("requiredTier", "S")
	var core_id := _balance.expansion_string("coreItemId", "expansion_core")
	var fragment_id := _balance.expansion_string("fragmentItemId", "expansion_fragment")
	var core_count := OverworldState.get_item_count(core_id)
	var fragment_count := OverworldState.get_item_count(fragment_id)
	var tier_ready := _balance.tier_index(instance.tier) >= _balance.tier_index(required_tier)

	if not instance.expansion_unlocked:
		body.add_child(_info_card("PERMANENT UNLOCK", "Requires Tier %s and 1 Expansion Core." % required_tier, V2.ORANGE))
		var requirements := HFlowContainer.new()
		requirements.add_theme_constant_override("h_separation", 8)
		requirements.add_theme_constant_override("v_separation", 6)
		body.add_child(requirements)
		requirements.add_child(_pill("TIER %s %s" % [required_tier, "READY" if tier_ready else "REQUIRED"], V2.GREEN if tier_ready else V2.MUTED))
		requirements.add_child(_pill("CORE %d / 1" % core_count, V2.GREEN if core_count >= 1 else V2.MUTED))
		var unlock := _button("USE EXPANSION CORE", V2.ORANGE)
		unlock.custom_minimum_size.y = 48
		unlock.disabled = not tier_ready or core_count < 1
		unlock.tooltip_text = "Unlock Expansion permanently for this individual." if not unlock.disabled else "Tier %s and one Expansion Core are required." % required_tier
		unlock.pressed.connect(_unlock_expansion)
		body.add_child(unlock)
	else:
		body.add_child(_label("2×2 grants +20% max HP and ignores normal forced movement. Damage, defense, SP, SPD and MOV are unchanged.", 10, V2.MUTED))
		var toggle := _button("SWITCH TO %s" % ("1×1" if instance.is_expanded() else "2×2"), V2.ORANGE)
		toggle.custom_minimum_size.y = 48
		toggle.pressed.connect(_toggle_expansion.bind(not instance.is_expanded()))
		body.add_child(toggle)

	body.add_child(_subsection("CORE CRAFTING", "Permanent resource", V2.CYAN))
	body.add_child(_single_line_label("5 FRAGMENTS + 50,000 BITS · YOU HAVE %d FRAGMENTS" % fragment_count, 9, V2.MUTED, true))
	var craft := _button("CRAFT EXPANSION CORE", V2.CYAN)
	craft.custom_minimum_size.y = 44
	craft.disabled = fragment_count < 5 or OverworldState.get_bits() < 50000
	craft.tooltip_text = "Craft one Expansion Core." if not craft.disabled else "Requires 5 Expansion Fragments and 50,000 Bits."
	craft.pressed.connect(_craft_core)
	body.add_child(craft)
	return panel


func _status_banner(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.07), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.30), 7))
	var margin := _margin(12, 8, 12, 8)
	panel.add_child(margin)
	var label := _label(text, 10, V2.CYAN, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(label)
	return panel


func _info_card(title: String, body_text: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(accent.r, accent.g, accent.b, 0.065), Color(accent.r, accent.g, accent.b, 0.24), 7))
	var margin := _margin(11, 8, 11, 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	stack.add_child(_single_line_label(title, 11, accent, true))
	var body := _label(body_text, 9, V2.MUTED)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	return panel


func _subsection(title: String, subtitle: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", V2.header_strip_style(6))
	var margin := _margin(10, 6, 10, 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var title_label := _semantic_label(title, 10, accent, true)
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(title_label)
	var subtitle_label := _single_line_label(subtitle, 9, V2.SUBTLE)
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(subtitle_label)
	return panel


func _tier_bonus_copy(tier: String) -> String:
	var primary := _balance.tier_stat_multiplier(tier, "hp")
	var secondary := _balance.tier_stat_multiplier(tier, "speed")
	return "HP/ATK/DEF/INT ×%.3f · SP/SPD ×%.3f · MOV unchanged" % [primary, secondary]


func _on_donor_selected(index: int, picker: OptionButton) -> void:
	_pending_donor_id = String(picker.get_item_metadata(index))


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
	var copy := "Ascend %s to Tier %s for %d Bits?" % [
		target.get_display_name(String(target_species.get("name", "Digimon"))),
		String(preview.get("target_tier", "")),
		int(preview.get("bits_cost", 0)),
	]
	if bool(preview.get("fusion_required", false)):
		var donor: DigimonInstance = OverworldState.get_instance_by_id(donor_id)
		if donor != null:
			var donor_species: Dictionary = _database.get_by_seed(donor.species_seed)
			copy += "\n\nThis permanently consumes %s (%s)." % [donor.get_display_name(String(donor_species.get("name", "Digimon"))), donor.id]
	_confirmation.dialog_text = copy
	_confirmation.popup_centered(Vector2i(540, 250))
	call_deferred("_focus_confirmation_cancel")


func _confirm_promotion() -> void:
	var result: Dictionary = OverworldState.promote_digimon_tier(_selected_id, _pending_donor_id)
	_status_text = "Ascension complete: Tier %s." % String(result.get("new_tier", "")) if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_pending_donor_id = ""
	_refresh()


func _unlock_expansion() -> void:
	var result: Dictionary = OverworldState.unlock_digimon_expansion(_selected_id)
	_status_text = "Expansion permanently unlocked." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _toggle_expansion(expanded: bool) -> void:
	var result: Dictionary = OverworldState.set_digimon_expanded(_selected_id, expanded)
	_status_text = "Battle size changed to %s." % ("2×2" if expanded else "1×1") if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _craft_core() -> void:
	var result: Dictionary = OverworldState.craft_expansion_core()
	_status_text = "Expansion Core crafted." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _reason_text(reason: String) -> String:
	var reasons := {
		"maximum_tier": "This individual is already Tier SSS.",
		"rank_too_low": "The current species rank does not meet this Tier requirement.",
		"insufficient_bits": "Not enough Bits.",
		"donor_required": "Select the exact individual that will be consumed.",
		"donor_in_active_party": "The donor must be in Storage.",
		"donor_not_in_storage": "Reserve belongs to the Squad. Move the donor to Storage first.",
		"donor_species_mismatch": "The donor must be the same current species.",
		"donor_has_equipment": "Remove all donor equipment first.",
		"tier_too_low": "Tier S is required to unlock Expansion.",
		"core_required": "An Expansion Core is required.",
		"insufficient_fragments": "Five Expansion Fragments are required.",
		"expansion_locked": "Unlock Expansion for this individual first.",
	}
	return String(reasons.get(reason, "The operation could not be completed (%s)." % reason))


func _on_collection_changed() -> void:
	if visible:
		_refresh()


func _on_inventory_changed(_inventory: Dictionary) -> void:
	if visible:
		_refresh()


func _on_account_rewards_changed(_bits: int, _data: Dictionary) -> void:
	if visible:
		_refresh()


func _on_active_party_changed(_party: Array) -> void:
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
	var active_tab := _header.get_tab_button("ascension")
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


func _focus_confirmation_cancel() -> void:
	if _confirmation != null and _confirmation.visible:
		var cancel := _confirmation.get_cancel_button()
		if cancel != null:
			cancel.grab_focus()


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


func _style_confirmation_dialog() -> void:
	if _confirmation == null:
		return
	_confirmation.add_theme_color_override("font_color", V2.TEXT)
	var ok := _confirmation.get_ok_button()
	if ok != null:
		_apply_existing_button_style(ok, V2.PURPLE)
	var cancel := _confirmation.get_cancel_button()
	if cancel != null:
		cancel.text = "CANCEL"
		_apply_existing_button_style(cancel, V2.CYAN)


func _style_option_button(button: OptionButton, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	V2.apply_body(button)


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
	_apply_existing_button_style(button, accent)
	return button


func _apply_existing_button_style(button: Button, accent: Color) -> void:
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


func _pill(text: String, accent: Color) -> Label:
	var label := _semantic_label(text, 9, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


func _semantic_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _single_line_label(text, size, color, bold)
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
