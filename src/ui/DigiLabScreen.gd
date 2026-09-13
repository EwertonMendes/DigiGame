extends Control
class_name DigiLabScreen

signal close_requested
signal reconstructed(instance: DigimonInstance)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
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
	_refresh()
	call_deferred("_layout")

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
	_backdrop.color = Color(0.004, 0.012, 0.030, 0.97)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.08, 0.14, 0.22, 0.99), Vector4.ZERO, 14.0))
	add_child(_frame)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_bottom", 20)
	_frame.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	_title = _label("DIGILAB", 24, UI.TEXT, true)
	heading.add_child(_title)
	_subtitle = _label("Reconstruct Digimon from species Digi Data", 11, UI.MUTED)
	heading.add_child(_subtitle)
	_close_button = _icon_button(CLOSE_ICON, UI.MUTED, "Close")
	_close_button.custom_minimum_size = Vector2(44, 44)
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
	_list_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.CYAN, Vector4(12, 12, 12, 12), 10.0))
	_body_grid.add_child(_list_panel)
	var list_root := VBoxContainer.new()
	list_root.add_theme_constant_override("separation", 8)
	_list_panel.add_child(list_root)
	list_root.add_child(_section_label("DIGI DATA ARCHIVE", UI.CYAN))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_root.add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list_box)

	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.GOLD, Vector4(14, 14, 14, 14), 10.0))
	_body_grid.add_child(_detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detail_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 9)
	detail_scroll.add_child(_detail_body)

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
	var button := _button("%s\n%s   %d DATA" % [species_name.to_upper(), rank.to_upper(), amount], accent)
	button.custom_minimum_size = Vector2(0, 58)
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
		SKIN.apply_button(button, accent)
		if species_name.to_lower() == _selected_name.to_lower():
			button.add_theme_stylebox_override("normal", SKIN.border_style(UI.GOLD, Vector4(14, 9, 14, 9), 10.0))

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
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	_detail_body.add_child(hero)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(132, 118)
	portrait_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.96), Vector4(6, 6, 6, 6), 9.0))
	hero.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(124, 110)
	portrait.set_species(canonical_name)
	portrait_frame.add_child(portrait)
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
	_announcement.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_announcement, "modulate:a", 1.0, 0.16)
	tween.tween_property(_announcement, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.75).timeout
	var out := create_tween()
	out.tween_property(_announcement, "modulate:a", 0.0, 0.28)
	await out.finished
	_announcement.visible = false

func _on_data_changed(_bits: int, _data: Dictionary) -> void:
	if visible:
		_refresh()

func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var edge := 12.0
	var width := minf(1080.0, physical.x - edge * 2.0)
	var height := minf(700.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)
	var compact := width < 820.0 or height < 560.0
	_body_grid.columns = 1 if compact else 2
	if compact:
		_list_panel.custom_minimum_size = Vector2(0, 180)
		_detail_panel.custom_minimum_size = Vector2(0, 300)
	else:
		_list_panel.custom_minimum_size = Vector2(300, 0)
		_detail_panel.custom_minimum_size = Vector2(600, 0)
	_announcement.scale = Vector2.ONE * scale_factor
	_announcement.position = origin + Vector2(width * 0.20, 74) * scale_factor
	_announcement.size = Vector2(width * 0.60, 42)

func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent, true)
	label.custom_minimum_size.y = 22
	return label

func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 42
	SKIN.apply_button(button, accent)
	return button

func _icon_button(icon_texture: Texture2D, accent: Color, tooltip: String) -> Button:
	var button := _button("", accent)
	button.icon = icon_texture
	button.expand_icon = true
	button.tooltip_text = tooltip
	return button
