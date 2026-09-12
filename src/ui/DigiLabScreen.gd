extends Control
class_name DigiLabScreen

signal close_requested
signal reconstructed(instance: DigimonInstance)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")

var _database: DigimonDatabase
var _factory: DigimonFactory
var _selected_name := ""
var _data_buttons: Array[Button] = []

var _backdrop: ColorRect
var _frame: PanelContainer
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
	_backdrop.color = Color(0.008, 0.020, 0.044, 0.97)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.10, 0.17, 0.24, 0.98), Vector4.ZERO, 14.0))
	add_child(_frame)

	_title = _label("DIGILAB", 25, UI.TEXT, true)
	add_child(_title)
	_subtitle = _label("Reconstruct new Digimon from Digi Data collected in battle", 11, UI.MUTED)
	add_child(_subtitle)
	_close_button = _button("CLOSE", UI.MUTED)
	_close_button.pressed.connect(close_view)
	add_child(_close_button)

	_list_panel = PanelContainer.new()
	_list_panel.add_theme_stylebox_override("panel", SKIN.border_style(Color(0.22, 0.58, 0.78, 0.95), Vector4(10, 10, 10, 10), 12.0))
	add_child(_list_panel)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_panel.add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 7)
	_list_scroll.add_child(_list_box)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", SKIN.border_style(UI.GOLD, Vector4(14, 14, 14, 14), 12.0))
	add_child(_detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(detail_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_detail_body)

	_announcement = _label("", 20, UI.GREEN, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.visible = false
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
		if aa == bb:
			return String(a.get("name", "")) < String(b.get("name", ""))
		return aa > bb
	)

	if entries.is_empty():
		_empty_label = _label("No Digi Data yet.\nDefeat Digimon in battle to collect reconstruction data.", 13, UI.MUTED)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_empty_label.custom_minimum_size.y = 160
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
	var button := Button.new()
	button.text = "%s\n%s  ·  %d DATA" % [species_name.to_upper(), rank.to_upper(), amount]
	button.custom_minimum_size = Vector2(238, 66)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_select_species.bind(species_name))
	button.focus_entered.connect(_select_species.bind(species_name))
	SKIN.apply_button(button, accent)
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
			button.add_theme_stylebox_override("normal", SKIN.border_style(UI.GOLD, Vector4(14, 9, 14, 9), 12.0))


func _refresh_detail() -> void:
	for child in _detail_body.get_children():
		child.queue_free()
	if _selected_name.is_empty():
		_detail_body.add_child(_label("DIGI DATA ARCHIVE", 14, UI.CYAN, true))
		_detail_body.add_child(_label("Collected species will appear here when you earn Digi Data from battle.", 11, UI.MUTED))
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
	portrait_frame.custom_minimum_size = Vector2(178, 158)
	portrait_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(accent.r * 0.40, accent.g * 0.40, accent.b * 0.40, 0.96), Vector4(7, 7, 7, 7), 10.0))
	hero.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(164, 144)
	portrait.set_species(canonical_name)
	portrait_frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	hero.add_child(info)
	info.add_child(_label(canonical_name.to_upper(), 23, UI.TEXT, true))
	info.add_child(_label(rank.to_upper(), 11, accent.lightened(0.14), true))
	info.add_child(_label("%d DIGI DATA" % available, 20, UI.GOLD, true))

	_detail_body.add_child(_section_label("RECONSTRUCTION QUALITY", UI.CYAN))
	var explainer := _label("100 Data reconstructs the Digimon. Saving more data gives the new individual a small starting Potential bonus without changing its species or evolution access.", 10, UI.MUTED)
	explainer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(explainer)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_detail_body.add_child(grid)
	for amount in [100, 150, 200]:
		var potential := _factory.potential_from_scan_percent(amount)
		var button := _button("%d DATA\n+%d POTENTIAL" % [amount, potential], UI.GOLD if amount == 200 else UI.CYAN)
		button.custom_minimum_size = Vector2(128, 66)
		button.disabled = available < amount
		button.tooltip_text = "Need %d more Digi Data." % (amount - available) if available < amount else "Reconstruct a new %s using %d Digi Data." % [canonical_name, amount]
		button.pressed.connect(_reconstruct.bind(canonical_name, amount))
		grid.add_child(button)

	_detail_body.add_child(_section_label("NEW INDIVIDUAL", UI.PURPLE))
	_detail_body.add_child(_label("The reconstructed Digimon joins your roster at Level 1. Multiple individuals of the same species are allowed.", 10, UI.MUTED))


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
	var tween := create_tween()
	tween.set_parallel(true)
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
	var compact := UI.is_compact(get_viewport(), 850.0) or physical.y > physical.x * 1.08
	var edge := 12.0 if compact else 18.0
	var width := minf(1180.0, physical.x - edge * 2.0)
	var height := minf(760.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)
	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(24, 16) * scale_factor
	_title.size = Vector2(width - 170, 34)
	_subtitle.scale = Vector2.ONE * scale_factor
	_subtitle.position = origin + Vector2(26, 45) * scale_factor
	_subtitle.size = Vector2(width - 180, 24)
	_close_button.scale = Vector2.ONE * scale_factor
	_close_button.position = origin + Vector2(width - 106, 15) * scale_factor
	_close_button.size = Vector2(84, 40)

	_list_panel.scale = Vector2.ONE * scale_factor
	_detail_panel.scale = Vector2.ONE * scale_factor
	if compact:
		var list_h := minf(210.0, height * 0.30)
		_list_panel.position = origin + Vector2(16, 76) * scale_factor
		_list_panel.size = Vector2(width - 32, list_h)
		_detail_panel.position = origin + Vector2(16, 88 + list_h) * scale_factor
		_detail_panel.size = Vector2(width - 32, height - list_h - 104)
	else:
		var list_w := clampf(width * 0.31, 280.0, 350.0)
		_list_panel.position = origin + Vector2(16, 76) * scale_factor
		_list_panel.size = Vector2(list_w, height - 92)
		_detail_panel.position = origin + Vector2(28 + list_w, 76) * scale_factor
		_detail_panel.size = Vector2(width - list_w - 44, height - 92)

	_announcement.scale = Vector2.ONE * scale_factor
	_announcement.position = origin + Vector2(width * 0.18, 78) * scale_factor
	_announcement.size = Vector2(width * 0.64, 46)


func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(110, 40)
	SKIN.apply_button(button, accent)
	return button


func _section_label(text: String, accent: Color) -> Label:
	return _label(text, 10, accent.lightened(0.14), true)
