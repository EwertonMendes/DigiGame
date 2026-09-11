extends Control
class_name DigimonRosterMenu

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database
var _progression
var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _account: Label
var _close_button: Button
var _roster_panel: PanelContainer
var _roster_scroll: ScrollContainer
var _roster_list: VBoxContainer
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_list: VBoxContainer
var _buttons: Array[Button] = []
var _selected_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database()
	_progression = ProgressionServiceScript.new(_database)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_layout)
	OverworldState.roster_changed.connect(_refresh_roster)
	OverworldState.account_rewards_changed.connect(_on_account_rewards_changed)
	_refresh_roster()
	call_deferred("_layout")


func open_menu() -> void:
	visible = true
	_refresh_roster()
	if not _buttons.is_empty():
		_buttons[clampi(_selected_index, 0, _buttons.size() - 1)].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.74)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "DigimonMenuPanel"
	_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.GOLD, 12))
	add_child(_panel)

	_title = _label("DIGIMON", 24, UI.TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)
	_account = _label("", 12, UI.MUTED)
	_account.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_account)

	_close_button = _button("CLOSE", UI.MUTED)
	_close_button.pressed.connect(func(): close_requested.emit())
	add_child(_close_button)

	_roster_panel = PanelContainer.new()
	_roster_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.74, 8))
	add_child(_roster_panel)
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roster_panel.add_child(_roster_scroll)
	_roster_list = VBoxContainer.new()
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list.add_theme_constant_override("separation", 8)
	_roster_scroll.add_child(_roster_list)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.74, 8))
	add_child(_detail_panel)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_panel.add_child(_detail_scroll)
	_detail_list = VBoxContainer.new()
	_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_list.add_theme_constant_override("separation", 9)
	_detail_scroll.add_child(_detail_list)


func _refresh_roster() -> void:
	if _roster_list == null:
		return
	for child in _roster_list.get_children():
		child.queue_free()
	_buttons.clear()
	var roster: Array[DigimonInstance] = OverworldState.get_roster_instances()
	_selected_index = clampi(_selected_index, 0, maxi(0, roster.size() - 1))
	for index in range(roster.size()):
		var instance: DigimonInstance = roster[index]
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var button := _button("%s\nLV %d  ·  %s" % [
			instance.get_display_name(String(species.get("name", "Unknown"))),
			instance.level,
			String(species.get("rank", "")),
		], UI.GOLD if index == _selected_index else UI.CYAN)
		button.name = "Roster%02d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(210.0, 64.0)
		button.pressed.connect(_select_index.bind(index))
		button.focus_entered.connect(_select_index.bind(index))
		_roster_list.add_child(button)
		_buttons.append(button)
	_update_account()
	_refresh_details()


func _select_index(index: int) -> void:
	if index < 0 or index >= OverworldState.get_roster_instances().size():
		return
	_selected_index = index
	for button_index in range(_buttons.size()):
		_style_button(_buttons[button_index], UI.GOLD if button_index == _selected_index else UI.CYAN)
	_refresh_details()


func _refresh_details() -> void:
	if _detail_list == null:
		return
	for child in _detail_list.get_children():
		child.queue_free()
	var roster: Array[DigimonInstance] = OverworldState.get_roster_instances()
	if roster.is_empty():
		_detail_list.add_child(_label("No Digimon in roster.", 16, UI.MUTED))
		return
	var instance: DigimonInstance = roster[clampi(_selected_index, 0, roster.size() - 1)]
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var heading := _label(display_name.to_upper(), 28, UI.TEXT)
	_detail_list.add_child(heading)
	_detail_list.add_child(_label("%s  ·  %s  ·  %s" % [
		String(species.get("rank", "Unknown")),
		String(species.get("type", species.get("attribute", "Free"))),
		String(species.get("family", species.get("species", "Unknown"))),
	], 13, UI.CYAN))

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	_detail_list.add_child(top_row)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(112.0, 112.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var species_key := String(species.get("name", "")).to_lower()
	var resource_path := "res://assets/resources/%s.tres" % species_key
	if ResourceLoader.exists(resource_path):
		var resource = load(resource_path)
		if resource != null:
			portrait.texture = resource.get("texture")
	top_row.add_child(portrait)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(summary)
	summary.add_child(_label("LEVEL %d" % instance.level, 22, UI.GOLD))
	var required := _progression.exp_to_next_level(instance)
	var xp_copy := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	summary.add_child(_label(xp_copy, 13, UI.MUTED))
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(240.0, 12.0)
	xp_bar.show_percentage = false
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	summary.add_child(xp_bar)
	summary.add_child(_label("POTENTIAL  %d / 100" % instance.potential, 15, UI.PURPLE))
	summary.add_child(_label("ID  %s" % instance.id.substr(0, 8).to_upper(), 11, UI.SUBTLE))

	_add_section("COMBAT STATS")
	var stats: Dictionary = _progression.get_final_stats(instance)
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 22)
	stat_grid.add_theme_constant_override("v_separation", 5)
	_detail_list.add_child(stat_grid)
	for entry in [
		["HP", "hp"], ["SP", "sp"], ["ATK", "atk"], ["DEF", "def"],
		["INT", "int"], ["SPD", "speed"], ["MOV", "mov"],
	]:
		stat_grid.add_child(_label(String(entry[0]), 13, UI.MUTED))
		stat_grid.add_child(_label(str(int(stats.get(String(entry[1]), 0))), 15, UI.TEXT))

	_add_section("DEVELOPMENT")
	_detail_list.add_child(_label("Aptitudes are small innate ±3% modifiers. Training is permanent across forms.", 12, UI.SUBTLE, true))
	_detail_list.add_child(_label(_development_copy(instance), 13, UI.TEXT, true))

	_add_section("SKILLS")
	var equipped := " · ".join(instance.equipped_skills) if not instance.equipped_skills.is_empty() else "None equipped"
	var learned := " · ".join(instance.learned_skills) if not instance.learned_skills.is_empty() else "No learned techniques"
	_detail_list.add_child(_label("Equipped: %s" % equipped, 13, UI.GOLD, true))
	_detail_list.add_child(_label("Learned: %s" % learned, 12, UI.MUTED, true))

	_add_section("DIGIVOLUTION")
	var routes: Array[Dictionary] = _progression.get_evolution_routes(instance)
	if routes.is_empty():
		_detail_list.add_child(_label("No further Digivolution route registered for this form.", 12, UI.MUTED, true))
	else:
		for route: Dictionary in routes:
			var unlocked := bool(route.get("unlocked", false))
			var prefix := "READY" if unlocked else "LOCKED"
			var color := UI.GREEN if unlocked else UI.SUBTLE
			_detail_list.add_child(_label("%s  ·  %s (%s)  —  %s" % [
				prefix,
				String(route.get("targetName", "Unknown")),
				String(route.get("targetRank", "")),
				_requirements_copy(route.get("requirements", [])),
			], 12, color, true))

	var degenerations: Array[Dictionary] = _progression.get_degeneration_routes(instance)
	if not degenerations.is_empty():
		_add_section("DEGENERATION")
		for route: Dictionary in degenerations:
			_detail_list.add_child(_label("%s (%s)" % [
				String(route.get("targetName", "Unknown")),
				String(route.get("targetRank", "")),
			], 12, UI.CYAN))


func _development_copy(instance: DigimonInstance) -> String:
	var parts: Array[String] = []
	for key in ["hp", "mp", "atk", "def", "int", "speed"]:
		var aptitude := int(instance.aptitudes.get(key, 0))
		var training := int(instance.training.get(key, 0))
		if aptitude != 0 or training != 0:
			parts.append("%s  aptitude %+d%%  training +%d" % [String(key).to_upper(), aptitude, training])
	var mov_training := int(instance.training.get("mov", 0))
	if mov_training > 0:
		parts.append("MOV training +%d" % mov_training)
	return "\n".join(parts) if not parts.is_empty() else "No specialized training yet."


func _requirements_copy(raw_requirements) -> String:
	if not raw_requirements is Array or (raw_requirements as Array).is_empty():
		return "No extra requirement"
	var parts: Array[String] = []
	for raw in raw_requirements:
		if raw is Dictionary:
			parts.append("%s %s" % [String(raw.get("type", "")).to_upper(), str(raw.get("value", ""))])
	return ", ".join(parts)


func _add_section(text: String) -> void:
	var label := _label(text, 12, UI.GOLD)
	label.add_theme_constant_override("outline_size", 3)
	_detail_list.add_child(label)


func _layout() -> void:
	if _panel == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 840.0)
	var edge := 14.0
	var width := minf(1120.0, physical.x - edge * 2.0)
	var height := minf(680.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = origin
	_panel.size = Vector2(width, height)
	var header_h := 64.0
	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(24.0, 18.0) * scale_factor
	_title.size = Vector2(240.0, 34.0)
	_account.scale = Vector2.ONE * scale_factor
	_account.position = origin + Vector2(width - 430.0, 21.0) * scale_factor
	_account.size = Vector2(300.0, 26.0)
	_close_button.scale = Vector2.ONE * scale_factor
	_close_button.position = origin + Vector2(width - 112.0, 14.0) * scale_factor
	_close_button.size = Vector2(88.0, 38.0)

	_roster_panel.scale = Vector2.ONE * scale_factor
	_detail_panel.scale = Vector2.ONE * scale_factor
	if compact:
		var roster_h := minf(172.0, height * 0.30)
		_roster_panel.position = origin + Vector2(18.0, header_h) * scale_factor
		_roster_panel.size = Vector2(width - 36.0, roster_h)
		_detail_panel.position = origin + Vector2(18.0, header_h + roster_h + 10.0) * scale_factor
		_detail_panel.size = Vector2(width - 36.0, height - header_h - roster_h - 28.0)
	else:
		var roster_w := minf(270.0, width * 0.28)
		_roster_panel.position = origin + Vector2(18.0, header_h) * scale_factor
		_roster_panel.size = Vector2(roster_w, height - header_h - 18.0)
		_detail_panel.position = origin + Vector2(28.0 + roster_w, header_h) * scale_factor
		_detail_panel.size = Vector2(width - roster_w - 46.0, height - header_h - 18.0)


func _update_account() -> void:
	if _account != null:
		_account.text = "%d BITS  ·  %d DATA TYPES" % [OverworldState.get_bits(), OverworldState.get_digi_data().size()]


func _on_account_rewards_changed(_bits: int, _digi_data: Dictionary) -> void:
	_update_account()


func _label(text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	_style_button(button, accent)
	return button


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", UI.command_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.command_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.command_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", UI.command_style(accent, "pressed"))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_focus_color", UI.TEXT)
