extends "res://src/ui/EvolutionConstellation.gd"
class_name EvolutionChart

const ChartCanvasScript = preload("res://src/ui/EvolutionChartCanvas.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")

var _content_root: Control = null

# Navigation data is immutable while the chart is open for the same Digimon state.
# Build it once when the graph is rebuilt, then every click is dictionary lookup
# instead of another database traversal/BFS.
var _path_cache: Dictionary = {}
var _direction_cache: Dictionary = {}
var _direct_route_cache: Dictionary = {}
var _detail_refresh_generation := 0


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.004, 0.008, 0.025, 0.97)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = PanelContainer.new()
	_frame.name = "EvolutionChartFrame"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.08, 0.13, 0.24, 0.98), Vector4.ZERO, 14.0)
	)
	add_child(_frame)

	_content_root = Control.new()
	_content_root.name = "Content"
	_content_root.clip_contents = true
	_frame.add_child(_content_root)

	_title = _label("EVOLUTION CHART", 24, UI.TEXT, true)
	_content_root.add_child(_title)
	_subtitle = _label("Explore Digivolution and Degeneration routes", 11, UI.MUTED)
	_content_root.add_child(_subtitle)

	_close_button = _button("", UI.MUTED)
	_close_button.name = "CloseEvolutionChart"
	_close_button.icon = CLOSE_ICON
	_close_button.expand_icon = true
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.tooltip_text = "Close Evolution Chart"
	_close_button.custom_minimum_size = Vector2(44.0, 44.0)
	_close_button.pressed.connect(close_view)
	_content_root.add_child(_close_button)
	_center_button = null
	_zoom_in_button = null
	_zoom_out_button = null

	_canvas = ChartCanvasScript.new() as EvolutionConstellationCanvas
	_canvas.name = "EvolutionChartCanvas"
	_canvas.clip_contents = true
	_canvas.node_selected.connect(_on_node_selected)
	_content_root.add_child(_canvas)

	_detail_panel = PanelContainer.new()
	_detail_panel.name = "EvolutionChartDetail"
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(0.07, 0.12, 0.20, 0.98), Vector4.ZERO, 12.0)
	)
	_content_root.add_child(_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 18)
	detail_margin.add_theme_constant_override("margin_top", 18)
	detail_margin.add_theme_constant_override("margin_right", 18)
	detail_margin.add_theme_constant_override("margin_bottom", 18)
	_detail_panel.add_child(detail_margin)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "EvolutionChartDetailScroll"
	_detail_scroll.clip_contents = true
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)

	_detail_body = VBoxContainer.new()
	_detail_body.name = "EvolutionChartDetailBody"
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 10)
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
	_rebuild_navigation_cache()

	var history_edges := _graph_service.history_edge_keys(_instance.evolution_history)
	_goal_path.clear()
	var goal_edges: Dictionary = {}
	if not _instance.evolution_goal_seed.is_empty() and _database.has_seed(_instance.evolution_goal_seed):
		_goal_path = _cached_path(_instance.evolution_goal_seed)
		goal_edges = _graph_service.path_edge_keys(_goal_path)
	_canvas.set_graph(_graph, _instance.species_seed, history_edges, _instance.evolution_goal_seed, goal_edges)


func _rebuild_navigation_cache() -> void:
	_path_cache.clear()
	_direction_cache.clear()
	_direct_route_cache.clear()
	if _instance == null:
		return

	var adjacency: Dictionary = {}
	var raw_nodes = _graph.get("nodes", [])
	if raw_nodes is Array:
		for raw_node in raw_nodes:
			if not raw_node is Dictionary:
				continue
			var seed := String((raw_node as Dictionary).get("seed", ""))
			if not seed.is_empty():
				adjacency[seed] = []

	var raw_edges = _graph.get("edges", [])
	if raw_edges is Array:
		for raw_edge in raw_edges:
			if not raw_edge is Dictionary:
				continue
			var edge := raw_edge as Dictionary
			var from_seed := String(edge.get("from", ""))
			var to_seed := String(edge.get("to", ""))
			if from_seed.is_empty() or to_seed.is_empty():
				continue
			if not adjacency.has(from_seed):
				adjacency[from_seed] = []
			if not adjacency.has(to_seed):
				adjacency[to_seed] = []
			(adjacency[from_seed] as Array).append(to_seed)
			(adjacency[to_seed] as Array).append(from_seed)

	# One O(V + E) BFS when the chart is built. Clicks only read the cached path.
	var current_seed := _instance.species_seed
	if adjacency.has(current_seed):
		var queue: Array[String] = [current_seed]
		var head := 0
		var previous: Dictionary = {current_seed: ""}
		while head < queue.size():
			var cursor := queue[head]
			head += 1
			for raw_neighbor in adjacency.get(cursor, []) as Array:
				var neighbor := String(raw_neighbor)
				if previous.has(neighbor):
					continue
				previous[neighbor] = cursor
				queue.append(neighbor)

		for raw_seed in previous.keys():
			var seed := String(raw_seed)
			var path: Array[String] = []
			var cursor := seed
			while not cursor.is_empty():
				path.append(cursor)
				if cursor == current_seed:
					break
				cursor = String(previous.get(cursor, ""))
			path.reverse()
			_path_cache[seed] = path

	# Direct action/requirements are also evaluated only once for this Digimon state.
	for route: Dictionary in _progression.get_evolution_routes(_instance):
		var target := String(route.get("targetSeed", ""))
		if target.is_empty():
			continue
		_direction_cache[target] = "digivolution"
		_direct_route_cache["digivolution|%s" % target] = route
	for route: Dictionary in _progression.get_degeneration_routes(_instance):
		var target := String(route.get("targetSeed", ""))
		if target.is_empty():
			continue
		_direction_cache[target] = "degeneration"
		_direct_route_cache["degeneration|%s" % target] = route


func _cached_path(seed: String) -> Array[String]:
	var result: Array[String] = []
	var raw_path = _path_cache.get(seed, [])
	if raw_path is Array:
		for raw_seed in raw_path as Array:
			result.append(String(raw_seed))
	return result


func _on_node_selected(seed: String) -> void:
	_selected_seed = seed
	_detail_refresh_generation += 1
	_refresh_detail_next_frame(seed, _detail_refresh_generation)


func _refresh_detail_next_frame(seed: String, generation: int) -> void:
	# Let the graph present the new branch on this frame. Detail-panel work happens
	# one frame later and is discarded if the player has already moved again.
	await get_tree().process_frame
	if generation != _detail_refresh_generation or seed != _selected_seed or not visible:
		return
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
	var species_name := String(species.get("name", "Unknown"))

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(0.0, 174.0)
	portrait_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.96), Vector4.ZERO, 10.0)
	)
	_detail_body.add_child(portrait_frame)
	var portrait_margin := MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_left", 10)
	portrait_margin.add_theme_constant_override("margin_top", 10)
	portrait_margin.add_theme_constant_override("margin_right", 10)
	portrait_margin.add_theme_constant_override("margin_bottom", 10)
	portrait_frame.add_child(portrait_margin)

	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(0.0, 154.0)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.set_species(species_name)
	portrait_margin.add_child(portrait)

	var name_label := _label(species_name.to_upper(), 22, UI.TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_child(name_label)
	_detail_body.add_child(_label(
		"%s  ·  %s" % [rank.to_upper(), String(species.get("type", species.get("attribute", "Free"))).to_upper()],
		10,
		accent.lightened(0.14),
		true
	))

	if _selected_seed == _instance.species_seed:
		var current_label := _label("CURRENT FORM", 9, UI.GOLD, true)
		current_label.add_theme_constant_override("outline_size", 1)
		_detail_body.add_child(current_label)
		_detail_body.add_child(_label("LV %d   ·   POTENTIAL %d   ·   LINK %d" % [_instance.level, _instance.potential, _instance.link], 13, UI.TEXT, true))
		if not _instance.evolution_goal_seed.is_empty():
			var goal_species := _database.get_by_seed(_instance.evolution_goal_seed)
			if not goal_species.is_empty():
				_detail_body.add_child(_section_label("TARGET", UI.PURPLE))
				_detail_body.add_child(_label(String(goal_species.get("name", "Unknown")), 14, UI.PURPLE.lightened(0.18), true))
		return

	var direction := String(_direction_cache.get(_selected_seed, ""))
	var path := _cached_path(_selected_seed)

	if direction == "digivolution" or direction == "degeneration":
		var route := _direct_route_cache.get("%s|%s" % [direction, _selected_seed], {}) as Dictionary
		var route_accent := UI.GREEN if direction == "digivolution" else UI.CYAN
		_detail_body.add_child(_section_label("REQUIREMENTS", route_accent))
		_add_requirement_rows(route.get("requirement_results", []))
		var unlocked := bool(route.get("unlocked", false))
		var action := _button("DIGIVOLVE" if direction == "digivolution" else "DEGENERATE", route_accent)
		action.disabled = not unlocked
		action.tooltip_text = "Meet every requirement first." if not unlocked else "Change to %s and return to Level 1." % species_name
		action.pressed.connect(_show_transition_confirmation.bind(direction, _selected_seed))
		_detail_body.add_child(action)

	_add_goal_controls(path)


func _mark_selected_as_goal() -> void:
	if _instance == null or _selected_seed.is_empty() or _selected_seed == _instance.species_seed:
		return
	_instance.evolution_goal_seed = _selected_seed
	_goal_path = _cached_path(_selected_seed)
	_canvas.set_goal(_selected_seed, _graph_service.path_edge_keys(_goal_path))
	_refresh_detail()
	evolution_applied.emit(_instance)


func _add_requirement_rows(raw_evaluations) -> void:
	if not raw_evaluations is Array or (raw_evaluations as Array).is_empty():
		_detail_body.add_child(_label("No extra requirements", 10, UI.GREEN, true))
		return
	for raw_evaluation in raw_evaluations:
		if not raw_evaluation is Dictionary:
			continue
		var evaluation := raw_evaluation as Dictionary
		var met := bool(evaluation.get("is_met", false))
		var supported := bool(evaluation.get("supported", true))
		var text := _requirement_result_text(evaluation)
		var prefix := "✓  " if met else "✕  "
		var color := UI.GREEN if met else UI.RED if supported else UI.ORANGE
		_detail_body.add_child(_label(prefix + text, 11, color, true))


func _requirement_result_text(evaluation: Dictionary) -> String:
	var kind := String(evaluation.get("type", "")).to_lower()
	var subject := String(evaluation.get("subject", kind))
	var current = evaluation.get("current_value", 0)
	var required = evaluation.get("required_value", 0)
	match kind:
		"level": return "Level %s / %s" % [current, required]
		"potential", "abi": return "Potential %s / %s" % [current, required]
		"link": return "Link %s / %s" % [current, required]
		"item": return "%s × %s / %s" % [subject, current, required]
		"quest": return "%s · %s / %s" % [subject, current, required]
		"flag", "party_condition": return subject.replace("_", " ").capitalize()
		"stat": return "%s %s / %s" % [subject.to_upper(), current, required]
		"hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed":
			return "%s %s / %s" % [subject.to_upper(), current, required]
		"battles_won": return "Battles won %s / %s" % [current, required]
		"species_defeated": return "%s defeated %s / %s" % [subject, current, required]
		"time": return "Time %s / %s" % [current, required]
	return "%s %s / %s" % [subject.replace("_", " ").capitalize(), current, required]


func _add_goal_controls(path: Array[String]) -> void:
	if _instance == null or _selected_seed == _instance.species_seed or path.is_empty():
		return
	if _instance.evolution_goal_seed == _selected_seed:
		var clear_button := _button("CLEAR TARGET", UI.MUTED)
		clear_button.pressed.connect(_clear_goal)
		_detail_body.add_child(clear_button)
	else:
		var goal_button := _button("MARK AS TARGET", UI.PURPLE)
		goal_button.pressed.connect(_mark_selected_as_goal)
		_detail_body.add_child(goal_button)


func _chip(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent.lightened(0.16), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _layout() -> void:
	if not visible or _frame == null or _content_root == null:
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
	_frame.clip_contents = true
	_content_root.position = Vector2.ZERO
	_content_root.size = Vector2(width, height)

	_title.position = Vector2(28, 17)
	_title.size = Vector2(maxf(180.0, width - 190.0), 34)
	_subtitle.position = Vector2(30, 48)
	_subtitle.size = Vector2(maxf(180.0, width - 190.0), 24)
	_close_button.position = Vector2(width - 68.0, 14.0)
	_close_button.size = Vector2(44.0, 44.0)

	if compact:
		var detail_h := clampf(height * 0.38, 250.0, 340.0)
		_canvas.position = Vector2(20.0, 82.0)
		_canvas.size = Vector2(width - 40.0, maxf(160.0, height - detail_h - 112.0))
		_detail_panel.position = Vector2(20.0, height - detail_h - 18.0)
		_detail_panel.size = Vector2(width - 40.0, detail_h)
	else:
		var detail_w := clampf(width * 0.285, 330.0, 390.0)
		var right_margin := 20.0
		var gap := 16.0
		var detail_x := width - right_margin - detail_w
		_canvas.position = Vector2(20.0, 82.0)
		_canvas.size = Vector2(maxf(280.0, detail_x - gap - 20.0), height - 102.0)
		_detail_panel.position = Vector2(detail_x, 82.0)
		_detail_panel.size = Vector2(detail_w, height - 102.0)

	_canvas.clip_contents = true
	_detail_panel.clip_contents = true
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
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(110, 40)
	SKIN.apply_button(button, accent)
	UI.apply_body_font(button)
	return button
