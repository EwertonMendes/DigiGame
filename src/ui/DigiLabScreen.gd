extends Control
class_name DigiLabScreen

signal close_requested
signal reconstructed(instance: DigimonInstance)

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")

var _database: DigimonDatabase
var _factory: DigimonFactory
var _selected_name := ""
var _data_buttons: Array[Button] = []

var _backdrop: ColorRect
var _frame: PanelContainer
var _body_grid: GridContainer
var _title: Label
var _subtitle: Label
var _close_button: Button
var _list_panel: PanelContainer
var _list_scroll: ScrollContainer
var _list_box: VBoxContainer
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
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
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "DigiLabScreenPanel"
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
	_title = _label("CONVERT DIGI DATA", 25, UI.TEXT, true)
	heading.add_child(_title)
	_subtitle = _label("Reconstruct Digimon from species Digi Data", 11, UI.MUTED)
	heading.add_child(_subtitle)
	_close_button = MENU.icon_button(CLOSE_ICON, UI.MUTED, "Close", Vector2(44, 44))
	_close_button.pressed.connect(close_view)
	header.add_child(_close_button)

	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_grid.add_theme_constant_override("h_separation", 12)
	_body_grid.add_theme_constant_override("v_separation", 12)
	root.add_child(_body_grid)

	_list_panel = PanelContainer.new()
	_list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_panel.clip_contents = true
	_list_panel.add_theme_stylebox_override("panel", MENU.surface(UI.CYAN, 0.80, 10))
	_body_grid.add_child(_list_panel)
	var list_margin := MENU.margin(12, 12, 12, 12)
	_list_panel.add_child(list_margin)
	var list_root := VBoxContainer.new()
	list_root.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_root)
	list_root.add_child(_section_label("DIGI DATA ARCHIVE", UI.CYAN))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_list_scroll.follow_focus = true
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_root.add_child(_list_scroll)
	SmoothScrollScript.attach(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_list_box)

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
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail_body)

	_announcement = _label("", 18, UI.GREEN, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announcement.visible = false
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announcement)

func _refresh() -> void:
	_refresh_list()
	_refresh_detail()

func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_data_buttons.clear()
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
	if entries.is_empty():
		_empty_label = _label("No Digi Data yet. Defeat Digimon in battle to discover reconstruction data.", 12, UI.MUTED)
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
		if name.to_lower() == _selected_name.to_lower():
			selection_still_exists = true
		var button := _data_button(name, amount)
		_list_box.add_child(button)
		_data_buttons.append(button)
	if not selection_still_exists:
		_selected_name = String(entries[0].get("name", ""))
	_style_selection()

func _data_button(species_name: String, amount: int) -> Button:
	var species := _database.get_by_name(species_name)
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var button := _button("%s\n%s  ·  %d DATA" % [species_name.to_upper(), rank.to_upper(), amount], accent)
	button.custom_minimum_size.y = 60
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_select_species.bind(species_name))
	button.focus_entered.connect(_select_species.bind(species_name))
	button.set_meta("species_name", species_name)
	return button

func _select_species(species_name: String) -> void:
	if _selected_name.to_lower() == species_name.to_lower() and _detail_body.get_child_count() > 0:
		return
	_selected_name = species_name
	_style_selection()
	_refresh_detail()

func _style_selection() -> void:
	for button: Button in _data_buttons:
		var species_name := String(button.get_meta("species_name", ""))
		var species := _database.get_by_name(species_name)
		var accent := UI.rank_color(String(species.get("rank", "Unknown")))
		var selected := species_name.to_lower() == _selected_name.to_lower()
		MENU.style_action_button(button, UI.GOLD if selected else accent, selected)

func _focus_selected_data() -> void:
	if not visible:
		return
	for button: Button in _data_buttons:
		if String(button.get_meta("species_name", "")).to_lower() == _selected_name.to_lower():
			button.grab_focus()
			return
	if not _data_buttons.is_empty():
		_data_buttons[0].grab_focus()

func _refresh_detail() -> void:
	for child in _detail_body.get_children():
		child.queue_free()
	if _selected_name.is_empty():
		_detail_body.add_child(_label("Select a species to inspect its reconstruction progress.", 12, UI.MUTED))
		return
	var species := _database.get_by_name(_selected_name)
	if species.is_empty():
		return
	var canonical_name := String(species.get("name", _selected_name))
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var available := OverworldState.get_digi_data_for(canonical_name)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MENU.card(accent, true))
	_detail_body.add_child(card)
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
	portrait.set_species(canonical_name)
	portrait_margin.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 5)
	hero.add_child(info)
	info.add_child(_label(canonical_name.to_upper(), 21, UI.TEXT, true))
	info.add_child(_label(rank.to_upper(), 11, accent.lightened(0.14), true))
	info.add_child(_label("%d DIGI DATA" % available, 18, UI.GOLD, true))
	_detail_body.add_child(_section_label("RECONSTRUCTION", UI.CYAN))
	_detail_body.add_child(_label("Spend collected Data to create a new Level 1 individual in Storage.", 11, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_detail_body.add_child(grid)
	for amount in [100, 150, 200]:
		var potential := _factory.potential_from_scan_percent(amount)
		var button := _button("%d DATA\n+%d POTENTIAL" % [amount, potential], UI.GOLD if amount == 200 else UI.CYAN)
		button.custom_minimum_size = Vector2(120, 62)
		button.disabled = available < amount
		button.tooltip_text = "Need %d more Digi Data." % (amount - available) if available < amount else "Reconstruct %s." % canonical_name
		button.pressed.connect(_reconstruct.bind(canonical_name, amount))
		grid.add_child(button)

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

func _on_data_changed(_bits: int, _data: Dictionary) -> void:
	if visible:
		_refresh()

func _layout() -> void:
	if not visible or _frame == null:
		return
	var layout := MENU.apply_safe_frame(_frame, get_viewport(), Vector2(1240, 720), 840.0)
	var compact := bool(layout.get("compact", false))
	_body_grid.columns = 1 if compact else 2
	if compact:
		_list_panel.custom_minimum_size = Vector2(0, 170)
		_detail_panel.custom_minimum_size = Vector2(0, 0)
	else:
		_list_panel.custom_minimum_size = Vector2(300, 0)
		_detail_panel.custom_minimum_size = Vector2(0, 0)
	var scale_factor := float(layout.get("scale", 1.0))
	var origin := Vector2(layout.get("position", Vector2.ZERO))
	var frame_size := Vector2(layout.get("size", Vector2(1240, 720)))
	_announcement.scale = Vector2.ONE * scale_factor
	_announcement.position = origin + Vector2(frame_size.x * 0.20, 72) * scale_factor
	_announcement.size = Vector2(frame_size.x * 0.60, 42)

func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent.lightened(0.08), true)
	label.custom_minimum_size.y = 22
	return label

func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if font_size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _button(text: String, accent: Color) -> Button:
	return MENU.action_button(text, accent)
