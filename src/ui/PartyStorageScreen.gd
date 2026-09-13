extends Control
class_name PartyStorageScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database: DigimonDatabase
var _progression: DigimonProgressionService
var _selected_id := ""

var _frame: PanelContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_progression = ProgressionServiceScript.new(_database) as DigimonProgressionService
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.roster_changed.connect(_on_state_changed)
	OverworldState.active_party_changed.connect(_on_party_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_screen() -> void:
	visible = true
	var roster := OverworldState.get_roster_instances()
	if _selected_id.is_empty() and not roster.is_empty():
		_selected_id = roster[0].id
	_refresh()
	call_deferred("_layout")


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
	backdrop.color = Color(0.006, 0.015, 0.035, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.08, 0.13, 0.21, 0.99), Vector4.ZERO, 14.0))
	add_child(_frame)

	_title = _label("PARTY / STORAGE", 24, UI.TEXT, true)
	add_child(_title)
	_close_button = _button("CLOSE", UI.MUTED)
	_close_button.pressed.connect(close_view)
	add_child(_close_button)

	var list_panel := PanelContainer.new()
	list_panel.name = "RosterPanel"
	list_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.CYAN, Vector4(12, 12, 12, 12), 10.0))
	_frame.add_child(list_panel)
	list_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	list_panel.position = Vector2(18, 72)
	list_panel.size = Vector2(330, 620)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	list_scroll.add_child(_list)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.GOLD, Vector4(16, 16, 16, 16), 10.0))
	_frame.add_child(detail_panel)
	detail_panel.position = Vector2(366, 72)
	detail_panel.size = Vector2(746, 620)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_detail)


func _refresh() -> void:
	_refresh_list()
	_refresh_detail()


func _refresh_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var active_ids := OverworldState.get_active_party_ids()
	var roster := OverworldState.get_roster_instances()
	if roster.is_empty():
		_list.add_child(_label("No Digimon in storage.", 12, UI.MUTED))
		return
	for instance: DigimonInstance in roster:
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", "Unknown")))
		var active := active_ids.has(instance.id)
		var button := _button("%s\nLv. %d  ·  %s" % [name.to_upper(), instance.level, "PARTY" if active else "STORAGE"], UI.GOLD if active else UI.CYAN)
		button.custom_minimum_size = Vector2(286, 62)
		button.pressed.connect(_select.bind(instance.id))
		if instance.id == _selected_id:
			button.add_theme_stylebox_override("normal", SKIN.border_style(UI.GREEN, Vector4(13, 9, 13, 9), 9.0))
		_list.add_child(button)


func _select(instance_id: String) -> void:
	_selected_id = instance_id
	_refresh()


func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_label("Select a Digimon.", 13, UI.MUTED))
		return
	var species := _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return
	var species_name := String(species.get("name", "Unknown"))
	var rank := String(species.get("rank", "Unknown"))
	var active_ids := OverworldState.get_active_party_ids()
	var party_index := active_ids.find(instance.id)
	var active := party_index >= 0

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 16)
	_detail.add_child(hero)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(180, 150)
	portrait.set_species(species_name)
	hero.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(identity)
	identity.add_child(_label(instance.get_display_name(species_name).to_upper(), 24, UI.TEXT, true))
	identity.add_child(_label("%s  ·  Lv. %d" % [rank.to_upper(), instance.level], 13, UI.rank_color(rank), true))
	identity.add_child(_label("ACTIVE PARTY · SLOT %d" % (party_index + 1) if active else "STORAGE", 12, UI.GOLD if active else UI.CYAN, true))
	identity.add_child(_label("Instance  %s" % instance.id.substr(0, mini(8, instance.id.length())), 9, UI.SUBTLE))

	var stats := _progression.get_final_stats(instance)
	_detail.add_child(_label("HP %d   SP %d   ATK %d   DEF %d   INT %d   SPD %d" % [int(stats.get("hp", 0)), int(stats.get("sp", 0)), int(stats.get("atk", 0)), int(stats.get("def", 0)), int(stats.get("int", 0)), int(stats.get("speed", 0))], 13, UI.TEXT, true))
	_detail.add_child(_label("Link: tactical battle synergy · Potential %d" % instance.potential, 11, UI.MUTED))

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_detail.add_child(actions)
	if active:
		var remove := _button("MOVE TO STORAGE", UI.ORANGE)
		remove.disabled = active_ids.size() <= 1
		remove.tooltip_text = "At least one Digimon must remain active." if remove.disabled else "Remove this Digimon from the active party."
		remove.pressed.connect(_remove_from_party.bind(instance.id))
		actions.add_child(remove)
		var order := HBoxContainer.new()
		order.add_theme_constant_override("separation", 8)
		actions.add_child(order)
		var up := _button("MOVE UP", UI.CYAN)
		up.disabled = party_index <= 0
		up.pressed.connect(_move.bind(instance.id, party_index - 1))
		order.add_child(up)
		var down := _button("MOVE DOWN", UI.CYAN)
		down.disabled = party_index >= active_ids.size() - 1
		down.pressed.connect(_move.bind(instance.id, party_index + 1))
		order.add_child(down)
	else:
		var add := _button("ADD TO PARTY", UI.GREEN)
		add.disabled = active_ids.size() >= OverworldState.get_max_active_party_size()
		add.tooltip_text = "Party is full. Choose a slot below to swap." if add.disabled else "Add this Digimon to the active party."
		add.pressed.connect(_add_to_party.bind(instance.id))
		actions.add_child(add)
		if add.disabled:
			actions.add_child(_label("PARTY FULL · SWAP WITH", 10, UI.MUTED, true))
			for active_id: String in active_ids:
				var active_instance := OverworldState.get_instance_by_id(active_id)
				if active_instance == null:
					continue
				var active_species := _database.get_by_seed(active_instance.species_seed)
				var swap := _button("SWAP  %s" % active_instance.get_display_name(String(active_species.get("name", "Digimon"))).to_upper(), UI.PURPLE)
				swap.pressed.connect(_swap.bind(active_id, instance.id))
				actions.add_child(swap)


func _add_to_party(instance_id: String) -> void:
	OverworldState.add_to_active_party(instance_id)
	_refresh()


func _remove_from_party(instance_id: String) -> void:
	OverworldState.remove_from_active_party(instance_id)
	_refresh()


func _swap(active_id: String, reserve_id: String) -> void:
	OverworldState.swap_party_with_reserve(active_id, reserve_id)
	_refresh()


func _move(instance_id: String, new_index: int) -> void:
	OverworldState.move_active_party_member(instance_id, new_index)
	_refresh()


func _on_state_changed() -> void:
	if visible:
		_refresh()


func _on_party_changed(_party: Array) -> void:
	if visible:
		_refresh()


func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var edge := 12.0
	var width := minf(1160.0, physical.x - edge * 2.0)
	var height := minf(740.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)
	var roster_panel := _frame.get_node_or_null("RosterPanel") as Control
	var detail_panel := _frame.get_node_or_null("DetailPanel") as Control
	var compact := width < 850.0
	if compact:
		var list_height := minf(220.0, height * 0.31)
		roster_panel.position = Vector2(14, 68)
		roster_panel.size = Vector2(width - 28, list_height)
		detail_panel.position = Vector2(14, 78 + list_height)
		detail_panel.size = Vector2(width - 28, height - list_height - 92)
	else:
		var list_width := clampf(width * 0.30, 270.0, 330.0)
		roster_panel.position = Vector2(18, 72)
		roster_panel.size = Vector2(list_width, height - 90)
		detail_panel.position = Vector2(30 + list_width, 72)
		detail_panel.size = Vector2(width - list_width - 48, height - 90)
	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(22, 15) * scale_factor
	_title.size = Vector2(width - 150, 38)
	_close_button.scale = Vector2.ONE * scale_factor
	_close_button.position = origin + Vector2(width - 102, 14) * scale_factor
	_close_button.size = Vector2(80, 40)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 42
	SKIN.apply_button(button, accent)
	return button
