extends Control
class_name EvolutionConstellation

signal close_requested
signal evolution_applied(instance: DigimonInstance)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const GraphServiceScript = preload("res://src/digimon/EvolutionGraphService.gd")
const CanvasScript = preload("res://src/ui/EvolutionConstellationCanvas.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database: DigimonDatabase
var _instance: DigimonInstance
var _graph_service: EvolutionGraphService
var _evolution_service: DigimonEvolutionService
var _calculator: DigimonStatCalculator
var _progression: DigimonProgressionService
var _graph: Dictionary = {}
var _selected_seed := ""
var _goal_path: Array[String] = []

var _backdrop: ColorRect
var _frame: PanelContainer
var _title: Label
var _subtitle: Label
var _close_button: Button
var _center_button: Button
var _zoom_in_button: Button
var _zoom_out_button: Button
var _canvas: EvolutionConstellationCanvas
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
var _flash: ColorRect
var _announcement: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_graph_service = GraphServiceScript.new() as EvolutionGraphService
	_evolution_service = EvolutionServiceScript.new() as DigimonEvolutionService
	_calculator = StatCalculatorScript.new() as DigimonStatCalculator
	_progression = ProgressionServiceScript.new(_database) as DigimonProgressionService
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_for(instance: DigimonInstance) -> void:
	if instance == null:
		return
	_instance = instance
	_selected_seed = instance.species_seed
	visible = true
	_rebuild_graph()
	_refresh_detail()
	call_deferred("_layout")
	call_deferred("_focus_current")


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
	_backdrop.color = Color(0.012, 0.018, 0.055, 0.97)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.11, 0.16, 0.28, 0.98), Vector4.ZERO, 14.0))
	add_child(_frame)

	_title = _label("EVOLUTION CONSTELLATION", 24, UI.TEXT, true)
	add_child(_title)
	_subtitle = _label("Navigate every connected Digivolution and Degeneration route", 11, UI.MUTED)
	add_child(_subtitle)

	_close_button = _button("CLOSE", UI.MUTED)
	_close_button.pressed.connect(close_view)
	add_child(_close_button)
	_center_button = _button("CENTER", UI.CYAN)
	_center_button.pressed.connect(func():
		if _instance != null:
			_canvas.center_on(_instance.species_seed)
	)
	add_child(_center_button)
	_zoom_out_button = _button("−", UI.CYAN)
	_zoom_out_button.pressed.connect(func(): _canvas.zoom_out())
	add_child(_zoom_out_button)
	_zoom_in_button = _button("+", UI.CYAN)
	_zoom_in_button.pressed.connect(func(): _canvas.zoom_in())
	add_child(_zoom_in_button)

	_canvas = CanvasScript.new() as EvolutionConstellationCanvas
	_canvas.name = "EvolutionConstellationCanvas"
	_canvas.node_selected.connect(_on_node_selected)
	add_child(_canvas)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", SKIN.border_style(Color(0.30, 0.55, 0.88, 0.98), Vector4(12, 12, 12, 12), 12.0))
	add_child(_detail_panel)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(_detail_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 9)
	_detail_scroll.add_child(_detail_body)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.55, 0.80, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)
	_announcement = _label("", 30, Color.WHITE, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announcement.add_theme_constant_override("outline_size", 6)
	_announcement.add_theme_color_override("font_outline_color", Color(0.18, 0.46, 0.95, 0.86))
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement.visible = false
	add_child(_announcement)


func _rebuild_graph() -> void:
	if _instance == null or _database == null:
		return
	_graph = _graph_service.build_connected_graph(_instance.species_seed, _database)
	var history_edges := _graph_service.history_edge_keys(_instance.evolution_history)
	_goal_path.clear()
	var goal_edges: Dictionary = {}
	if not _instance.evolution_goal_seed.is_empty() and _database.has_seed(_instance.evolution_goal_seed):
		_goal_path = _graph_service.find_shortest_path(_instance.species_seed, _instance.evolution_goal_seed, _database)
		goal_edges = _graph_service.path_edge_keys(_goal_path)
	_canvas.set_graph(_graph, _instance.species_seed, history_edges, _instance.evolution_goal_seed, goal_edges)


func _on_node_selected(seed: String) -> void:
	_selected_seed = seed
	_refresh_detail()


func _refresh_detail() -> void:
	if _detail_body == null:
		return
	for child in _detail_body.get_children():
		child.queue_free()
	if _instance == null or _selected_seed.is_empty():
		return
	var species := _database.get_by_seed(_selected_seed)
	if species.is_empty():
		return
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(210.0, 168.0)
	portrait_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(accent.r * 0.36, accent.g * 0.36, accent.b * 0.36, 0.96), Vector4(8, 8, 8, 8), 10.0))
	_detail_body.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(194.0, 152.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_frame.add_child(portrait)

	var name_label := _label(String(species.get("name", "Unknown")).to_upper(), 22, UI.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(name_label)
	_detail_body.add_child(_label("%s  ·  %s" % [rank.to_upper(), String(species.get("type", species.get("attribute", "Free"))).to_upper()], 10, accent.lightened(0.14), true))

	if _selected_seed == _instance.species_seed:
		_detail_body.add_child(_chip("CURRENT FORM", UI.GOLD))
		_detail_body.add_child(_label("LV %d   ·   POTENTIAL %d" % [_instance.level, _instance.potential], 13, UI.TEXT, true))
		var experienced := _experienced_form_count()
		var total_nodes := (_graph.get("nodes", []) as Array).size()
		_detail_body.add_child(_label("Forms experienced by this Digimon: %d / %d connected" % [experienced, total_nodes], 10, UI.MUTED))
		if not _instance.evolution_goal_seed.is_empty():
			var goal_species := _database.get_by_seed(_instance.evolution_goal_seed)
			if not goal_species.is_empty():
				_detail_body.add_child(_section_label("CURRENT GOAL", UI.PURPLE))
				_detail_body.add_child(_label(String(goal_species.get("name", "Unknown")), 14, UI.PURPLE.lightened(0.18), true))
		return

	var direction := _graph_service.route_direction(_instance.species_seed, _selected_seed, _database)
	var path := _graph_service.find_shortest_path(_instance.species_seed, _selected_seed, _database)
	if not path.is_empty():
		_detail_body.add_child(_section_label("ROUTE", UI.CYAN))
		_detail_body.add_child(_route_path_label(path))

	if direction == "digivolution" or direction == "degeneration":
		var route := _direct_route(_selected_seed, direction)
		_detail_body.add_child(_section_label("REQUIREMENTS", UI.GREEN if direction == "digivolution" else UI.CYAN))
		_add_requirement_rows(route.get("requirements", []))
		var unlocked := bool(route.get("unlocked", false))
		var action := _button("DIGIVOLVE" if direction == "digivolution" else "DEGENERATE", UI.GREEN if direction == "digivolution" else UI.CYAN)
		action.disabled = not unlocked
		action.tooltip_text = "Meet every requirement before changing form." if not unlocked else "This changes the Digimon to the selected form and resets it to Level 1."
		action.pressed.connect(_show_transition_confirmation.bind(direction, _selected_seed))
		_detail_body.add_child(action)
		if not unlocked:
			_detail_body.add_child(_label("Requirements are not met yet. You can still explore and mark this form as a future target.", 10, UI.MUTED))

	_add_goal_controls(path)


func _add_goal_controls(path: Array[String]) -> void:
	if _instance == null or _selected_seed == _instance.species_seed or path.is_empty():
		return
	_detail_body.add_child(_section_label("PLANNING", UI.PURPLE))
	if _instance.evolution_goal_seed == _selected_seed:
		_detail_body.add_child(_chip("EVOLUTION GOAL", UI.PURPLE))
		var clear_button := _button("CLEAR GOAL", UI.MUTED)
		clear_button.pressed.connect(_clear_goal)
		_detail_body.add_child(clear_button)
	else:
		var goal_button := _button("MARK AS TARGET", UI.PURPLE)
		goal_button.pressed.connect(_mark_selected_as_goal)
		_detail_body.add_child(goal_button)


func _mark_selected_as_goal() -> void:
	if _instance == null or _selected_seed.is_empty() or _selected_seed == _instance.species_seed:
		return
	_instance.evolution_goal_seed = _selected_seed
	_goal_path = _graph_service.find_shortest_path(_instance.species_seed, _selected_seed, _database)
	_canvas.set_goal(_selected_seed, _graph_service.path_edge_keys(_goal_path))
	_refresh_detail()
	evolution_applied.emit(_instance)


func _clear_goal() -> void:
	if _instance == null:
		return
	_instance.evolution_goal_seed = ""
	_goal_path.clear()
	_canvas.set_goal("", {})
	_refresh_detail()
	evolution_applied.emit(_instance)


func _show_transition_confirmation(direction: String, target_seed: String) -> void:
	var target := _database.get_by_seed(target_seed)
	if target.is_empty():
		return
	_detail_body.add_child(_section_label("CONFIRM", UI.ORANGE))
	_detail_body.add_child(_label("Change to %s? Level and XP will reset to Level 1. Permanent development and evolution history remain." % String(target.get("name", "Unknown")), 10, UI.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail_body.add_child(row)
	var confirm := _button("CONFIRM", UI.GOLD)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_apply_transition.bind(direction, target_seed))
	row.add_child(confirm)
	var cancel := _button("CANCEL", UI.MUTED)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_refresh_detail)
	row.add_child(cancel)


func _apply_transition(direction: String, target_seed: String) -> void:
	if _instance == null:
		return
	var target := _database.get_by_seed(target_seed)
	if target.is_empty():
		return
	var success := false
	if direction == "digivolution":
		success = _evolution_service.digivolve(_instance, target_seed, _database, _calculator)
	elif direction == "degeneration":
		success = _evolution_service.degenerate(_instance, target_seed, _database, _calculator)
	if not success:
		_refresh_detail()
		return
	if _instance.evolution_goal_seed == target_seed:
		_instance.evolution_goal_seed = ""
	_selected_seed = _instance.species_seed
	evolution_applied.emit(_instance)
	_rebuild_graph()
	_refresh_detail()
	_play_transition_celebration(direction, String(target.get("name", "Digimon")))
	call_deferred("_focus_current")


func _play_transition_celebration(direction: String, target_name: String) -> void:
	_flash.visible = true
	_flash.modulate.a = 0.0
	_flash.color = Color(0.38, 0.76, 1.0, 1.0) if direction == "digivolution" else Color(0.43, 0.88, 0.80, 1.0)
	_announcement.text = ("DIGIVOLUTION COMPLETE\n" if direction == "digivolution" else "DEGENERATION COMPLETE\n") + target_name.to_upper()
	_announcement.visible = true
	_announcement.modulate.a = 0.0
	_announcement.scale = Vector2(0.90, 0.90)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_flash, "modulate:a", 0.34, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_announcement, "modulate:a", 1.0, 0.18)
	tween.tween_property(_announcement, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.55).timeout
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(_flash, "modulate:a", 0.0, 0.34)
	out.tween_property(_announcement, "modulate:a", 0.0, 0.28)
	await out.finished
	_flash.visible = false
	_announcement.visible = false


func _direct_route(target_seed: String, direction: String) -> Dictionary:
	var routes: Array[Dictionary] = _progression.get_evolution_routes(_instance) if direction == "digivolution" else _progression.get_degeneration_routes(_instance)
	for route: Dictionary in routes:
		if String(route.get("targetSeed", "")) == target_seed:
			return route
	return {}


func _add_requirement_rows(raw_requirements) -> void:
	if not raw_requirements is Array or (raw_requirements as Array).is_empty():
		_detail_body.add_child(_label("No extra requirements", 10, UI.GREEN, true))
		return
	for raw in raw_requirements:
		if not raw is Dictionary:
			continue
		var requirement := raw as Dictionary
		var met := _requirement_met(requirement)
		var text := _requirement_text(requirement)
		_detail_body.add_child(_label(("✓  " if met else "✦  ") + text, 11, UI.GREEN if met else UI.MUTED, true))


func _requirement_met(requirement: Dictionary) -> bool:
	if _instance == null:
		return false
	var kind := String(requirement.get("type", "")).to_lower()
	var value := int(requirement.get("value", 0))
	var stats := _progression.get_final_stats(_instance)
	match kind:
		"level": return _instance.level >= value
		"potential", "abi": return _instance.potential >= value
		"hp": return int(stats.get("hp", 0)) >= value
		"mp", "sp": return int(stats.get("sp", 0)) >= value
		"atk", "attack": return int(stats.get("atk", 0)) >= value
		"def", "defense": return int(stats.get("def", 0)) >= value
		"int": return int(stats.get("int", 0)) >= value
		"speed": return int(stats.get("speed", 0)) >= value
		"item": return false
		"": return true
	return false


func _requirement_text(requirement: Dictionary) -> String:
	var kind := String(requirement.get("type", "")).to_lower()
	var value := str(requirement.get("value", ""))
	match kind:
		"level": return "Level %s" % value
		"potential", "abi": return "Potential %s" % value
		"mp", "sp": return "SP %s" % value
		"atk", "attack": return "ATK %s" % value
		"def", "defense": return "DEF %s" % value
		"speed": return "SPD %s" % value
		"item": return "Required item: %s" % value
	return "%s %s" % [kind.to_upper(), value]


func _route_path_label(path: Array[String]) -> Label:
	var names: Array[String] = []
	for seed: String in path:
		var species := _database.get_by_seed(seed)
		names.append(String(species.get("name", "?")))
	var label := _label("  →  ".join(names), 10, UI.CYAN.lightened(0.12), true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _experienced_form_count() -> int:
	if _instance == null:
		return 0
	var seeds: Dictionary = {_instance.species_seed: true}
	for record: Dictionary in _instance.evolution_history:
		var from_seed := String(record.get("fromSeed", ""))
		var to_seed := String(record.get("toSeed", ""))
		if not from_seed.is_empty(): seeds[from_seed] = true
		if not to_seed.is_empty(): seeds[to_seed] = true
	return seeds.size()


func _focus_current() -> void:
	if _instance != null:
		_canvas.center_on(_instance.species_seed)


func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 850.0) or physical.y > physical.x * 1.08
	var edge := 10.0 if compact else 18.0
	var width := minf(1500.0, physical.x - edge * 2.0)
	var height := minf(900.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)

	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(24, 15) * scale_factor
	_title.size = Vector2(width - 430, 34)
	_subtitle.scale = Vector2.ONE * scale_factor
	_subtitle.position = origin + Vector2(26, 45) * scale_factor
	_subtitle.size = Vector2(width - 430, 24)
	_close_button.scale = Vector2.ONE * scale_factor
	_close_button.position = origin + Vector2(width - 104, 16) * scale_factor
	_close_button.size = Vector2(82, 40)
	_zoom_in_button.scale = Vector2.ONE * scale_factor
	_zoom_out_button.scale = Vector2.ONE * scale_factor
	_center_button.scale = Vector2.ONE * scale_factor
	_zoom_in_button.position = origin + Vector2(width - 160, height - 58) * scale_factor
	_zoom_out_button.position = origin + Vector2(width - 210, height - 58) * scale_factor
	_center_button.position = origin + Vector2(width - 306, height - 58) * scale_factor
	_zoom_in_button.size = Vector2(42, 38)
	_zoom_out_button.size = Vector2(42, 38)
	_center_button.size = Vector2(88, 38)

	_canvas.scale = Vector2.ONE * scale_factor
	_detail_panel.scale = Vector2.ONE * scale_factor
	if compact:
		var detail_h := clampf(height * 0.39, 260.0, 360.0)
		_canvas.position = origin + Vector2(18, 74) * scale_factor
		_canvas.size = Vector2(width - 36, height - detail_h - 96) * scale_factor / scale_factor
		_detail_panel.position = origin + Vector2(18, height - detail_h - 16) * scale_factor
		_detail_panel.size = Vector2(width - 36, detail_h)
	else:
		var detail_w := clampf(width * 0.27, 320.0, 390.0)
		_canvas.position = origin + Vector2(18, 74) * scale_factor
		_canvas.size = Vector2(width - detail_w - 54, height - 96)
		_detail_panel.position = origin + Vector2(width - detail_w - 22, 74) * scale_factor
		_detail_panel.size = Vector2(detail_w, height - 96)

	_flash.position = Vector2.ZERO
	_flash.size = get_viewport_rect().size
	_announcement.position = origin + Vector2(width * 0.18, height * 0.40) * scale_factor
	_announcement.size = Vector2(width * 0.64, 150.0) * scale_factor


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


func _chip(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent.lightened(0.16), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(120, 25)
	return label


func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent.lightened(0.12), true)
	label.add_theme_constant_override("outline_size", 1)
	return label
