extends "res://src/ui/EvolutionConstellationCanvas.gd"
class_name EvolutionChartCanvas

# Focused exploration keeps the active lineage permanently visible while only
# revealing the direct routes around the form the player is currently inspecting.
# This preserves the freedom of a graph without allowing exploration to turn into
# an unreadable accumulation of every previously opened branch.

var _initializing_chart := false
var _ignore_center_requests := false
var _primary_route: Array[String] = []
var _primary_edges: Dictionary = {}


func set_graph(graph: Dictionary, current_seed: String, history_edges: Dictionary, goal_seed: String = "", goal_edges: Dictionary = {}) -> void:
	# Suppress the parent canvas' deferred centering/tween during first build.
	_initializing_chart = true
	_ignore_center_requests = true
	_primary_route.clear()
	_primary_edges.clear()
	super.set_graph(graph, current_seed, history_edges, goal_seed, goal_edges)
	_primary_route = _derive_primary_route()
	_primary_edges = _edge_keys_for_path(_primary_route)
	_selected_seed = current_seed
	_branch_open = true
	_rebuild_visible_nodes(current_seed)
	_initializing_chart = false
	call_deferred("_finish_initial_layout")


func center_on(seed: String) -> void:
	if _ignore_center_requests:
		return
	super.center_on(seed)


func _finish_initial_layout() -> void:
	# Wait until EvolutionChart has assigned the real canvas rectangle.
	await get_tree().process_frame
	_ignore_center_requests = false
	_fit_visible_graph()
	_refresh_node_styles()
	queue_redraw()


func _fit_visible_graph() -> void:
	_apply_fit_transform()
	_refresh_layout()


func _apply_fit_transform() -> void:
	if _buttons.is_empty() or size.x <= 1.0 or size.y <= 1.0:
		return
	var min_center := Vector2(INF, INF)
	var max_center := Vector2(-INF, -INF)
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		if not _base_positions.has(seed):
			continue
		var node_center := Vector2(_base_positions[seed]) + NODE_SIZE * 0.5
		min_center.x = minf(min_center.x, node_center.x)
		min_center.y = minf(min_center.y, node_center.y)
		max_center.x = maxf(max_center.x, node_center.x)
		max_center.y = maxf(max_center.y, node_center.y)
	if is_inf(min_center.x):
		return

	var graph_center := (min_center + max_center) * 0.5
	var content_size := (max_center - min_center) + NODE_SIZE
	var safe_size := Vector2(maxf(120.0, size.x - 72.0), maxf(120.0, size.y - 72.0))
	var horizontal_fit := safe_size.x / maxf(1.0, content_size.x)
	var vertical_fit := safe_size.y / maxf(1.0, content_size.y)
	var fit_zoom := minf(DEFAULT_ZOOM, minf(horizontal_fit, vertical_fit))
	_zoom = clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)
	_pan = -graph_center
	_has_centered = true


func _animate_relayout(new_seeds: Array[String], source_seed: String) -> void:
	if _initializing_chart:
		for raw_seed in _buttons.keys():
			var button := _buttons[raw_seed] as Button
			if button != null:
				button.modulate.a = 1.0
				button.scale = Vector2.ONE * _zoom
		_refresh_layout()
		return

	# Calculate the final framing before the inherited tween creates its targets.
	# Existing cards therefore glide into the new focused composition instead of
	# snapping when the visible branch changes.
	_apply_fit_transform()
	super._animate_relayout(new_seeds, source_seed)


func _activate_node(seed: String) -> void:
	if not _buttons.has(seed):
		return
	_selected_seed = seed
	_trail.clear()
	_trail.append(seed)
	_branch_open = true
	_rebuild_visible_nodes(seed)
	node_selected.emit(seed)


func _visible_seeds_for_state() -> Array[String]:
	var result: Array[String] = []
	for seed: String in _primary_route:
		_add_unique_seed(result, seed)
	_add_unique_seed(result, _current_seed)

	var focus_seed := _selected_seed if _nodes_by_seed.has(_selected_seed) else _current_seed
	_add_unique_seed(result, focus_seed)
	for neighbor: String in _neighbors(focus_seed):
		_add_unique_seed(result, neighbor)
	return result


func _add_unique_seed(target: Array[String], seed: String) -> void:
	if not seed.is_empty() and _nodes_by_seed.has(seed) and not target.has(seed):
		target.append(seed)


func _derive_primary_route() -> Array[String]:
	var route: Array[String] = []
	if _current_seed.is_empty() or not _nodes_by_seed.has(_current_seed):
		return route

	# EvolutionGraphService stores the most recent traversal index in each
	# experienced edge. Walking backwards through lower ranks with a decreasing
	# history index reconstructs the active lineage while naturally discarding old
	# branches and degeneration loops.
	route.append(_current_seed)
	var visited: Dictionary = {_current_seed: true}
	var cursor := _current_seed
	var history_cutoff := 2147483647

	while true:
		var cursor_rank := _rank_index_for(cursor)
		var best_seed := ""
		var best_order := -1
		var best_rank := -1
		for neighbor: String in _neighbors(cursor):
			if visited.has(neighbor):
				continue
			var neighbor_rank := _rank_index_for(neighbor)
			if neighbor_rank >= cursor_rank:
				continue
			var key := _edge_key(cursor, neighbor)
			if not _history_edges.has(key):
				continue
			var order := int(_history_edges.get(key, 0))
			if order <= 0 or order >= history_cutoff:
				continue
			if order > best_order or (order == best_order and neighbor_rank > best_rank):
				best_seed = neighbor
				best_order = order
				best_rank = neighbor_rank
		if best_seed.is_empty():
			break
		route.push_front(best_seed)
		visited[best_seed] = true
		cursor = best_seed
		history_cutoff = best_order
	return route


func _edge_keys_for_path(path: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for index in range(maxi(0, path.size() - 1)):
		result[_edge_key(path[index], path[index + 1])] = true
	return result


func _rank_index_for(seed: String) -> int:
	var node := _nodes_by_seed.get(seed, {}) as Dictionary
	return int(node.get("rank_index", 99)) if not node.is_empty() else 99


func _recalculate_positions(visible_seeds: Array[String]) -> void:
	_base_positions.clear()
	if visible_seeds.is_empty():
		return

	var current_rank := _rank_index_for(_current_seed)
	var by_rank: Dictionary = {}
	for seed: String in visible_seeds:
		var rank_index := _rank_index_for(seed)
		if not by_rank.has(rank_index):
			by_rank[rank_index] = []
		(by_rank[rank_index] as Array).append(seed)

	for raw_rank in by_rank.keys():
		var rank_index := int(raw_rank)
		var group: Array = by_rank[raw_rank]
		group.sort_custom(func(a, b) -> bool:
			return String((_nodes_by_seed.get(String(a), {}) as Dictionary).get("name", "")) < String((_nodes_by_seed.get(String(b), {}) as Dictionary).get("name", ""))
		)
		var occupied: Dictionary = {}
		var x := float(rank_index - current_rank) * COLUMN_GAP
		var lineage_seed := _primary_seed_at_rank(rank_index, group)
		if not lineage_seed.is_empty():
			_base_positions[lineage_seed] = Vector2(x, 0.0)
			occupied[0] = true

		if group.has(_selected_seed) and _selected_seed != lineage_seed:
			var selected_lane := 0 if lineage_seed.is_empty() else 1
			_base_positions[_selected_seed] = Vector2(x, float(selected_lane) * ROW_GAP)
			occupied[selected_lane] = true

		for raw_seed in group:
			var seed := String(raw_seed)
			if _base_positions.has(seed):
				continue
			var lane := _next_open_lane(occupied)
			occupied[lane] = true
			_base_positions[seed] = Vector2(x, float(lane) * ROW_GAP)


func _primary_seed_at_rank(rank_index: int, group: Array) -> String:
	for seed: String in _primary_route:
		if _rank_index_for(seed) == rank_index and group.has(seed):
			return seed
	return ""


func _next_open_lane(occupied: Dictionary) -> int:
	if not occupied.has(0):
		return 0
	for distance in range(1, 32):
		var above := -distance
		if not occupied.has(above):
			return above
		var below := distance
		if not occupied.has(below):
			return below
	return occupied.size() + 1


func _create_node_button(node: Dictionary) -> Button:
	var button := super._create_node_button(node)
	var status := _find_status_label(button)
	if status != null:
		status.visible = String(node.get("seed", "")) == _current_seed
		if status.visible:
			status.text = "CURRENT FORM"
			status.add_theme_color_override("font_color", UI.GOLD)
	return button


func _refresh_node_styles() -> void:
	var primary_lookup: Dictionary = {}
	for seed: String in _primary_route:
		primary_lookup[seed] = true

	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
		var node := _nodes_by_seed.get(seed, {}) as Dictionary
		var rank := String(node.get("rank", "Unknown"))
		var accent := UI.rank_color(rank)
		if primary_lookup.has(seed):
			accent = UI.CYAN
		if seed == _goal_seed:
			accent = UI.PURPLE.lightened(0.12)
		if seed == _current_seed:
			accent = UI.GOLD

		SKIN.apply_button(button, accent)
		button.modulate.a = 1.0 if primary_lookup.has(seed) or seed == _selected_seed or seed == _current_seed else 0.88
		if seed == _current_seed:
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.36, 0.27, 0.09, 0.99), Vector4(10, 8, 10, 8), 12.0))
			button.add_theme_stylebox_override("hover", SKIN.border_style(UI.GOLD.lightened(0.14), Vector4(10, 8, 10, 8), 12.0))
			button.tooltip_text = "Current form"
		elif seed == _selected_seed:
			button.add_theme_stylebox_override("normal", SKIN.border_style(accent.lightened(0.16), Vector4(10, 8, 10, 8), 12.0))
			button.add_theme_stylebox_override("hover", SKIN.border_style(accent.lightened(0.24), Vector4(10, 8, 10, 8), 12.0))
			button.tooltip_text = "Focused form · select a connected card to continue exploring"
		elif seed == _goal_seed:
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.29, 0.16, 0.42, 0.98), Vector4(10, 8, 10, 8), 12.0))
			button.tooltip_text = "Evolution target"
		elif primary_lookup.has(seed):
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.035, 0.15, 0.19, 0.97), Vector4(10, 8, 10, 8), 12.0))
			button.add_theme_stylebox_override("hover", SKIN.border_style(UI.CYAN.lightened(0.12), Vector4(10, 8, 10, 8), 12.0))
			button.tooltip_text = "Previous form on this Digimon's active lineage"
		else:
			button.tooltip_text = "Select to focus this form and reveal its connected routes"

		var status := _find_status_label(button)
		if status != null:
			status.visible = seed == _current_seed
			status.custom_minimum_size = Vector2.ZERO
			if status.visible:
				status.text = "CURRENT FORM"
				status.add_theme_color_override("font_color", UI.GOLD)


func _draw() -> void:
	_draw_space_backdrop()
	var visible := _visible_seed_dictionary()
	for edge: Dictionary in _edges:
		var from_seed := String(edge.get("from", ""))
		var to_seed := String(edge.get("to", ""))
		if not visible.has(from_seed) or not visible.has(to_seed):
			continue
		if not _buttons.has(from_seed) or not _buttons.has(to_seed):
			continue

		var p1 := _button_screen_center(from_seed)
		var p2 := _button_screen_center(to_seed)
		var key := String(edge.get("key", ""))
		var color := Color(0.24, 0.46, 0.74, 0.28)
		var width := 1.5
		var emphasized := false

		if _history_edges.has(key):
			color = Color(0.28, 0.60, 0.68, 0.36)
			width = 1.7
		if from_seed == _selected_seed or to_seed == _selected_seed:
			color = Color(0.38, 0.72, 1.0, 0.88)
			width = 2.7
			emphasized = true
		if _primary_edges.has(key):
			color = Color(0.28, 0.86, 0.92, 0.96)
			width = 3.2
			emphasized = true
		if _goal_edges.has(key):
			color = Color(0.72, 0.45, 1.0, 0.98)
			width = 3.5
			emphasized = true

		var average_scale := (_button_scale(from_seed) + _button_scale(to_seed)) * 0.5
		draw_line(p1, p2, Color(0.035, 0.075, 0.16, 0.88), (width + 3.0) * average_scale, true)
		draw_line(p1, p2, color, width * average_scale, true)
		if emphasized:
			var speed := 0.32 if _primary_edges.has(key) or _goal_edges.has(key) else 0.24
			var pulse_t := fmod(_phase * speed + float(abs(key.hash()) % 100) / 100.0, 1.0)
			var pulse := p1.lerp(p2, pulse_t)
			draw_circle(pulse, 2.8 * average_scale, Color(color.r, color.g, color.b, minf(1.0, color.a + 0.12)))

	if _buttons.has(_current_seed):
		var current_center := _button_screen_center(_current_seed)
		var current_scale := _button_scale(_current_seed)
		var ring := 60.0 + 3.0 * sin(_phase * 2.2)
		draw_arc(current_center, ring * current_scale, 0.0, TAU, 48, Color(1.0, 0.78, 0.28, 0.40), 2.3 * current_scale, true)
		draw_arc(current_center, (ring + 9.0) * current_scale, 0.0, TAU, 48, Color(0.30, 0.84, 0.92, 0.16), 1.2 * current_scale, true)

	if _selected_seed != _current_seed and _buttons.has(_selected_seed):
		var selected_center := _button_screen_center(_selected_seed)
		var selected_scale := _button_scale(_selected_seed)
		var selected_ring := 56.0 + 2.0 * sin(_phase * 1.9)
		draw_arc(selected_center, selected_ring * selected_scale, 0.0, TAU, 40, Color(0.38, 0.72, 1.0, 0.24), 1.7 * selected_scale, true)


func _button_screen_center(seed: String) -> Vector2:
	var button := _buttons.get(seed) as Button
	if button == null:
		return Vector2.ZERO
	return button.position + NODE_SIZE * 0.5 * button.scale.x


func _button_scale(seed: String) -> float:
	var button := _buttons.get(seed) as Button
	return maxf(0.01, button.scale.x) if button != null else maxf(0.01, _zoom)
