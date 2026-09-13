extends Control
class_name PartyStorageScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")

var _database: DigimonDatabase
var _progression: DigimonProgressionService
var _selected_id := ""

var _frame: PanelContainer
var _body_grid: GridContainer
var _collection_panel: PanelContainer
var _detail_panel: PanelContainer
var _list_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _summary_label: Label
var _status_label: Label
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
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not collection.is_empty():
		_selected_id = collection[0].id
	_status_label.text = ""
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
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "PartyStoragePanel"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", MENU.screen_frame())
	add_child(_frame)

	var outer := MENU.margin(18, 16, 18, 18)
	_frame.add_child(outer)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	heading.add_child(_label("PARTY / STORAGE", 25, UI.TEXT, true))
	_summary_label = _label("", 11, UI.MUTED)
	heading.add_child(_summary_label)
	var close := MENU.icon_button(CLOSE_ICON, UI.MUTED, "Close Party / Storage", Vector2(44, 44))
	close.pressed.connect(close_view)
	header.add_child(close)

	_status_label = _single_line_label("", 10, UI.CYAN, true)
	_status_label.custom_minimum_size.y = 20
	root.add_child(_status_label)

	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 12)
	_body_grid.add_theme_constant_override("v_separation", 12)
	root.add_child(_body_grid)

	_collection_panel = PanelContainer.new()
	_collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", MENU.surface(UI.CYAN, 0.80, 10))
	_body_grid.add_child(_collection_panel)
	var collection_margin := MENU.margin(12, 12, 12, 12)
	_collection_panel.add_child(collection_margin)
	var collection_root := VBoxContainer.new()
	collection_root.add_theme_constant_override("separation", 8)
	collection_margin.add_child(collection_root)
	collection_root.add_child(_section_label("COLLECTION", UI.CYAN))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.follow_focus = true
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_root.add_child(_list_scroll)
	SmoothScrollScript.attach(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_list)

	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", MENU.surface(UI.GOLD, 0.80, 10))
	_body_grid.add_child(_detail_panel)
	var detail_margin := MENU.margin(14, 14, 14, 14)
	_detail_panel.add_child(detail_margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail)

func _refresh() -> void:
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_summary_label.text = "ACTIVE %d / %d  ·  STORAGE %d" % [active_ids.size(), OverworldState.get_max_active_party_size(), maxi(0, collection.size() - active_ids.size())]
	_refresh_list()
	_refresh_detail()

func _refresh_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_list_buttons.clear()
	_list_ids.clear()
	_list_previews.clear()
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var collection: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if collection.is_empty():
		_list.add_child(_label("No Digimon available.", 12, UI.MUTED))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = collection[0].id
	for instance: DigimonInstance in collection:
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var active := active_ids.has(instance.id)
		var accent := UI.GOLD if active else UI.CYAN
		var button := _collection_button(instance, species, active, active_ids, accent)
		_list.add_child(button)
		_list_buttons.append(button)
		_list_ids.append(instance.id)
	_style_list_selection()

func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool, active_ids: Array[String], accent: Color) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(268, 78)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_select.bind(instance.id))
	button.focus_entered.connect(_select.bind(instance.id))
	button.tooltip_text = "Select %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	MENU.style_action_button(button, accent, instance.id == _selected_id)

	var margin := MENU.margin(9, 7, 10, 7)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(60, 60)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", "")))
	preview.set_active(instance.id == _selected_id)
	row.add_child(preview)
	_list_previews.append(preview)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := instance.get_display_name(String(species.get("name", "Unknown")))
	var location := "PARTY SLOT %d" % (active_ids.find(instance.id) + 1) if active else "STORAGE"
	copy.add_child(_single_line_label(name.to_upper(), 13, UI.TEXT, true))
	copy.add_child(_single_line_label("LV %d  ·  %s" % [instance.level, location], 10, accent.lightened(0.08), true))
	copy.add_child(_single_line_label("POT %d  ·  LINK %d" % [instance.potential, instance.link], 9, UI.SUBTLE, true))
	return button

func _style_list_selection() -> void:
	var active_ids := OverworldState.get_active_party_ids()
	for index in range(_list_buttons.size()):
		var id := _list_ids[index] if index < _list_ids.size() else ""
		var active := active_ids.has(id)
		var accent := UI.GOLD if active else UI.CYAN
		var selected := id == _selected_id
		MENU.style_action_button(_list_buttons[index], UI.GREEN if selected else accent, selected)
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
	_status_label.text = ""
	_style_list_selection()
	_refresh_detail()

func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var instance: DigimonInstance = OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_label("Select a Digimon from your collection.", 13, UI.MUTED))
		return
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_detail.add_child(_label("Species data unavailable.", 13, UI.RED))
		return

	var species_name := String(species.get("name", "Unknown"))
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var active_ids: Array[String] = OverworldState.get_active_party_ids()
	var party_index := active_ids.find(instance.id)
	var active := party_index >= 0

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MENU.card(accent, true))
	_detail.add_child(card)
	var card_margin := MENU.margin(12, 10, 12, 10)
	card.add_child(card_margin)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	card_margin.add_child(hero)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(132, 118)
	portrait_frame.add_theme_stylebox_override("panel", MENU.portrait(accent))
	hero.add_child(portrait_frame)
	var portrait_margin := MENU.margin(6, 6, 6, 6)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(120, 106)
	portrait.set_species(species_name)
	portrait_margin.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 4)
	hero.add_child(identity)
	identity.add_child(_label(instance.get_display_name(species_name).to_upper(), 22, UI.TEXT, true))
	identity.add_child(_label("%s  ·  LV %d" % [rank.to_upper(), instance.level], 11, accent.lightened(0.10), true))
	identity.add_child(_label("ACTIVE PARTY  ·  SLOT %d" % (party_index + 1) if active else "STORAGE", 10, UI.GOLD if active else UI.CYAN, true))
	identity.add_child(_label("ID %s" % instance.id.substr(0, mini(8, instance.id.length())), 9, UI.SUBTLE))

	_detail.add_child(_section_label("COMBAT STATS", UI.CYAN))
	var stats: Dictionary = _progression.get_final_stats(instance)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 3
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_grid.add_theme_constant_override("h_separation", 8)
	stats_grid.add_theme_constant_override("v_separation", 8)
	_detail.add_child(stats_grid)
	for entry in [
		["HP", stats.get("hp", 0), UI.GREEN], ["SP", stats.get("sp", 0), UI.BLUE],
		["ATK", stats.get("atk", 0), UI.GOLD], ["DEF", stats.get("def", 0), UI.CYAN],
		["INT", stats.get("int", 0), UI.PURPLE], ["SPD", stats.get("speed", 0), UI.ORANGE]
	]:
		stats_grid.add_child(_stat_chip(String(entry[0]), int(entry[1]), entry[2] as Color))

	var meta := PanelContainer.new()
	meta.add_theme_stylebox_override("panel", MENU.card(UI.PURPLE, false))
	_detail.add_child(meta)
	var meta_margin := MENU.margin(10, 7, 10, 7)
	meta.add_child(meta_margin)
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 12)
	meta_margin.add_child(meta_row)
	var link := _single_line_label("LINK %d / %d" % [instance.link, DigimonInstance.MAX_LINK], 10, UI.CYAN, true)
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(link)
	var potential := _single_line_label("POTENTIAL %d / %d" % [instance.potential, DigimonInstance.MAX_POTENTIAL], 10, UI.PURPLE, true)
	potential.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(potential)

	_detail.add_child(_section_label("PARTY ACTIONS", UI.GOLD))
	if active:
		var remove := MENU.action_button("MOVE TO STORAGE", UI.ORANGE)
		remove.disabled = active_ids.size() <= 1
		remove.tooltip_text = "At least one Digimon must remain active." if remove.disabled else "Move this Digimon to Storage."
		remove.pressed.connect(_remove_from_party.bind(instance.id))
		_detail.add_child(remove)
		var order := HBoxContainer.new()
		order.add_theme_constant_override("separation", 8)
		_detail.add_child(order)
		var up := MENU.action_button("MOVE UP", UI.CYAN)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.disabled = party_index <= 0
		up.pressed.connect(_move.bind(instance.id, party_index - 1))
		order.add_child(up)
		var down := MENU.action_button("MOVE DOWN", UI.CYAN)
		down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		down.disabled = party_index >= active_ids.size() - 1
		down.pressed.connect(_move.bind(instance.id, party_index + 1))
		order.add_child(down)
	else:
		var add := MENU.action_button("ADD TO PARTY", UI.GREEN)
		add.disabled = active_ids.size() >= OverworldState.get_max_active_party_size()
		add.tooltip_text = "Party is full. Choose a slot to swap." if add.disabled else "Add this Digimon to the active party."
		add.pressed.connect(_add_to_party.bind(instance.id))
		_detail.add_child(add)
		if add.disabled:
			_detail.add_child(_label("PARTY FULL  ·  CHOOSE THE ACTIVE SLOT TO REPLACE", 10, UI.MUTED, true))
			var swaps := GridContainer.new()
			swaps.columns = 1
			swaps.add_theme_constant_override("v_separation", 6)
			_detail.add_child(swaps)
			for active_id: String in active_ids:
				var active_instance: DigimonInstance = OverworldState.get_instance_by_id(active_id)
				if active_instance == null:
					continue
				var active_species: Dictionary = _database.get_by_seed(active_instance.species_seed)
				var active_name := active_instance.get_display_name(String(active_species.get("name", "Digimon")))
				var slot := active_ids.find(active_id) + 1
				var swap := MENU.action_button("REPLACE SLOT %d  ·  %s" % [slot, active_name.to_upper()], UI.PURPLE)
				swap.pressed.connect(_swap.bind(active_id, instance.id))
				swaps.add_child(swap)

func _stat_chip(stat_name: String, value: int, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", MENU.stat_surface(accent))
	var margin := MENU.margin(8, 6, 8, 6)
	panel.add_child(margin)
	var label := _single_line_label("%s  %d" % [stat_name, value], 11, UI.TEXT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return panel

func _add_to_party(instance_id: String) -> void:
	var ok := OverworldState.add_to_active_party(instance_id)
	_status_label.text = "Added to active party." if ok else "Could not add this Digimon to the party."
	_refresh()
	call_deferred("_focus_selected")

func _remove_from_party(instance_id: String) -> void:
	var ok := OverworldState.remove_from_active_party(instance_id)
	_status_label.text = "Moved to Storage." if ok else "At least one Digimon must remain active."
	_refresh()
	call_deferred("_focus_selected")

func _swap(active_id: String, reserve_id: String) -> void:
	var ok := OverworldState.swap_party_with_reserve(active_id, reserve_id)
	_status_label.text = "Party slot updated." if ok else "Could not swap these Digimon."
	_refresh()
	call_deferred("_focus_selected")

func _move(instance_id: String, new_index: int) -> void:
	var ok := OverworldState.move_active_party_member(instance_id, new_index)
	_status_label.text = "Party order updated." if ok else "Could not change party order."
	_refresh()
	call_deferred("_focus_selected")

func _on_state_changed() -> void:
	if visible:
		_refresh()

func _on_party_changed(_party: Array) -> void:
	if visible:
		_refresh()

func _layout() -> void:
	if not visible or _frame == null:
		return
	var layout := MENU.apply_safe_frame(_frame, get_viewport(), Vector2(1240, 720), 840.0)
	var compact := bool(layout.get("compact", false))
	_body_grid.columns = 1 if compact else 2
	if compact:
		_collection_panel.custom_minimum_size = Vector2(0, 175)
		_detail_panel.custom_minimum_size = Vector2.ZERO
	else:
		_collection_panel.custom_minimum_size = Vector2(310, 0)
		_detail_panel.custom_minimum_size = Vector2.ZERO

func _section_label(text: String, accent: Color) -> Label:
	var label := _single_line_label(text, 10, accent.lightened(0.08), true)
	label.custom_minimum_size.y = 22
	return label

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
