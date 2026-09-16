extends "res://src/ui/EvolutionConstellation.gd"
class_name EvolutionChart

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const GlassPanelScript = preload("res://src/ui/components/DigiGlassPanel.gd")
const ChartCanvasScript = preload("res://src/ui/EvolutionChartCanvas.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const TransitionModalScript = preload("res://src/ui/EvolutionTransitionModal.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")

const MAX_FRAME_SIZE := Vector2(1500.0, 900.0)
const DESKTOP_BREAKPOINT := 960.0
const HEADER_HEIGHT := 76.0
const CONTENT_GAP := 14.0

var _content_root: Control = null
var _header_panel: PanelContainer = null
var _header_accent: ColorRect = null
var _transition_modal: EvolutionTransitionModal = null

# Navigation data is immutable while the chart is open for the same Digimon state.
# Build it once when the graph is rebuilt, then every click is dictionary lookup
# instead of another database traversal/BFS.
var _path_cache: Dictionary = {}
var _direction_cache: Dictionary = {}
var _direct_route_cache: Dictionary = {}
var _detail_refresh_generation := 0


func _build() -> void:
	set_meta("digi_ui_v2_component", true)

	_backdrop = ColorRect.new()
	_backdrop.name = "EvolutionChartBackdropV2"
	_backdrop.color = Color(V2.BACKDROP.r, V2.BACKDROP.g, V2.BACKDROP.b, 0.94)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_frame = GlassPanelScript.new() as PanelContainer
	_frame.name = "EvolutionChartFrameV2"
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.call("configure_glass", V2.CYAN, "modal", Vector4.ZERO, 14)
	add_child(_frame)

	_content_root = Control.new()
	_content_root.name = "EvolutionChartContentV2"
	_content_root.clip_contents = true
	_frame.add_child(_content_root)

	_header_panel = PanelContainer.new()
	_header_panel.name = "EvolutionChartHeaderV2"
	_header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_panel.add_theme_stylebox_override("panel", V2.header_strip_style(12))
	_content_root.add_child(_header_panel)

	_header_accent = ColorRect.new()
	_header_accent.name = "EvolutionChartHeaderAccentV2"
	_header_accent.color = Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.82)
	_header_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_root.add_child(_header_accent)

	_title = _label("EVOLUTION CHART", 25, V2.TEXT, true)
	_title.name = "EvolutionChartTitleV2"
	_content_root.add_child(_title)
	_subtitle = _label("Explore Digivolution and Degeneration routes", 11, V2.MUTED)
	_subtitle.name = "EvolutionChartSubtitleV2"
	_content_root.add_child(_subtitle)

	_close_button = _button("", V2.CYAN)
	_close_button.name = "CloseEvolutionChart"
	_close_button.icon = CLOSE_ICON
	_close_button.expand_icon = true
	_close_button.icon_max_width = 18
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.tooltip_text = "Close Evolution Chart"
	_close_button.custom_minimum_size = Vector2(V2.TOUCH_TARGET, V2.TOUCH_TARGET)
	_close_button.pressed.connect(close_view)
	_content_root.add_child(_close_button)
	_center_button = null
	_zoom_in_button = null
	_zoom_out_button = null

	# The chart itself deliberately stays on the existing, battle-tested canvas.
	# UI V2 owns only the surrounding screen chrome and detail surface.
	_canvas = ChartCanvasScript.new() as EvolutionConstellationCanvas
	_canvas.name = "EvolutionChartCanvas"
	_canvas.clip_contents = true
	_canvas.node_selected.connect(_on_node_selected)
	_content_root.add_child(_canvas)

	_detail_panel = GlassPanelScript.new() as PanelContainer
	_detail_panel.name = "EvolutionChartDetailV2"
	_detail_panel.clip_contents = true
	_detail_panel.call("configure_glass", V2.CYAN, "subtle", Vector4.ZERO, 10)
	_content_root.add_child(_detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.name = "EvolutionChartDetailMarginV2"
	detail_margin.add_theme_constant_override("margin_left", 16)
	detail_margin.add_theme_constant_override("margin_top", 16)
	detail_margin.add_theme_constant_override("margin_right", 16)
	detail_margin.add_theme_constant_override("margin_bottom", 16)
	_detail_panel.add_child(detail_margin)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "EvolutionChartDetailScroll"
	_detail_scroll.clip_contents = true
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.scroll_deadzone = 8
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
	_flash.color = Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)

	_announcement = _label("", 30, V2.WHITE, true)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announcement.add_theme_constant_override("outline_size", 6)
	_announcement.add_theme_color_override("font_outline_color", Color(V2.BLUE.r, V2.BLUE.g, V2.BLUE.b, 0.86))
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement.visible = false
	add_child(_announcement)

	_transition_modal = TransitionModalScript.new() as EvolutionTransitionModal
	_transition_modal.name = "EvolutionTransitionModal"
	_transition_modal.confirmed.connect(_on_transition_confirmed)
	add_child(_transition_modal)


func close_view() -> void:
	if _transition_modal != null:
		_transition_modal.close_immediately()
	super.close_view()


func _unhandled_input(event: InputEvent) -> void:
	if _transition_modal != null and _transition_modal.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_transition_modal.cancel()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _show_transition_confirmation(direction: String, target_seed: String) -> void:
	if _instance == null or _transition_modal == null:
		return
	var allowed := (
		_evolution_service.can_digivolve(_instance, target_seed, _database, _calculator)
		if direction == "digivolution"
		else _evolution_service.can_degenerate(_instance, target_seed, _database, _calculator)
	)
	if not allowed:
		_refresh_detail()
		return
	var preview := _evolution_service.build_transition_preview(_instance, target_seed, _database, _calculator, direction)
	if preview.is_empty():
		return
	_transition_modal.open_preview(preview)


func _on_transition_confirmed(direction: String, target_seed: String) -> void:
	_apply_transition(direction, target_seed)


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
	var accent := V2.rank_color(rank)
	var species_name := String(species.get("name", "Unknown"))

	_detail_body.add_child(_section_label("SELECTED FORM", V2.CYAN))

	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "EvolutionChartPortraitV2"
	portrait_frame.custom_minimum_size = Vector2(0.0, 174.0)
	portrait_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override("panel", V2.outlined_surface(accent, false, 8))
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

	var name_label := _label(species_name.to_upper(), 22, V2.TEXT, true)
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
		var current_label := _chip("CURRENT FORM", V2.AMBER)
		_detail_body.add_child(current_label)
		_detail_body.add_child(_label("LV %d   ·   POTENTIAL %d   ·   LINK %d" % [_instance.level, _instance.potential, _instance.link], 13, V2.TEXT, true))
		if not _instance.evolution_goal_seed.is_empty():
			var goal_species := _database.get_by_seed(_instance.evolution_goal_seed)
			if not goal_species.is_empty():
				_detail_body.add_child(_section_label("TARGET", V2.PURPLE))
				_detail_body.add_child(_label(String(goal_species.get("name", "Unknown")), 14, V2.PURPLE.lightened(0.18), true))
		return

	var direction := String(_direction_cache.get(_selected_seed, ""))
	var path := _cached_path(_selected_seed)

	if direction == "digivolution" or direction == "degeneration":
		var route := _direct_route_cache.get("%s|%s" % [direction, _selected_seed], {}) as Dictionary
		var route_accent := V2.GREEN if direction == "digivolution" else V2.CYAN
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
		_detail_body.add_child(_label("No extra requirements", 10, V2.GREEN, true))
		return
	for raw_evaluation in raw_evaluations:
		if not raw_evaluation is Dictionary:
			continue
		var evaluation := raw_evaluation as Dictionary
		var met := bool(evaluation.get("is_met", false))
		var supported := bool(evaluation.get("supported", true))
		var text := _requirement_result_text(evaluation)
		var prefix := "✓  " if met else "✕  "
		var color := V2.GREEN if met else V2.RED if supported else V2.ORANGE
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
		var clear_button := _button("CLEAR TARGET", V2.MUTED)
		clear_button.pressed.connect(_clear_goal)
		_detail_body.add_child(clear_button)
	else:
		var goal_button := _button("MARK AS TARGET", V2.PURPLE)
		goal_button.pressed.connect(_mark_selected_as_goal)
		_detail_body.add_child(goal_button)


func _chip(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent.lightened(0.12), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 27.0)
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label


func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent.lightened(0.08), true)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _layout() -> void:
	if not visible or _frame == null or _content_root == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := V2.is_compact(get_viewport(), DESKTOP_BREAKPOINT) or physical.y > physical.x * 1.08
	var edge := 10.0 if compact else 18.0
	var available := Vector2(
		maxf(1.0, physical.x - edge * 2.0),
		maxf(1.0, physical.y - edge * 2.0)
	)
	var width := minf(MAX_FRAME_SIZE.x, available.x)
	var height := minf(MAX_FRAME_SIZE.y, available.y)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor

	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)
	_frame.clip_contents = true
	_content_root.position = Vector2.ZERO
	_content_root.size = Vector2(width, height)

	_header_panel.position = Vector2.ZERO
	_header_panel.size = Vector2(width, HEADER_HEIGHT)
	_header_accent.position = Vector2(0.0, HEADER_HEIGHT - 2.0)
	_header_accent.size = Vector2(width, 2.0)
	_title.position = Vector2(24.0, 12.0)
	_title.size = Vector2(maxf(160.0, width - 112.0), 34.0)
	_subtitle.position = Vector2(25.0, 43.0)
	_subtitle.size = Vector2(maxf(160.0, width - 112.0), 22.0)
	_close_button.position = Vector2(width - V2.TOUCH_TARGET - 14.0, 12.0)
	_close_button.size = Vector2(V2.TOUCH_TARGET, V2.TOUCH_TARGET)

	var body_top := HEADER_HEIGHT + 12.0
	var body_bottom := 14.0
	var body_height := maxf(1.0, height - body_top - body_bottom)
	if compact:
		var gap := 12.0
		var detail_h := clampf(body_height * 0.36, 120.0, 300.0)
		var canvas_h := body_height - detail_h - gap
		if canvas_h < 110.0:
			detail_h = maxf(96.0, body_height - gap - 110.0)
			canvas_h = maxf(1.0, body_height - detail_h - gap)
		_canvas.position = Vector2(14.0, body_top)
		_canvas.size = Vector2(maxf(1.0, width - 28.0), canvas_h)
		_detail_panel.position = Vector2(14.0, body_top + canvas_h + gap)
		_detail_panel.size = Vector2(maxf(1.0, width - 28.0), detail_h)
	else:
		var side_margin := 14.0
		var detail_w := clampf(width * 0.29, 330.0, 420.0)
		var detail_x := width - side_margin - detail_w
		_canvas.position = Vector2(side_margin, body_top)
		_canvas.size = Vector2(maxf(280.0, detail_x - CONTENT_GAP - side_margin), body_height)
		_detail_panel.position = Vector2(detail_x, body_top)
		_detail_panel.size = Vector2(detail_w, body_height)

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
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(110.0, V2.TOUCH_TARGET)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled"))
	V2.apply_body(button)
	return button