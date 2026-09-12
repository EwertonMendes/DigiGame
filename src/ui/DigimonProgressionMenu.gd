extends "res://src/ui/DigimonRosterMenu.gd"
class_name DigimonProgressionMenu

const ProgressionUI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const EvolutionChartScript = preload("res://src/ui/EvolutionChart.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const BattleActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")

var _constellation: EvolutionChart
var _actions: BattleActionDatabase
var _menu_root: Control


func _build() -> void:
	super._build()

	_actions = BattleActionDatabaseScript.new() as BattleActionDatabase
	_actions.load_default()

	# A single clipped Kenney frame owns the complete menu. Local positioning is
	# always relative to this frame, so content cannot escape at other scales.
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(ProgressionUI.FRAME_DARK, Vector4.ZERO, 14.0)
	)
	_menu_root = Control.new()
	_menu_root.name = "MenuContent"
	_menu_root.clip_contents = true
	_panel.add_child(_menu_root)
	for control: Control in [_title, _account, _close_button, _roster_panel, _detail_panel]:
		remove_child(control)
		_menu_root.add_child(control)

	_configure_close_button(_close_button, "Close Digimon menu")

	_roster_panel.clip_contents = true
	_roster_panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.07, 0.12, 0.18, 0.98), Vector4(14, 14, 14, 14), 12.0)
	)
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.06, 0.10, 0.17, 0.98), Vector4(16, 16, 16, 16), 12.0)
	)
	_detail_scroll.clip_contents = true
	SmoothScrollScript.attach(_roster_scroll)
	SmoothScrollScript.attach(_detail_scroll)

	_constellation = EvolutionChartScript.new() as EvolutionChart
	_constellation.name = "EvolutionChart"
	_constellation.visible = false
	_constellation.close_requested.connect(_close_constellation)
	_constellation.evolution_applied.connect(_on_evolution_state_changed)
	add_child(_constellation)


func open_menu() -> void:
	if _constellation != null:
		_constellation.visible = false
	super.open_menu()


func has_nested_view_open() -> bool:
	return _constellation != null and _constellation.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _constellation != null and _constellation.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_close_constellation()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _build_hero(instance: DigimonInstance, species: Dictionary) -> Control:
	var rank := String(species.get("rank", "Unknown"))
	var accent := ProgressionUI.rank_color(rank)
	var hero := PanelContainer.new()
	hero.name = "IdentityCard"
	hero.clip_contents = true
	hero.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.08, 0.13, 0.20, 0.98), Vector4.ZERO, 12.0)
	)
	_detail_list.add_child(hero)

	var hero_margin := _margin(18, 16, 18, 16)
	hero.add_child(hero_margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	hero_margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(164.0, 148.0)
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.96), Vector4.ZERO, 10.0)
	)
	row.add_child(portrait_frame)
	var portrait_margin := _margin(9, 9, 9, 9)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(146.0, 130.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 7)
	row.add_child(summary)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	summary.add_child(heading_row)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var heading := _label(display_name.to_upper(), 25, ProgressionUI.TEXT, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_row.add_child(heading)
	var rank_text := _label(rank.to_upper(), 9, accent.lightened(0.16), true)
	rank_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading_row.add_child(rank_text)

	var identity := _label("%s  ·  %s" % [
		String(species.get("type", species.get("attribute", "Free"))).to_upper(),
		String(species.get("family", species.get("species", "Unknown"))).to_upper(),
	], 11, ProgressionUI.MUTED, true)
	summary.add_child(identity)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 14)
	summary.add_child(level_row)
	level_row.add_child(_label("LEVEL %d" % instance.level, 20, ProgressionUI.GOLD, true))
	level_row.add_child(_label("POTENTIAL %d" % instance.potential, 10, ProgressionUI.PURPLE.lightened(0.16), true))

	var required := _progression.exp_to_next_level(instance)
	var xp_copy := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_line := HBoxContainer.new()
	xp_line.add_theme_constant_override("separation", 10)
	summary.add_child(xp_line)
	var xp_caption := _label("NEXT LEVEL", 9, ProgressionUI.SUBTLE, true)
	xp_caption.custom_minimum_size.x = 72.0
	xp_line.add_child(xp_caption)
	var xp_bar := _mini_progress(ProgressionUI.GOLD)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	xp_line.add_child(xp_bar)
	var xp_value := _label(xp_copy, 10, ProgressionUI.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_value.custom_minimum_size.x = 80.0
	xp_line.add_child(xp_value)
	return hero


func _build_skills_card(instance: DigimonInstance) -> Control:
	var card := _section_card("SKILLS", ProgressionUI.GOLD)
	var body := card.get_meta("body") as VBoxContainer
	body.add_child(_subheading("EQUIPPED", ProgressionUI.GOLD))
	body.add_child(_wrapped_value(_skill_list_copy(instance.equipped_skills, "None equipped"), ProgressionUI.TEXT))
	if not instance.learned_skills.is_empty():
		body.add_child(_subheading("LEARNED", ProgressionUI.CYAN))
		body.add_child(_wrapped_value(_skill_list_copy(instance.learned_skills, ""), ProgressionUI.MUTED))
	return card


func _build_evolution_card(instance: DigimonInstance) -> Control:
	var card := _section_card("EVOLUTION CHART", ProgressionUI.PURPLE)
	var body := card.get_meta("body") as VBoxContainer
	var evolutions: Array[Dictionary] = _progression.get_evolution_routes(instance)
	var degenerations: Array[Dictionary] = _progression.get_degeneration_routes(instance)
	var ready := 0
	for route: Dictionary in evolutions:
		if bool(route.get("unlocked", false)):
			ready += 1
	for route: Dictionary in degenerations:
		if bool(route.get("unlocked", false)):
			ready += 1

	var route_line := "%d EVOLUTION%s  ·  %d DEGENERATION%s" % [
		evolutions.size(), "" if evolutions.size() == 1 else "S",
		degenerations.size(), "" if degenerations.size() == 1 else "S"
	]
	body.add_child(_label(route_line, 10, ProgressionUI.CYAN, true))
	if ready > 0:
		body.add_child(_label("%d route%s ready" % [ready, "" if ready == 1 else "s"], 10, ProgressionUI.GREEN, true))
	if not instance.evolution_goal_seed.is_empty():
		var goal_species := _database.get_by_seed(instance.evolution_goal_seed)
		if not goal_species.is_empty():
			body.add_child(_label("TARGET  ·  %s" % String(goal_species.get("name", "Unknown")).to_upper(), 10, ProgressionUI.PURPLE.lightened(0.18), true))

	var open_button := _button("OPEN EVOLUTION CHART", ProgressionUI.PURPLE)
	open_button.custom_minimum_size.y = 46.0
	open_button.pressed.connect(_open_constellation.bind(instance.id))
	body.add_child(open_button)
	return card


func _open_constellation(instance_id: String) -> void:
	if _constellation == null:
		return
	var instance := OverworldState.get_instance_by_id(instance_id)
	if instance == null:
		return
	_constellation.open_for(instance)


func _close_constellation() -> void:
	if _constellation != null:
		_constellation.visible = false
	_refresh_roster()
	if not _buttons.is_empty():
		_buttons[clampi(_selected_index, 0, _buttons.size() - 1)].grab_focus()


func _on_evolution_state_changed(_instance: DigimonInstance) -> void:
	OverworldState.notify_roster_changed()
	_refresh_roster()


func _section_card(title: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.055, 0.08, 0.13, 0.96), Vector4.ZERO, 10.0)
	)
	var card_margin := _margin(16, 14, 16, 14)
	panel.add_child(card_margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	card_margin.add_child(body)
	var heading := _label(title, 11, accent.lightened(0.10), true)
	body.add_child(heading)
	panel.set_meta("body", body)
	return panel


func _stat_tile(label_text: String, value: int, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(100.0, 62.0)
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		SKIN.border_style(Color(accent.r, accent.g, accent.b, 0.72), Vector4.ZERO, 8.0)
	)
	var tile_margin := _margin(12, 9, 12, 9)
	panel.add_child(tile_margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	tile_margin.add_child(box)
	box.add_child(_label(label_text, 9, ProgressionUI.SUBTLE, true))
	box.add_child(_label(str(value), 18, ProgressionUI.TEXT, true))
	return panel


func _chip(text: String, accent: Color) -> Label:
	# Chips are deliberately typographic here. Decorative micro-frames made the
	# text cramped; the surrounding surfaces already provide the Kenney chrome.
	var label := _label(text, 9, accent.lightened(0.14), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	SKIN.apply_button(button, accent)
	return button


func _configure_close_button(button: Button, tooltip: String) -> void:
	if button == null:
		return
	button.text = ""
	button.icon = CLOSE_ICON
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(44.0, 44.0)


func _style_roster_button(button: Button, selected: bool, rank_color: Color) -> void:
	var accent := ProgressionUI.GOLD if selected else rank_color
	SKIN.apply_button(button, accent)
	if selected:
		button.add_theme_stylebox_override(
			"normal",
			SKIN.border_style(ProgressionUI.GOLD, Vector4(14, 10, 14, 10), 10.0)
		)


func _mini_progress(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", SKIN.progress_track_style())
	bar.add_theme_stylebox_override("fill", SKIN.progress_fill_style(accent))
	return bar


func _skill_list_copy(skill_ids: Array[String], empty_copy: String) -> String:
	if skill_ids.is_empty():
		return empty_copy
	var names: Array[String] = []
	for skill_id: String in skill_ids:
		names.append(_skill_display_name(skill_id))
	return ", ".join(names)


func _skill_display_name(skill_id: String) -> String:
	if _actions != null:
		var action := _actions.get_action(skill_id)
		var display_name := String(action.get("name", "")).strip_edges()
		if not display_name.is_empty():
			return display_name
	return skill_id.replace("_", " ").capitalize()


func _layout() -> void:
	if _panel == null or _menu_root == null:
		return
	var physical := ProgressionUI.physical_window_size(get_viewport())
	var scale_factor := ProgressionUI.ui_scale(get_viewport())
	var compact := ProgressionUI.is_compact(get_viewport(), 840.0)
	var edge := 12.0 if compact else 18.0
	var width := minf(1240.0, physical.x - edge * 2.0)
	var height := minf(760.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor

	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = origin
	_panel.size = Vector2(width, height)
	_panel.clip_contents = true
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)
	_menu_root.clip_contents = true

	var header_h := 72.0
	_title.position = Vector2(28.0, 19.0)
	_title.size = Vector2(240.0, 34.0)
	_account.position = Vector2(width - 300.0, 23.0)
	_account.size = Vector2(210.0, 26.0)
	_close_button.position = Vector2(width - 68.0, 14.0)
	_close_button.size = Vector2(44.0, 44.0)

	if compact:
		var roster_h := minf(196.0, height * 0.29)
		_roster_panel.position = Vector2(20.0, header_h)
		_roster_panel.size = Vector2(width - 40.0, roster_h)
		_detail_panel.position = Vector2(20.0, header_h + roster_h + 14.0)
		_detail_panel.size = Vector2(width - 40.0, height - header_h - roster_h - 34.0)
		_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_grid.columns = 2 if width < 620.0 else 3
	else:
		var roster_w := clampf(width * 0.245, 270.0, 310.0)
		var left := 20.0
		var gap := 16.0
		var right := 20.0
		var detail_x := left + roster_w + gap
		_roster_panel.position = Vector2(left, header_h)
		_roster_panel.size = Vector2(roster_w, height - header_h - 20.0)
		_detail_panel.position = Vector2(detail_x, header_h)
		_detail_panel.size = Vector2(width - detail_x - right, height - header_h - 20.0)
		_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_roster_grid.columns = 1

	_roster_panel.clip_contents = true
	_detail_panel.clip_contents = true
	_apply_adaptive_detail_layout(compact)
	if compact != _last_compact:
		_last_compact = compact
		call_deferred("_refresh_details")