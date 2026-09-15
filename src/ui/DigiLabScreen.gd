extends Control
class_name DigiLabScreen

signal close_requested
signal reconstructed(instance: DigimonInstance)
signal tab_requested(tab_id: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")

const DESKTOP_BREAKPOINT := 980.0

var _database: DigimonDatabase
var _factory: DigimonFactory
var _selected_name := ""
var _lab_mode := "reconstruction"
var _data_buttons: Array[Button] = []

var _backdrop: ColorRect
var _frame: PanelContainer
var _root: Control
var _header: DigiModalHeader
var _header_rule: ColorRect
var _hint_bar: DigiInputHintBar
var _list_panel: PanelContainer
var _list_header: DigiSectionHeader
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
var _detail_panel: PanelContainer
var _detail_header: DigiSectionHeader
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
var _mode_bar: HBoxContainer
var _reconstruct_mode_button: Button
var _records_mode_button: Button
var _record_search: LineEdit
var _empty_label: Label
var _announcement: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_factory = FactoryScript.new(_database) as DigimonFactory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_layout)
	OverworldState.account_rewards_changed.connect(_on_data_changed)
	visible = false


func open_lab() -> void:
	visible = true
	_header.set_active_tab("convert")
	_header.set_bits(OverworldState.get_bits())
	_layout()
	_refresh()
	call_deferred("_layout")
	call_deferred("_focus_selected_data")
	_frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close_view() -> void:
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		close_view()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = V2.BACKDROP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "ConvertDigiDataV2"
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
	], "convert")
	_header.close_requested.connect(close_view)
	_header.tab_selected.connect(_on_top_tab_selected)
	_root.add_child(_header)

	_header_rule = ColorRect.new()
	_header_rule.color = Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.62)
	_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_header_rule)

	_list_panel = PanelContainer.new()
	_list_panel.clip_contents = true
	_list_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.74), 8))
	_root.add_child(_list_panel)
	var list_stack := VBoxContainer.new()
	list_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_theme_constant_override("separation", 0)
	_list_panel.add_child(list_stack)
	_list_header = SectionHeaderScript.new() as DigiSectionHeader
	_list_header.configure("DIGI DATA ARCHIVE", "", V2.CYAN, "database")
	list_stack.add_child(_list_header)
	var list_inset := _margin(10, 10, 5, 10)
	list_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_stack.add_child(list_inset)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.follow_focus = true
	_list_scroll.scroll_deadzone = 8
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_inset.add_child(_list_scroll)
	SmoothScrollScript.attach(_list_scroll)
	var list_scroll_inset := _margin(0, 0, 6, 0)
	list_scroll_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(list_scroll_inset)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	list_scroll_inset.add_child(_list_box)

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
	_detail_header.configure("RECONSTRUCTION", "Build a persistent Digimon from collected data", V2.CYAN, "database")
	detail_stack.add_child(_detail_header)

	var mode_inset := _margin(12, 8, 12, 4)
	detail_stack.add_child(mode_inset)
	_mode_bar = HBoxContainer.new()
	_mode_bar.add_theme_constant_override("separation", 6)
	mode_inset.add_child(_mode_bar)
	_reconstruct_mode_button = _mode_button("RECONSTRUCTION", "database")
	_reconstruct_mode_button.pressed.connect(_set_lab_mode.bind("reconstruction"))
	_mode_bar.add_child(_reconstruct_mode_button)
	_records_mode_button = _mode_button("TECHNIQUE RECORDS", "book")
	_records_mode_button.pressed.connect(_set_lab_mode.bind("records"))
	_mode_bar.add_child(_records_mode_button)
	var mode_spacer := Control.new()
	mode_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_bar.add_child(mode_spacer)
	_record_search = LineEdit.new()
	_record_search.placeholder_text = "Search techniques"
	_record_search.custom_minimum_size = Vector2(190, 34)
	_record_search.visible = false
	_record_search.add_theme_font_size_override("font_size", 10)
	_record_search.add_theme_color_override("font_color", V2.TEXT)
	_record_search.add_theme_color_override("font_placeholder_color", V2.SUBTLE)
	_record_search.add_theme_stylebox_override("normal", V2.surface_style(V2.PANEL_DEEP, V2.BORDER_SOFT, 6, Vector4(10, 5, 10, 5)))
	_record_search.add_theme_stylebox_override("focus", V2.button_style(V2.CYAN, "focus", 6))
	V2.apply_body(_record_search)
	_record_search.text_changed.connect(func(_text: String): _refresh_detail())
	_mode_bar.add_child(_record_search)

	var detail_inset := _margin(12, 6, 7, 12)
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
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 10)
	detail_scroll_inset.add_child(_detail_body)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "InputHints"
	_hint_bar.set_description("Convert Digi Data into persistent Digimon or manage permanent Technique Records.")
	_root.add_child(_hint_bar)

	_announcement = _label("", 18, V2.GREEN, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announcement.visible = false
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announcement)
	_style_mode_tabs()


func _on_top_tab_selected(tab_id: String) -> void:
	if tab_id == "party":
		tab_requested.emit("party")


func _refresh() -> void:
	_header.set_bits(OverworldState.get_bits())
	_refresh_list()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _clear_children_now(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_list() -> void:
	_clear_children_now(_list_box)
	_data_buttons.clear()
	if _lab_mode == "records":
		_refresh_record_roster()
		return
	var data := OverworldState.get_digi_data()
	var entries: Array[Dictionary] = []
	for raw_name in data.keys():
		var name := String(raw_name)
		var amount := int(data[raw_name])
		if amount <= 0 or _database.get_by_name(name).is_empty():
			continue
		entries.append({"name": name, "amount": amount})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var aa := int(a.get("amount", 0))
		var bb := int(b.get("amount", 0))
		return String(a.get("name", "")) < String(b.get("name", "")) if aa == bb else aa > bb
	)
	_list_header.set_trailing("%d DISCOVERED" % entries.size())
	if entries.is_empty():
		_empty_label = _label("No Digi Data yet.\nDefeat Digimon in battle to discover reconstruction data.", 12, V2.MUTED)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.custom_minimum_size.y = 140
		_list_box.add_child(_empty_label)
		_selected_name = ""
		return
	var selection_still_exists := false
	for entry: Dictionary in entries:
		var name := String(entry.get("name", ""))
		var amount := int(entry.get("amount", 0))
		selection_still_exists = selection_still_exists or name.to_lower() == _selected_name.to_lower()
		var button := _data_button(name, amount)
		_list_box.add_child(button)
		_data_buttons.append(button)
	if not selection_still_exists:
		_selected_name = String(entries[0].get("name", ""))
	_style_selection()


func _data_button(species_name: String, amount: int) -> Button:
	var species := _database.get_by_name(species_name)
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var button := Button.new()
	button.text = "%s\n%s  ·  %d DATA" % [species_name.to_upper(), rank.to_upper(), amount]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 66)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_species.bind(species_name))
	button.focus_entered.connect(_select_species.bind(species_name))
	button.set_meta("species_name", species_name)
	button.tooltip_text = "Inspect reconstruction data for %s" % species_name
	_style_roster_button(button, false, accent)
	return button


func _select_species(species_name: String) -> void:
	if _selected_name.to_lower() == species_name.to_lower() and _detail_body.get_child_count() > 0:
		return
	_selected_name = species_name
	_style_selection()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _style_selection() -> void:
	if _lab_mode == "records":
		for button: Button in _data_buttons:
			var selected := String(button.get_meta("instance_id", "")) == _selected_name
			_style_roster_button(button, selected, V2.CYAN)
		return
	for button: Button in _data_buttons:
		var species_name := String(button.get_meta("species_name", ""))
		var species := _database.get_by_name(species_name)
		var selected := species_name.to_lower() == _selected_name.to_lower()
		_style_roster_button(button, selected, V2.rank_color(String(species.get("rank", "Unknown"))))


func _focus_selected_data() -> void:
	if not visible:
		return
	for button: Button in _data_buttons:
		if _lab_mode == "records" and String(button.get_meta("instance_id", "")) == _selected_name:
			button.grab_focus()
			return
		if String(button.get_meta("species_name", "")).to_lower() == _selected_name.to_lower():
			button.grab_focus()
			return
	if not _data_buttons.is_empty():
		_data_buttons[0].grab_focus()


func _refresh_detail() -> void:
	_clear_children_now(_detail_body)
	if _lab_mode == "records":
		_refresh_record_detail()
		return
	if _selected_name.is_empty():
		_detail_body.add_child(_empty_state("Select a species to inspect its reconstruction progress."))
		return
	var species := _database.get_by_name(_selected_name)
	if species.is_empty():
		return
	var canonical_name := String(species.get("name", _selected_name))
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var available := OverworldState.get_digi_data_for(canonical_name)
	var required := OverworldState.get_reconstruction_requirement(canonical_name)
	_detail_body.add_child(_simple_reconstruction_hero(canonical_name, rank, accent, available, required))
	_detail_body.add_child(_subsection("RECONSTRUCTION OPTIONS", "Choose how much Digi Data to invest.", V2.CYAN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_detail_body.add_child(grid)
	for amount in [required, mini(200, required + 50), mini(200, required + 100)]:
		if amount <= 0:
			continue
		var potential := _factory.potential_from_scan_percent(clampi(amount, 100, 200))
		var caption := "%d DATA" % amount
		if potential > 0:
			caption += "\n+%d POTENTIAL" % potential
		var button := _button(caption, V2.AMBER if amount == required else V2.CYAN)
		button.custom_minimum_size = Vector2(128, 68)
		button.disabled = available < amount
		button.pressed.connect(_reconstruct.bind(canonical_name, amount))
		grid.add_child(button)


func _simple_reconstruction_hero(canonical_name: String, rank: String, accent: Color, available: int, required: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(accent.r, accent.g, accent.b, 0.44), 8))
	var margin := _margin(14, 12, 14, 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(154, 142)
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(0.015, 0.030, 0.044, 1.0), Color(accent.r, accent.g, accent.b, 0.52), 8))
	row.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.set_species(canonical_name)
	portrait_frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	info.add_child(_label(canonical_name.to_upper(), 25, V2.TEXT, true))
	info.add_child(_label(rank.to_upper(), 10, accent, true))
	info.add_child(_label("%d / %d DIGI DATA" % [available, required], 18, V2.AMBER, true))
	info.add_child(_progress_bar(accent, required, available))
	return panel


func _reconstruct(species_name: String, amount: int) -> void:
	var instance := OverworldState.reconstruct_digimon(species_name, amount)
	if instance == null:
		_refresh()
		return
	reconstructed.emit(instance)
	_show_announcement("%s RECONSTRUCTED" % species_name.to_upper())
	_refresh()


func _show_announcement(text: String) -> void:
	_announcement.text = text
	_announcement.visible = true
	_announcement.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_announcement, "modulate:a", 1.0, 0.14)
	await tween.finished
	await get_tree().create_timer(0.75).timeout
	var out := create_tween()
	out.tween_property(_announcement, "modulate:a", 0.0, 0.24)
	await out.finished
	_announcement.visible = false


func _on_data_changed(bits: int, _data: Dictionary) -> void:
	_header.set_bits(bits)
	if visible:
		_refresh()


func _set_lab_mode(mode: String) -> void:
	if mode == _lab_mode:
		return
	_lab_mode = mode
	_selected_name = ""
	var records_mode := mode == "records"
	_list_header.configure("OWNED DIGIMON" if records_mode else "DIGI DATA ARCHIVE", "", V2.AMBER if records_mode else V2.CYAN, "book" if records_mode else "database")
	_detail_header.configure("TECHNIQUE RECORDS" if records_mode else "RECONSTRUCTION", "Teach permanent techniques with account-wide Records" if records_mode else "Build a persistent Digimon from collected data", V2.AMBER if records_mode else V2.CYAN, "book" if records_mode else "database")
	_record_search.visible = records_mode
	_hint_bar.set_description("Teach permanent techniques from unlocked Records." if records_mode else "Convert Digi Data into persistent Digimon or manage permanent Technique Records.")
	_style_mode_tabs()
	_refresh()
	call_deferred("_focus_selected_data")


func _style_mode_tabs() -> void:
	if _reconstruct_mode_button == null:
		return
	_style_mode_button(_reconstruct_mode_button, _lab_mode == "reconstruction", V2.CYAN)
	_style_mode_button(_records_mode_button, _lab_mode == "records", V2.AMBER)


func _refresh_record_roster() -> void:
	var instances: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_list_header.set_trailing("%d OWNED" % instances.size())
	if instances.is_empty():
		_list_box.add_child(_empty_state("No owned Digimon."))
		return
	var selection_exists := false
	for instance: DigimonInstance in instances:
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", "Digimon")))
		var rank := String(species.get("rank", "Unknown"))
		var button := Button.new()
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("instance_id", instance.id)
		button.pressed.connect(_select_record_instance.bind(instance.id))
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
		preview.custom_minimum_size = Vector2(56, 56)
		preview.set_species(String(species.get("name", "")))
		preview.set_active(instance.id == _selected_name)
		row.add_child(preview)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 3)
		row.add_child(copy)
		copy.add_child(_label(name, 14, V2.TEXT, true))
		copy.add_child(_label("Lv %d  ·  %s" % [instance.level, rank], 10, V2.rank_color(rank), true))
		copy.add_child(_label("%d BITS available" % OverworldState.get_bits(), 9, V2.MUTED))
		_list_box.add_child(button)
		_data_buttons.append(button)
		selection_exists = selection_exists or instance.id == _selected_name
	if not selection_exists:
		_selected_name = instances[0].id
	_style_selection()


func _select_record_instance(instance_id: String) -> void:
	if _selected_name == instance_id and _detail_body.get_child_count() > 0:
		return
	_selected_name = instance_id
	_style_selection()
	_refresh_detail()
	call_deferred("_wire_focus_navigation")


func _refresh_record_detail() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_name)
	if instance == null:
		_detail_body.add_child(_empty_state("Select an owned Digimon to use Technique Records."))
		return
	var species := _database.get_by_seed(instance.species_seed)
	var name := instance.get_display_name(String(species.get("name", "Digimon")))
	_detail_body.add_child(_subsection("%s · %d BITS" % [name.to_upper(), OverworldState.get_bits()], "Compatibility is checked while teaching; learned techniques remain permanent.", V2.AMBER))
	var query := _record_search.text.to_lower().strip_edges()
	var shown := 0
	for action: Dictionary in OverworldState.get_teachable_techniques(instance.id):
		var action_name := String(action.get("name", action.get("id", "Technique")))
		if not query.is_empty() and not action_name.to_lower().contains(query) and not String(action.get("id", "")).contains(query):
			continue
		var unlocked := bool(action.get("unlocked", false))
		var research := int(action.get("research", 0))
		if not unlocked and research <= 0:
			continue
		var record = action.get("record", {})
		var cost := int(record.get("bitsCost", 0)) if record is Dictionary else 0
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.34 if unlocked else 0.16), 7))
		var margin := _margin(12, 9, 12, 9)
		panel.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)
		info.add_child(_label(action_name, 13, V2.TEXT, true))
		info.add_child(_label("%s · %s · Research %d/3" % [String(action.get("element", "neutral")).capitalize(), String(record.get("recordLevel", "common")).capitalize(), research], 9, V2.MUTED))
		var teach := _button("LEARN\n%d BITS" % cost, V2.AMBER)
		teach.custom_minimum_size = Vector2(112, 50)
		teach.disabled = not unlocked or not bool(action.get("compatible", false)) or bool(action.get("learned", false)) or OverworldState.get_bits() < cost
		teach.tooltip_text = "Already learned" if bool(action.get("learned", false)) else ("Incompatible with the current form" if not bool(action.get("compatible", false)) else "Teach permanently")
		teach.pressed.connect(_teach_record.bind(instance.id, String(action.get("id", ""))))
		row.add_child(teach)
		_detail_body.add_child(panel)
		shown += 1
	if shown == 0:
		_detail_body.add_child(_empty_state("No unlocked or researched Records match this search."))


func _teach_record(instance_id: String, skill_id: String) -> void:
	var result := OverworldState.teach_technique(instance_id, skill_id)
	if bool(result.get("success", false)):
		_show_announcement("TECHNIQUE LEARNED")
	_refresh()


func _wire_focus_navigation() -> void:
	if _data_buttons.is_empty():
		return
	var selected := _data_buttons[0]
	for button: Button in _data_buttons:
		if (_lab_mode == "records" and String(button.get_meta("instance_id", "")) == _selected_name) or (_lab_mode != "records" and String(button.get_meta("species_name", "")).to_lower() == _selected_name.to_lower()):
			selected = button
			break
	var detail_controls := _focusable_descendants(_detail_body)
	var first_detail: Control = _reconstruct_mode_button
	if not detail_controls.is_empty():
		first_detail = detail_controls[0]
	for button: Button in _data_buttons:
		button.focus_neighbor_right = button.get_path_to(first_detail)
	if first_detail != null:
		first_detail.focus_neighbor_left = first_detail.get_path_to(selected)
	var active_tab := _header.get_tab_button("convert")
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
		_list_panel.position = Vector2(edge, body_top)
		_list_panel.size = Vector2(width - edge * 2.0, list_h)
		_detail_panel.position = Vector2(edge, body_top + list_h + 10.0)
		_detail_panel.size = Vector2(width - edge * 2.0, maxf(100.0, body_h - list_h - 10.0))
	else:
		var edge := 22.0
		var gap := 12.0
		var list_w := clampf(width * 0.34, 330.0, 520.0)
		_list_panel.position = Vector2(edge, body_top)
		_list_panel.size = Vector2(list_w, body_h)
		_detail_panel.position = Vector2(edge + list_w + gap, body_top)
		_detail_panel.size = Vector2(width - edge * 2.0 - list_w - gap, body_h)

	_announcement.scale = Vector2.ONE * scale_factor
	_announcement.position = Vector2(width * 0.25, header_h + 8.0) * scale_factor
	_announcement.size = Vector2(width * 0.50, 42.0)


func _mode_button(text: String, icon_kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(150, 34)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("icon_kind", icon_kind)
	button.add_theme_font_size_override("font_size", 10)
	V2.apply_heading(button)
	return button


func _style_mode_button(button: Button, active: bool, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", V2.tab_style(active, false, false))
	button.add_theme_stylebox_override("hover", V2.tab_style(active, true, false))
	button.add_theme_stylebox_override("focus", V2.tab_style(active, true, false))
	button.add_theme_stylebox_override("pressed", V2.tab_style(active, true, false))
	button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_focus_color", accent)


func _style_roster_button(button: Button, selected: bool, accent: Color) -> void:
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
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	V2.apply_body(button)


func _subsection(title: String, subtitle: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.header_strip_style(6))
	var margin := _margin(12, 7, 12, 7)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var title_label := _label(title, 11, accent, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var subtitle_label := _label(subtitle, 9, V2.SUBTLE)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(subtitle_label)
	return panel


func _empty_state(text: String) -> Label:
	var label := _label(text, 12, V2.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = 120
	return label


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


func _progress_bar(accent: Color, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = float(maxi(1, maximum))
	bar.value = float(clampi(value, 0, maxi(1, maximum)))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	return bar


func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
