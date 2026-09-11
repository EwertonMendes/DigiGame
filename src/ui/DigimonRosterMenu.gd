extends Control
class_name DigimonRosterMenu

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")

var _database: DigimonDatabase
var _progression: DigimonProgressionService
var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _account: Label
var _close_button: Button
var _roster_panel: PanelContainer
var _roster_scroll: ScrollContainer
var _roster_grid: GridContainer
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_list: VBoxContainer
var _section_grid: GridContainer
var _buttons: Array[Button] = []
var _walk_previews: Array[DigimonWalkPreview] = []
var _adaptive_stat_grids: Array[GridContainer] = []
var _selected_index := 0
var _last_compact := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_progression = ProgressionServiceScript.new(_database) as DigimonProgressionService
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
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "DigimonMenuPanel"
	_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.GOLD, 14))
	add_child(_panel)

	_title = _label("DIGIMON", 25, UI.TEXT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)

	_account = _label("", 12, UI.MUTED, true)
	_account.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_account)

	_close_button = _button("CLOSE", UI.MUTED)
	_close_button.pressed.connect(func(): close_requested.emit())
	add_child(_close_button)

	_roster_panel = PanelContainer.new()
	_roster_panel.name = "RosterPanel"
	_roster_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.80, 10))
	add_child(_roster_panel)
	var roster_margin := _margin(12, 12, 12, 12)
	_roster_panel.add_child(roster_margin)
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_margin.add_child(_roster_scroll)
	_roster_grid = GridContainer.new()
	_roster_grid.columns = 1
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_scroll.add_child(_roster_grid)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.80, 10))
	add_child(_detail_panel)
	var detail_margin := _margin(18, 18, 18, 18)
	_detail_panel.add_child(detail_margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	_detail_list = VBoxContainer.new()
	_detail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_list.add_theme_constant_override("separation", 12)
	_detail_scroll.add_child(_detail_list)


func _refresh_roster() -> void:
	if _roster_grid == null:
		return
	for child in _roster_grid.get_children():
		child.queue_free()
	_buttons.clear()
	_walk_previews.clear()
	var roster: Array[DigimonInstance] = OverworldState.get_roster_instances()
	_selected_index = clampi(_selected_index, 0, maxi(0, roster.size() - 1))
	for index in range(roster.size()):
		var instance: DigimonInstance = roster[index]
		var species: Dictionary = _database.get_by_seed(instance.species_seed)
		var card := _roster_button(instance, species, index)
		_roster_grid.add_child(card)
	_update_account()
	_refresh_details()
	_style_roster_selection()


func _roster_button(instance: DigimonInstance, species: Dictionary, index: int) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := UI.rank_color(rank)
	var selected := index == _selected_index
	var button := Button.new()
	button.name = "Roster%02d" % index
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(236.0, 82.0)
	button.clip_contents = true
	button.pressed.connect(_select_index.bind(index))
	button.focus_entered.connect(_select_index.bind(index))
	_style_roster_button(button, selected, rank_color)

	var margin := _margin(10, 9, 10, 9)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(62.0, 62.0)
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	row.add_child(preview)
	_walk_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name_label := _label(display_name, 16, UI.TEXT, true)
	name_label.clip_text = true
	copy.add_child(name_label)
	var sub := _label("LV %d  ·  %s" % [instance.level, rank.to_upper()], 11, rank_color.lightened(0.12), true)
	sub.clip_text = true
	copy.add_child(sub)
	var xp_required := _progression.exp_to_next_level(instance)
	var progress := _mini_progress(UI.GOLD if selected else rank_color)
	progress.max_value = maxf(1.0, float(xp_required))
	progress.value = float(instance.exp if xp_required > 0 else xp_required)
	progress.custom_minimum_size = Vector2(90.0, 5.0)
	copy.add_child(progress)

	_buttons.append(button)
	return button


func _select_index(index: int) -> void:
	if index < 0 or index >= OverworldState.get_roster_instances().size():
		return
	if _selected_index == index and _detail_list.get_child_count() > 0:
		_style_roster_selection()
		return
	_selected_index = index
	_style_roster_selection()
	_refresh_details()


func _style_roster_selection() -> void:
	var roster: Array[DigimonInstance] = OverworldState.get_roster_instances()
	for index in range(_buttons.size()):
		var rank_color := UI.CYAN
		if index < roster.size():
			var species := _database.get_by_seed(roster[index].species_seed)
			rank_color = UI.rank_color(String(species.get("rank", "Unknown")))
		var selected := index == _selected_index
		_style_roster_button(_buttons[index], selected, rank_color)
		if index < _walk_previews.size():
			_walk_previews[index].set_active(selected)


func _refresh_details() -> void:
	if _detail_list == null:
		return
	for child in _detail_list.get_children():
		child.queue_free()
	_adaptive_stat_grids.clear()
	_section_grid = null
	var roster: Array[DigimonInstance] = OverworldState.get_roster_instances()
	if roster.is_empty():
		var empty := _label("No Digimon in roster.", 16, UI.MUTED)
		empty.custom_minimum_size.y = 120.0
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detail_list.add_child(empty)
		return
	var instance: DigimonInstance = roster[clampi(_selected_index, 0, roster.size() - 1)]
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	_build_hero(instance, species)
	_section_grid = GridContainer.new()
	_section_grid.columns = 2
	_section_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_grid.add_theme_constant_override("h_separation", 12)
	_section_grid.add_theme_constant_override("v_separation", 12)
	_detail_list.add_child(_section_grid)
	_section_grid.add_child(_build_stats_card(instance))
	_section_grid.add_child(_build_development_card(instance))
	_section_grid.add_child(_build_skills_card(instance))
	_section_grid.add_child(_build_evolution_card(instance))
	_apply_adaptive_detail_layout(UI.is_compact(get_viewport(), 840.0))


func _build_hero(instance: DigimonInstance, species: Dictionary) -> Control:
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var hero := PanelContainer.new()
	hero.name = "IdentityCard"
	hero.add_theme_stylebox_override("panel", _card_style(accent, true))
	_detail_list.add_child(hero)
	var margin := _margin(16, 14, 16, 14)
	hero.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(176.0, 154.0)
	portrait_frame.add_theme_stylebox_override("panel", _portrait_style(accent))
	row.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(154.0, 136.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 6)
	row.add_child(summary)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	summary.add_child(heading_row)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var heading := _label(display_name.to_upper(), 27, UI.TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.clip_text = true
	heading_row.add_child(heading)
	var rank_chip := _chip(rank.to_upper(), accent)
	heading_row.add_child(rank_chip)

	var identity := _label("%s  ·  %s" % [
		String(species.get("type", species.get("attribute", "Free"))).to_upper(),
		String(species.get("family", species.get("species", "Unknown"))).to_upper(),
	], 11, UI.MUTED, true)
	summary.add_child(identity)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	summary.add_child(level_row)
	level_row.add_child(_label("LEVEL %d" % instance.level, 21, UI.GOLD, true))
	var potential_chip := _chip("POTENTIAL %d" % instance.potential, UI.PURPLE)
	level_row.add_child(potential_chip)

	var required := _progression.exp_to_next_level(instance)
	var xp_copy := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_line := HBoxContainer.new()
	xp_line.add_theme_constant_override("separation", 10)
	summary.add_child(xp_line)
	var xp_caption := _label("NEXT LEVEL", 10, UI.SUBTLE, true)
	xp_caption.custom_minimum_size.x = 78.0
	xp_line.add_child(xp_caption)
	var xp_bar := _mini_progress(UI.GOLD)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	xp_line.add_child(xp_bar)
	var xp_value := _label(xp_copy, 11, UI.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_value.custom_minimum_size.x = 86.0
	xp_line.add_child(xp_value)

	var hint := _label("Field portrait · live animation", 10, UI.SUBTLE)
	hint.tooltip_text = "The large portrait uses the animated WebP-derived portrait frames used by the battle UI."
	summary.add_child(hint)
	return hero


func _build_stats_card(instance: DigimonInstance) -> Control:
	var card := _section_card("COMBAT STATS", UI.CYAN)
	var body := card.get_meta("body") as VBoxContainer
	var stats := _progression.get_final_stats(instance)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	_adaptive_stat_grids.append(grid)
	for entry in [
		["HP", "hp", UI.GREEN], ["SP", "sp", UI.BLUE.lightened(0.12)],
		["ATK", "atk", UI.GOLD], ["DEF", "def", UI.CYAN],
		["INT", "int", UI.PURPLE], ["SPD", "speed", UI.ORANGE], ["MOV", "mov", UI.TEXT],
	]:
		grid.add_child(_stat_tile(String(entry[0]), int(stats.get(String(entry[1]), 0)), entry[2] as Color))
	return card


func _build_development_card(instance: DigimonInstance) -> Control:
	var card := _section_card("DEVELOPMENT", UI.PURPLE)
	var body := card.get_meta("body") as VBoxContainer
	body.add_child(_label("Innate aptitude + permanent training", 10, UI.SUBTLE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for header in ["STAT", "APT", "TRAIN"]:
		grid.add_child(_label(header, 9, UI.SUBTLE, true))
	for key in ["hp", "mp", "atk", "def", "int", "speed", "mov"]:
		var aptitude := int(instance.aptitudes.get(key, 0))
		var training := int(instance.training.get(key, 0))
		grid.add_child(_label("SP" if key == "mp" else key.to_upper(), 11, UI.TEXT, true))
		grid.add_child(_label("%+d%%" % aptitude, 11, UI.CYAN if aptitude >= 0 else UI.RED, true))
		grid.add_child(_label("+%d" % training, 11, UI.GOLD if training > 0 else UI.MUTED, true))
	return card


func _build_skills_card(instance: DigimonInstance) -> Control:
	var card := _section_card("SKILLS", UI.GOLD)
	var body := card.get_meta("body") as VBoxContainer
	body.add_child(_subheading("EQUIPPED", UI.GOLD))
	body.add_child(_wrapped_value(", ".join(instance.equipped_skills) if not instance.equipped_skills.is_empty() else "None equipped", UI.TEXT))
	body.add_child(_subheading("LEARNED", UI.CYAN))
	body.add_child(_wrapped_value(", ".join(instance.learned_skills) if not instance.learned_skills.is_empty() else "No learned techniques", UI.MUTED))
	return card


func _build_evolution_card(instance: DigimonInstance) -> Control:
	var card := _section_card("EVOLUTION PATHS", UI.GREEN)
	var body := card.get_meta("body") as VBoxContainer
	var evolutions: Array[Dictionary] = _progression.get_evolution_routes(instance)
	var degenerations: Array[Dictionary] = _progression.get_degeneration_routes(instance)
	if evolutions.is_empty() and degenerations.is_empty():
		body.add_child(_wrapped_value("No evolution routes registered for this form.", UI.MUTED))
		return card
	if not evolutions.is_empty():
		body.add_child(_subheading("DIGIVOLVE", UI.GREEN))
		for route: Dictionary in evolutions:
			body.add_child(_route_row(route, true))
	if not degenerations.is_empty():
		body.add_child(_subheading("DEGENERATE", UI.CYAN))
		for route: Dictionary in degenerations:
			body.add_child(_route_row(route, false))
	return card


func _route_row(route: Dictionary, show_lock: bool) -> Control:
	var unlocked := bool(route.get("unlocked", true))
	var accent := UI.GREEN if unlocked else UI.SUBTLE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _route_style(accent, unlocked))
	var margin := _margin(9, 6, 9, 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	if show_lock:
		row.add_child(_chip("READY" if unlocked else "LOCKED", accent))
	var target := _label(String(route.get("targetName", "Unknown")), 11, UI.TEXT, true)
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.clip_text = true
	row.add_child(target)
	var requirement := _label(_requirements_copy(route.get("requirements", [])), 9, UI.MUTED)
	requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	requirement.custom_minimum_size.x = 110.0
	row.add_child(requirement)
	return panel


func _section_card(title: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style(accent, false))
	var margin := _margin(13, 11, 13, 11)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)
	var heading := _label(title, 11, accent.lightened(0.10), true)
	body.add_child(heading)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1.0
	divider.color = UI.separator(accent, 0.20)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(divider)
	panel.set_meta("body", body)
	return panel


func _stat_tile(label_text: String, value: int, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112.0, 54.0)
	panel.add_theme_stylebox_override("panel", _stat_style(accent))
	var margin := _margin(10, 6, 10, 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	margin.add_child(box)
	box.add_child(_label(label_text, 9, UI.SUBTLE, true))
	box.add_child(_label(str(value), 18, UI.TEXT, true))
	return panel


func _subheading(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent.lightened(0.10), true)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _wrapped_value(text: String, color: Color) -> Label:
	var label := _label(text, 11, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 32.0
	return label


func _requirements_copy(raw_requirements) -> String:
	if not raw_requirements is Array or (raw_requirements as Array).is_empty():
		return "No extra req."
	var parts: Array[String] = []
	for raw in raw_requirements:
		if raw is Dictionary:
			var type_name := String(raw.get("type", "")).to_upper()
			var value := str(raw.get("value", ""))
			parts.append("%s %s" % [type_name, value])
	return " · ".join(parts)


func _layout() -> void:
	if _panel == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 840.0)
	var edge := 12.0 if compact else 18.0
	var width := minf(1240.0, physical.x - edge * 2.0)
	var height := minf(760.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = origin
	_panel.size = Vector2(width, height)
	var header_h := 68.0

	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(24.0, 18.0) * scale_factor
	_title.size = Vector2(240.0, 36.0)
	_account.scale = Vector2.ONE * scale_factor
	_account.position = origin + Vector2(width - 360.0, 21.0) * scale_factor
	_account.size = Vector2(220.0, 26.0)
	_close_button.scale = Vector2.ONE * scale_factor
	_close_button.position = origin + Vector2(width - 112.0, 14.0) * scale_factor
	_close_button.size = Vector2(88.0, 40.0)

	_roster_panel.scale = Vector2.ONE * scale_factor
	_detail_panel.scale = Vector2.ONE * scale_factor
	if compact:
		var roster_h := minf(198.0, height * 0.30)
		_roster_panel.position = origin + Vector2(16.0, header_h) * scale_factor
		_roster_panel.size = Vector2(width - 32.0, roster_h)
		_detail_panel.position = origin + Vector2(16.0, header_h + roster_h + 10.0) * scale_factor
		_detail_panel.size = Vector2(width - 32.0, height - header_h - roster_h - 26.0)
		_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_grid.columns = 2 if width < 620.0 else 3
	else:
		var roster_w := clampf(width * 0.255, 270.0, 320.0)
		_roster_panel.position = origin + Vector2(16.0, header_h) * scale_factor
		_roster_panel.size = Vector2(roster_w, height - header_h - 16.0)
		_detail_panel.position = origin + Vector2(28.0 + roster_w, header_h) * scale_factor
		_detail_panel.size = Vector2(width - roster_w - 44.0, height - header_h - 16.0)
		_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_grid.columns = 1

	_apply_adaptive_detail_layout(compact)
	if compact != _last_compact:
		_last_compact = compact
		call_deferred("_refresh_details")


func _apply_adaptive_detail_layout(compact: bool) -> void:
	if _section_grid != null:
		_section_grid.columns = 1 if compact else 2
	for grid in _adaptive_stat_grids:
		if grid != null:
			grid.columns = 2 if compact else 4


func _update_account() -> void:
	if _account != null:
		_account.text = "%d BITS" % OverworldState.get_bits()


func _on_account_rewards_changed(_bits: int, _digi_data: Dictionary) -> void:
	_update_account()


func _label(text: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if font_size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _chip(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent.lightened(0.12), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", UI.pill(accent, 0.12))
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", UI.command_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.command_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.command_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", UI.command_style(accent, "pressed"))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_focus_color", UI.TEXT)
	return button


func _style_roster_button(button: Button, selected: bool, rank_color: Color) -> void:
	var accent := UI.GOLD if selected else rank_color
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.action_style(UI.GOLD, "focus"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_color_override("font_color", UI.TEXT)


func _mini_progress(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.01, 0.01, 0.015, 0.88)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _card_style(accent: Color, strong: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.014, 0.020, 0.90 if strong else 0.72)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.48 if strong else 0.22)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style


func _portrait_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.36)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _stat_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.26)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.22)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _route_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.24)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.38 if active else 0.18)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
