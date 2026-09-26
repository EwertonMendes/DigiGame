extends Control
class_name DigiWorkspaceFusionScreen

signal close_requested
signal tab_requested(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")
const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const WorkspaceBackdrop = preload("res://src/ui/components/DigiLabWorkspaceBackdrop.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const TransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")

const DESKTOP_BREAKPOINT := 980.0

var _database: DigimonDatabase
var _selected_fusion_id := ""
var _selected_material_ids: Array[String] = []
var _status_text := ""
var _page := 0

var _transition_surface: DigiUiTransitionSurface
var _backdrop: ColorRect
var _frame: PanelContainer
var _root: Control
var _header: DigiModalHeader
var _hint_bar: DigiInputHintBar
var _list_panel: PanelContainer
var _detail_panel: PanelContainer
var _list_header: DigiSectionHeader
var _detail_header: DigiSectionHeader
var _list: VBoxContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _pager: DigiPager
var _confirmation: ConfirmationDialog
var _close_lifecycle_managed := false
var _list_buttons: Array[Button] = []
var _list_ids: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.inventory_changed.connect(_on_inventory_changed)
	OverworldState.fusion_progress_changed.connect(_on_fusion_progress_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func get_transition_surface() -> DigiUiTransitionSurface:
	return _transition_surface


func set_close_lifecycle_managed(value: bool) -> void:
	_close_lifecycle_managed = value


func open_screen() -> void:
	visible = true
	WorkspaceChrome.configure_header(_header)
	_header.configure_tabs(PrimaryTabs.specs(), "fusion")
	_header.set_active_tab("fusion")
	WorkspaceChrome.configure_hints(_hint_bar, "Discover Fusion recipes, prepare materials and create permanent Fusion Digimon.", "", true)
	var definitions := OverworldState.get_fusion_definitions()
	if definitions.is_empty():
		_selected_fusion_id = ""
	elif _selected_fusion_id.is_empty() or not _definition_exists(_selected_fusion_id, definitions):
		_selected_fusion_id = String((definitions[0] as Dictionary).get("id", ""))
	_selected_material_ids.clear()
	_status_text = ""
	_refresh()
	_layout()
	call_deferred("_focus_selected")


func close_view() -> void:
	visible = false
	close_requested.emit()


func _request_close() -> void:
	if _close_lifecycle_managed:
		close_requested.emit()
	else:
		close_view()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		_request_close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_TAB and _header.select_adjacent_tab(1):
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEUP:
			_turn_page(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_PAGEDOWN:
			_turn_page(1)
			get_viewport().set_input_as_handled()


func _build() -> void:
	_transition_surface = TransitionSurfaceScript.new() as DigiUiTransitionSurface
	_transition_surface.name = "FusionWorkspaceTransition"
	add_child(_transition_surface)

	# Match every other DigiLab workspace layer contract:
	# legacy/base backdrop -> laboratory image -> transparent workspace frame.
	_backdrop = ColorRect.new()
	_backdrop.name = "FusionBaseBackdrop"
	_backdrop.color = V2.BACKDROP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "FusionWorkspace"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.BACKDROP, Color.TRANSPARENT, 0))
	_transition_surface.add_transition_child(_frame)

	var backdrop := WorkspaceBackdrop.new() as DigiLabWorkspaceBackdrop
	backdrop.name = "DigiLabWorkspaceBackdrop"
	_transition_surface.add_transition_child(backdrop)
	WorkspaceChrome.install_background(_transition_surface.get_content_root(), backdrop, _frame)

	_root = Control.new()
	_root.clip_contents = true
	_frame.add_child(_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "DigiLabHeader"
	_header.configure("DIGI LAB", "Fusion", OverworldState.get_bits(), true)
	_header.configure_tabs(PrimaryTabs.specs(), "fusion")
	_header.close_requested.connect(_request_close)
	_header.tab_selected.connect(_on_tab_selected)
	_root.add_child(_header)

	_list_panel = PanelContainer.new()
	_list_panel.clip_contents = true
	WorkspaceChrome.style_workspace_panel(_list_panel, V2.CYAN)
	_root.add_child(_list_panel)
	var list_stack := VBoxContainer.new()
	list_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_theme_constant_override("separation", 0)
	_list_panel.add_child(list_stack)
	_list_header = SectionHeaderScript.new() as DigiSectionHeader
	_list_header.configure("FUSION DATABASE", "Unlock at 100% Fusion Data", V2.CYAN, "evolution")
	_list_header.set_workspace_mode(true)
	list_stack.add_child(_list_header)
	var list_margin := _margin(10, 9, 10, 6)
	list_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_child(list_margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	list_margin.add_child(_list)
	var pager_margin := _margin(10, 2, 10, 8)
	_pager = PagerScript.new() as DigiPager
	_pager.set_workspace_mode(true)
	_pager.page_delta_requested.connect(_turn_page)
	pager_margin.add_child(_pager)
	list_stack.add_child(pager_margin)

	_detail_panel = PanelContainer.new()
	_detail_panel.clip_contents = true
	WorkspaceChrome.style_workspace_panel(_detail_panel, V2.CYAN)
	_root.add_child(_detail_panel)
	var detail_stack := VBoxContainer.new()
	detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_theme_constant_override("separation", 0)
	_detail_panel.add_child(detail_stack)
	_detail_header = SectionHeaderScript.new() as DigiSectionHeader
	_detail_header.configure("FUSION", "Combine prepared Digimon into a new permanent individual", V2.CYAN, "evolution")
	_detail_header.set_workspace_mode(true)
	detail_stack.add_child(_detail_header)
	var detail_margin := _margin(12, 10, 8, 10)
	detail_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_stack.add_child(detail_margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	var detail_inner := _margin(0, 0, 5, 0)
	detail_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(detail_inner)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	detail_inner.add_child(_detail)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.set_primary_tabs_enabled(true)
	_hint_bar.set_pagination_enabled(true)
	_hint_bar.set_scroll_hint_enabled(true)
	_root.add_child(_hint_bar)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm Fusion"
	_confirmation.ok_button_text = "FUSE"
	_confirmation.get_cancel_button().text = "CANCEL"
	_confirmation.confirmed.connect(_confirm_fusion)
	add_child(_confirmation)


func _on_tab_selected(tab_id: String) -> void:
	if tab_id != "fusion":
		tab_requested.emit(tab_id)


func _refresh() -> void:
	if not visible:
		return
	_header.set_bits(OverworldState.get_bits())
	_refresh_list()
	_refresh_detail()


func _refresh_list() -> void:
	_clear(_list)
	_list_buttons.clear()
	_list_ids.clear()
	var definitions := OverworldState.get_fusion_definitions()
	_list_header.set_trailing("%d RECIPES" % definitions.size())
	if definitions.is_empty():
		_list.add_child(_empty("No Fusion recipes are configured."))
		_pager.configure(0, 1)
		return
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 5, 4, 3)
	var page_count := maxi(1, ceili(float(definitions.size()) / float(capacity)))
	_page = clampi(_page, 0, page_count - 1)
	var start := _page * capacity
	var finish := mini(definitions.size(), start + capacity)
	for index in range(start, finish):
		var definition := definitions[index] as Dictionary
		var button := _fusion_button(definition)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(String(definition.get("id", "")))
	_pager.configure(_page, page_count)


func _fusion_button(definition: Dictionary) -> Button:
	var fusion_id := String(definition.get("id", ""))
	var data := int(OverworldState.get_fusion_data(fusion_id))
	var unlocked := data >= 100
	var result_species := _database.get_by_seed(String(definition.get("resultSeed", "")))
	var display_name := String(result_species.get("name", "Unknown")) if unlocked else "????????"
	var selected := fusion_id == _selected_fusion_id
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 78)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_select_fusion.bind(fusion_id))
	button.focus_entered.connect(_preview_fusion.bind(fusion_id))
	var accent := V2.CYAN
	button.add_theme_stylebox_override("normal", V2.hospital_panel_style(accent, selected))
	button.add_theme_stylebox_override("hover", V2.hospital_button_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.hospital_button_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.hospital_button_style(accent, "pressed"))

	var margin := _margin(8, 6, 10, 6)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(62, 62)
	portrait.set_species(String(result_species.get("name", "")))
	portrait.modulate = Color(0.035, 0.035, 0.045, 1.0) if not unlocked else Color.WHITE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(_line(display_name, 14, V2.TEXT if unlocked else V2.MUTED, true))
	copy.add_child(_line("UNLOCKED" if unlocked else "FUSION DATA %d / 100" % data, 10, V2.GREEN if unlocked else V2.ORANGE, true))
	var progress := ProgressBar.new()
	progress.max_value = 100
	progress.value = data
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(progress)
	return button


func _select_fusion(fusion_id: String) -> void:
	if fusion_id == _selected_fusion_id:
		return
	_selected_fusion_id = fusion_id
	_selected_material_ids.clear()
	_status_text = ""
	_refresh()


func _preview_fusion(fusion_id: String) -> void:
	if fusion_id != _selected_fusion_id:
		_selected_fusion_id = fusion_id
		_selected_material_ids.clear()
		_refresh_detail()


func _refresh_detail() -> void:
	_clear(_detail)
	if _selected_fusion_id.is_empty():
		_detail.add_child(_empty("Select a Fusion recipe."))
		return
	var definition := _definition(_selected_fusion_id)
	if definition.is_empty():
		_detail.add_child(_empty("Fusion definition unavailable."))
		return
	var data := int(OverworldState.get_fusion_data(_selected_fusion_id))
	var unlocked := data >= 100
	var result_species := _database.get_by_seed(String(definition.get("resultSeed", "")))
	if not _status_text.is_empty():
		_detail.add_child(_banner(_status_text, V2.CYAN))
	if not unlocked:
		_detail.add_child(_locked_card(result_species, data))
		return

	var preview := OverworldState.get_fusion_preview(_selected_fusion_id, _selected_material_ids)
	var resolved = preview.get("selected_ids", [])
	_selected_material_ids.clear()
	if resolved is Array:
		for raw_id in resolved:
			_selected_material_ids.append(String(raw_id))

	_detail.add_child(_result_card(result_species, preview))
	_detail.add_child(_section("MATERIAL DIGIMON", "Higher levels increase the resulting Potential.", V2.ORANGE))
	var slot_rows = preview.get("material_slots", [])
	if slot_rows is Array:
		for raw_slot in slot_rows:
			if raw_slot is Dictionary:
				_detail.add_child(_material_picker(raw_slot as Dictionary))
	var item_rows = preview.get("item_requirements", [])
	if item_rows is Array and not (item_rows as Array).is_empty():
		_detail.add_child(_section("ITEM MATERIALS", "Only recipes that define items consume them.", V2.CYAN))
		for raw_item in item_rows:
			if raw_item is Dictionary:
				var item := raw_item as Dictionary
				var ok := bool(item.get("valid", false))
				_detail.add_child(_banner("%s  %d / %d" % [String(item.get("itemId", "")).to_upper(), int(item.get("owned", 0)), int(item.get("amount", 0))], V2.GREEN if ok else V2.RED))
	var fuse := _button("FUSE", V2.ORANGE)
	fuse.custom_minimum_size.y = 50
	fuse.disabled = not bool(preview.get("can_fuse", false))
	fuse.tooltip_text = "Permanently consume the selected materials and create this Fusion." if not fuse.disabled else _reason(String(preview.get("reason", "missing_material")))
	fuse.pressed.connect(_request_fusion)
	_detail.add_child(fuse)


func _locked_card(result_species: Dictionary, data: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.76), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.34), 8))
	var margin := _margin(18, 18, 18, 18)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(190, 180)
	portrait.set_species(String(result_species.get("name", "")))
	portrait.modulate = Color(0.025, 0.025, 0.032, 1.0)
	stack.add_child(portrait)
	var unknown := _line("????????", 28, V2.MUTED, true)
	unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(unknown)
	var progress := ProgressBar.new()
	progress.max_value = 100
	progress.value = data
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(300, 18)
	stack.add_child(progress)
	var label := _line("FUSION DATA  %d / 100" % data, 13, V2.ORANGE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(label)
	return panel


func _result_card(species: Dictionary, preview: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.05), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.42), 8))
	var margin := _margin(14, 12, 14, 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(136, 128)
	portrait.set_species(String(species.get("name", "")))
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 6)
	row.add_child(copy)
	copy.add_child(_line(String(species.get("name", "Unknown")).to_upper(), 25, V2.TEXT, true))
	copy.add_child(_line("FUSION · LV 1", 11, V2.ORANGE, true))
	copy.add_child(_line("POTENTIAL %d  ·  TIER %s" % [int(preview.get("result_potential", 0)), String(preview.get("result_tier", "E"))], 14, V2.PURPLE, true))
	return panel


func _material_picker(slot: Dictionary) -> Control:
	var slot_index := int(slot.get("index", 0))
	var seed := String(slot.get("speciesSeed", ""))
	var species := _database.get_by_seed(seed)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.72), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.30), 7))
	var margin := _margin(11, 8, 11, 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var name := _line(String(species.get("name", "Unknown")).to_upper(), 12, V2.TEXT, true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name)
	header.add_child(_line("LV %d+" % int(slot.get("minLevel", 1)), 10, V2.ORANGE, true))
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 42
	var eligible := OverworldState.get_fusion_eligible_instances(_selected_fusion_id, slot_index)
	var current := String(slot.get("instanceId", ""))
	if eligible.is_empty():
		picker.add_item("No eligible Digimon")
		picker.set_item_disabled(0, true)
	else:
		var selected_index := 0
		for candidate: DigimonInstance in eligible:
			var candidate_species := _database.get_by_seed(candidate.species_seed)
			var role := OverworldState.get_squad_role(candidate.id)
			var location := "ACTIVE" if role == PlayerCollection.SQUAD_ROLE_ACTIVE else ("RESERVE" if role == PlayerCollection.SQUAD_ROLE_RESERVE else "STORAGE")
			picker.add_item("%s · Lv %d · Tier %s · %s" % [candidate.get_display_name(String(candidate_species.get("name", "Digimon"))), candidate.level, candidate.tier, location])
			picker.set_item_metadata(picker.item_count - 1, candidate.id)
			if candidate.id == current:
				selected_index = picker.item_count - 1
			elif _selected_material_ids.has(candidate.id):
				picker.set_item_disabled(picker.item_count - 1, true)
		picker.select(selected_index)
		picker.item_selected.connect(_on_material_selected.bind(slot_index, picker))
	_style_option(picker)
	stack.add_child(picker)
	return panel


func _on_material_selected(item_index: int, slot_index: int, picker: OptionButton) -> void:
	while _selected_material_ids.size() <= slot_index:
		_selected_material_ids.append("")
	_selected_material_ids[slot_index] = String(picker.get_item_metadata(item_index))
	_status_text = ""
	_refresh_detail()


func _request_fusion() -> void:
	var preview := OverworldState.get_fusion_preview(_selected_fusion_id, _selected_material_ids)
	if not bool(preview.get("can_fuse", false)):
		_status_text = _reason(String(preview.get("reason", "invalid")))
		_refresh_detail()
		return
	var lines: Array[String] = []
	for instance_id: String in preview.get("selected_ids", []):
		var instance := OverworldState.get_instance_by_id(instance_id)
		if instance == null:
			continue
		var species := _database.get_by_seed(instance.species_seed)
		lines.append("%s · Lv %d · Tier %s" % [instance.get_display_name(String(species.get("name", "Digimon"))), instance.level, instance.tier])
	_confirmation.dialog_text = "Create %s?

The following Digimon will be permanently consumed:
%s

Result: Lv 1 · Potential %d · Tier %s" % [
		String(preview.get("result_name", "Fusion")),
		"
".join(lines),
		int(preview.get("result_potential", 0)),
		String(preview.get("result_tier", "E")),
	]
	_confirmation.popup_centered(Vector2i(620, 360))


func _confirm_fusion() -> void:
	var result := OverworldState.fuse_digimon(_selected_fusion_id, _selected_material_ids)
	if bool(result.get("success", false)):
		_status_text = "%s created successfully." % String(result.get("result_name", "Fusion"))
		_selected_material_ids.clear()
	else:
		_status_text = _reason(String(result.get("reason", "invalid")))
	_refresh()


func _turn_page(delta: int) -> void:
	var definitions := OverworldState.get_fusion_definitions()
	var capacity := WorkspaceChrome.page_capacity(get_viewport(), 5, 4, 3)
	var page_count := maxi(1, ceili(float(definitions.size()) / float(capacity)))
	var next_page := clampi(_page + delta, 0, page_count - 1)
	if next_page == _page:
		return
	_page = next_page
	_refresh_list()
	call_deferred("_focus_selected")


func _definition(fusion_id: String) -> Dictionary:
	for definition: Dictionary in OverworldState.get_fusion_definitions():
		if String(definition.get("id", "")) == fusion_id:
			return definition
	return {}


func _definition_exists(fusion_id: String, definitions: Array[Dictionary]) -> bool:
	for definition: Dictionary in definitions:
		if String(definition.get("id", "")) == fusion_id:
			return true
	return false


func _focus_selected() -> void:
	for index in range(_list_ids.size()):
		if _list_ids[index] == _selected_fusion_id and index < _list_buttons.size():
			_list_buttons[index].grab_focus()
			return
	if not _list_buttons.is_empty():
		_list_buttons[0].grab_focus()


func _on_state_changed() -> void:
	if visible:
		_refresh()


func _on_inventory_changed(_inventory: Dictionary) -> void:
	if visible:
		_refresh_detail()


func _on_fusion_progress_changed(fusion_id: String, progress: Dictionary) -> void:
	if bool(progress.get("newly_unlocked", false)):
		_status_text = "Fusion unlocked: %s" % String(_database.get_by_seed(String(_definition(fusion_id).get("resultSeed", ""))).get("name", fusion_id))
	if visible:
		_refresh()


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
	var header_h := 76.0
	var footer_h := 64.0
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_hint_bar.position = Vector2(0, height - footer_h)
	_hint_bar.size = Vector2(width, footer_h)
	var top := header_h + 12.0
	var body_h := maxf(140.0, height - top - footer_h - 12.0)
	if compact:
		var edge := 10.0
		var list_h := clampf(body_h * 0.34, 175.0, 250.0)
		_list_panel.position = Vector2(edge, top)
		_list_panel.size = Vector2(width - edge * 2.0, list_h)
		_detail_panel.position = Vector2(edge, top + list_h + 10.0)
		_detail_panel.size = Vector2(width - edge * 2.0, body_h - list_h - 10.0)
	else:
		var edge := 22.0
		var gap := 12.0
		var list_w := clampf(width * 0.31, 330.0, 470.0)
		_list_panel.position = Vector2(edge, top)
		_list_panel.size = Vector2(list_w, body_h)
		_detail_panel.position = Vector2(edge + list_w + gap, top)
		_detail_panel.size = Vector2(width - edge * 2.0 - list_w - gap, body_h)


func _section(title: String, subtitle: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.header_strip_style(6))
	var margin := _margin(10, 6, 10, 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var a := _line(title, 10, accent, true)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var b := _line(subtitle, 9, V2.SUBTLE)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(b)
	return panel


func _banner(text: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(accent.r, accent.g, accent.b, 0.07), Color(accent.r, accent.g, accent.b, 0.30), 7))
	var margin := _margin(10, 7, 10, 7)
	panel.add_child(margin)
	margin.add_child(_label(text, 10, accent, true))
	return panel


func _reason(reason: String) -> String:
	var reasons := {
		"locked": "Reach 100% Fusion Data to unlock this recipe.",
		"missing_material": "One or more eligible Digimon materials are missing.",
		"missing_item": "A required item material is missing.",
		"material_changed": "A selected material is no longer available.",
		"transaction_failed": "Fusion could not be committed safely.",
	}
	return String(reasons.get(reason, "Fusion is not available (%s)." % reason))


func _style_option(button: OptionButton) -> void:
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_stylebox_override("normal", V2.button_style(V2.ORANGE, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(V2.ORANGE, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(V2.ORANGE, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(V2.ORANGE, "pressed", 7))
	V2.apply_body(button)


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 7))
	button.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(button)
	return button


func _empty(text: String) -> Label:
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


func _line(text: String, size: int, color: Color, bold: bool = false) -> Label:
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


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
