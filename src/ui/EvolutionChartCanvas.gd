extends "res://src/ui/EvolutionConstellationCanvas.gd"
class_name EvolutionChartCanvas

# Focused exploration keeps the active lineage permanently visible while only
# revealing the direct routes around the form the player is currently inspecting.
# The lineage owns the center lane. Alternative branches get a stable upper/lower
# side, but their exact row is recomputed compactly so repeated exploration cannot
# push cards farther and farther away from their parent.

const LINK_SIGNAL_PRIMARY_SPEED := 0.10
const LINK_SIGNAL_SECONDARY_SPEED := 0.075
const CURRENT_FLAME_SPEED := 0.075
const SELECTED_FLAME_SPEED := 0.060

var _initializing_chart := false
var _ignore_center_requests := false
var _primary_route: Array[String] = []
var _primary_edges: Dictionary = {}
var _focus_bridge_path: Array[String] = []
var _focus_bridge_edges: Dictionary = {}
var _branch_lanes: Dictionary = {}
var _focus_lane := 0


func set_graph(graph: Dictionary, current_seed: String, history_edges: Dictionary, goal_seed: String = "", goal_edges: Dictionary = {}) -> void:
	_initializing_chart = true
	_ignore_center_requests = true
	_primary_route.clear()
	_primary_edges.clear()
	_focus_bridge_path.clear()
	_focus_bridge_edges.clear()
	_branch_lanes.clear()
	_focus_lane = 0
	super.set_graph(graph, current_seed, history_edges, goal_seed, goal_edges)
	_primary_route = _derive_primary_route()
	_primary_edges = _edge_keys_for_path(_primary_route)
	for seed: String in _primary_route:
		_branch_lanes[seed] = 0
	_selected_seed = current_seed
	_refresh_focus_bridge()
	_branch_open = true
	_rebuild_visible_nodes(current_seed)
	_initializing_chart = false
	call_deferred("_finish_initial_layout")


func center_on(seed: String) -> void:
	if _ignore_center_requests:
		return
	super.center_on(seed)


func _finish_initial_layout() -> void:
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

	_apply_fit_transform()
	super._animate_relayout(new_seeds, source_seed)


func _activate_node(seed: String) -> void:
	if not _buttons.has(seed):
		return

	# Capture the currently rendered lane before rebuilding. This is side memory:
	# a branch that was above remains an upper branch, and one below remains lower.
	_focus_lane = _lane_for_seed(seed)
	_selected_seed = seed
	_refresh_focus_bridge()
	_trail.clear()
	_trail.append(seed)
	_branch_open = true
	_rebuild_visible_nodes(seed)
	node_selected.emit(seed)


func _visible_seeds_for_state() -> Array[String]:
	var result: Array[String] = []
	for seed: String in _primary_route:
		_add_unique_seed(result, seed)

	# Keep a continuous bridge from the inspected form to the current form. This
	# prevents the current Digimon from ever appearing as a disconnected island.
	for seed: String in _focus_bridge_path:
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


func _refresh_focus_bridge() -> void:
	_focus_bridge_path = _find_connection_path(_selected_seed, _current_seed)
	_focus_bridge_edges = _edge_keys_for_path(_focus_bridge_path)


func _find_connection_path(start_seed: String, target_seed: String) -> Array[String]:
	var empty: Array[String] = []
	if start_seed.is_empty() or target_seed.is_empty():
		return empty
	if start_seed == target_seed:
		return [start_seed]
	if not _nodes_by_seed.has(start_seed) or not _nodes_by_seed.has(target_seed):
		return empty

	var queue: Array[String] = [start_seed]
	var previous: Dictionary = {start_seed: ""}
	while not queue.is_empty():
		var cursor: String = String(queue.pop_front())
		for neighbor: String in _neighbors(cursor):
			if previous.has(neighbor):
				continue
			previous[neighbor] = cursor
			if neighbor == target_seed:
				var reversed: Array[String] = []
				var path_cursor := target_seed
				while not path_cursor.is_empty():
					reversed.append(path_cursor)
					if path_cursor == start_seed:
						break
					path_cursor = String(previous.get(path_cursor, ""))
				if reversed.is_empty() or reversed[reversed.size() - 1] != start_seed:
					return empty
				reversed.reverse()
				return reversed
			queue.append(neighbor)
	return empty


func _derive_primary_route() -> Array[String]:
	var route: Array[String] = []
	if _current_seed.is_empty() or not _nodes_by_seed.has(_current_seed):
		return route

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


func _lane_for_seed(seed: String) -> int:
	if _primary_route.has(seed):
		return 0
	if _branch_lanes.has(seed):
		return int(_branch_lanes[seed])
	if _base_positions.has(seed):
		var y := Vector2(_base_positions[seed]).y
		var inferred := int(round(y / ROW_GAP))
		return inferred
	return 0


func _lane_side(lane: int) -> int:
	if lane < 0:
		return -1
	if lane > 0:
		return 1
	return 0


func _balanced_lane_for_index(index: int) -> int:
	var distance := int(index / 2) + 1
	return -distance if index % 2 == 0 else distance


func _nearest_open_lane(occupied: Dictionary, preferred_lane: int, side: int) -> int:
	if preferred_lane != 0 and not occupied.has(preferred_lane):
		return preferred_lane

	if side == 0:
		for distance in range(1, 64):
			var above := -distance
			if not occupied.has(above):
				return above
			var below := distance
			if not occupied.has(below):
				return below
		return occupied.size() + 1

	var preferred_magnitude := maxi(1, absi(preferred_lane))
	for radius in range(0, 64):
		if radius == 0:
			var exact := side * preferred_magnitude
			if not occupied.has(exact):
				return exact
			continue

		var inner_magnitude := preferred_magnitude - radius
		if inner_magnitude >= 1:
			var inner := side * inner_magnitude
			if not occupied.has(inner):
				return inner

		var outer := side * (preferred_magnitude + radius)
		if not occupied.has(outer):
			return outer

	return side * (occupied.size() + 1)


func _claim_lane(seed: String, occupied: Dictionary, preferred_lane: int, side: int) -> int:
	var resolved_side := side
	if resolved_side == 0:
		resolved_side = _lane_side(preferred_lane)
	var lane := preferred_lane
	if lane == 0:
		lane = resolved_side if resolved_side != 0 else _nearest_open_lane(occupied, 0, 0)
	lane = _nearest_open_lane(occupied, lane, resolved_side)
	occupied[lane] = true
	_branch_lanes[seed] = lane
	return lane


func _prepare_focus_neighbor_lanes(visible_seeds: Array[String]) -> void:
	var focus_seed := _selected_seed if _nodes_by_seed.has(_selected_seed) else _current_seed
	var focus_lane := _lane_for_seed(focus_seed)
	var focus_side := _lane_side(focus_lane)
	var candidates: Array[String] = []

	for neighbor: String in _neighbors(focus_seed):
		if not visible_seeds.has(neighbor):
			continue
		if _primary_route.has(neighbor) or neighbor == _current_seed:
			continue
		candidates.append(neighbor)

	candidates.sort_custom(func(a: String, b: String) -> bool:
		var ar := _rank_index_for(a)
		var br := _rank_index_for(b)
		if ar == br:
			return String((_nodes_by_seed.get(a, {}) as Dictionary).get("name", "")) < String((_nodes_by_seed.get(b, {}) as Dictionary).get("name", ""))
		return ar < br
	)

	if candidates.is_empty():
		return

	if focus_side == 0:
		# A main-line form always opens its alternatives on BOTH sides. We recompute
		# these lanes deterministically every time, so stale exploration state can
		# never collapse every option above or below the selected Digimon.
		for index in range(candidates.size()):
			_branch_lanes[candidates[index]] = _balanced_lane_for_index(index)
		return

	# A branch keeps growing on the side where it was opened. The bridge back to
	# the current form keeps its existing lane; newly revealed choices start at the
	# focus row and only move one row farther out when siblings need space.
	var next_offset := 0
	var focus_magnitude := maxi(1, absi(focus_lane))
	for seed: String in candidates:
		var edge_key := _edge_key(focus_seed, seed)
		if _focus_bridge_edges.has(edge_key) and _branch_lanes.has(seed):
			continue
		var existing_lane := int(_branch_lanes.get(seed, 0))
		if _lane_side(existing_lane) == focus_side and existing_lane != 0:
			continue
		_branch_lanes[seed] = focus_side * (focus_magnitude + next_offset)
		next_offset += 1


func _recalculate_positions(visible_seeds: Array[String]) -> void:
	_base_positions.clear()
	if visible_seeds.is_empty():
		return

	for seed: String in _primary_route:
		_branch_lanes[seed] = 0

	_prepare_focus_neighbor_lanes(visible_seeds)

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

		# Lane zero remains reserved for the active lineage even at ranks where the
		# current focused subset has no lineage card. This keeps route semantics clear.
		var occupied: Dictionary = {0: true}
		var x := float(rank_index - current_rank) * COLUMN_GAP
		var lineage_seed := _primary_seed_at_rank(rank_index, group)
		if not lineage_seed.is_empty():
			_base_positions[lineage_seed] = Vector2(x, 0.0)

		# The selected branch receives its preferred row first, then bridge nodes,
		# then other branches. This prevents a temporary sibling from pushing the
		# important selected/current connection several rows away.
		if group.has(_selected_seed) and _selected_seed != lineage_seed:
			var selected_preferred := int(_branch_lanes.get(_selected_seed, _focus_lane))
			var selected_side := _lane_side(selected_preferred)
			var selected_lane := _claim_lane(_selected_seed, occupied, selected_preferred, selected_side)
			_base_positions[_selected_seed] = Vector2(x, float(selected_lane) * ROW_GAP)

		for raw_seed in group:
			var seed := String(raw_seed)
			if _base_positions.has(seed) or not _focus_bridge_path.has(seed) or not _branch_lanes.has(seed):
				continue
			var preferred := int(_branch_lanes[seed])
			var side := _lane_side(preferred)
			var lane := _claim_lane(seed, occupied, preferred, side)
			_base_positions[seed] = Vector2(x, float(lane) * ROW_GAP)

		for raw_seed in group:
			var seed := String(raw_seed)
			if _base_positions.has(seed) or not _branch_lanes.has(seed):
				continue
			var preferred := int(_branch_lanes[seed])
			var side := _lane_side(preferred)
			var lane := _claim_lane(seed, occupied, preferred, side)
			_base_positions[seed] = Vector2(x, float(lane) * ROW_GAP)

		for raw_seed in group:
			var seed := String(raw_seed)
			if _base_positions.has(seed):
				continue
			var lane := _claim_lane(seed, occupied, _nearest_open_lane(occupied, 0, 0), 0)
			_base_positions[seed] = Vector2(x, float(lane) * ROW_GAP)


func _primary_seed_at_rank(rank_index: int, group: Array) -> String:
	for seed: String in _primary_route:
		if _rank_index_for(seed) == rank_index and group.has(seed):
			return seed
	return ""


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
		if _focus_bridge_edges.has(key):
			color = Color(0.34, 0.66, 0.94, 0.74)
			width = 2.3
			emphasized = true
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
			var speed := LINK_SIGNAL_PRIMARY_SPEED if _primary_edges.has(key) or _goal_edges.has(key) else LINK_SIGNAL_SECONDARY_SPEED
			var pulse_t := fmod(_phase * speed + float(abs(key.hash()) % 100) / 100.0, 1.0)
			_draw_signal_packet(p1, p2, pulse_t, Color(color.r, color.g, color.b, minf(0.86, color.a + 0.06)), average_scale)

	# Calm digital-fire activity rises from behind the highlighted cards. The
	# fragments are drawn by this parent before Button children, so the card itself
	# masks the effect and the sprite/name/status stay completely readable.
	if _buttons.has(_current_seed):
		_draw_digital_flame(_current_seed, UI.GOLD, UI.CYAN, 11, CURRENT_FLAME_SPEED, 1.0)
	if _selected_seed != _current_seed and _buttons.has(_selected_seed):
		_draw_digital_flame(_selected_seed, Color(0.40, 0.76, 1.0, 1.0), Color(0.28, 0.90, 0.96, 1.0), 7, SELECTED_FLAME_SPEED, 0.72)


func _draw_signal_packet(p1: Vector2, p2: Vector2, t: float, color: Color, scale_factor: float) -> void:
	var direction := (p2 - p1).normalized()
	if direction == Vector2.ZERO:
		return
	var normal := Vector2(-direction.y, direction.x)
	var center := p1.lerp(p2, t)
	var half_length := 3.2 * scale_factor
	var half_width := 0.85 * scale_factor
	var points := PackedVector2Array([
		center - direction * half_length - normal * half_width,
		center + direction * half_length - normal * half_width,
		center + direction * half_length + normal * half_width,
		center - direction * half_length + normal * half_width,
	])
	draw_colored_polygon(points, color)


func _draw_digital_flame(seed: String, primary: Color, secondary: Color, count: int, speed: float, intensity: float) -> void:
	var button := _buttons.get(seed) as Button
	if button == null or count <= 0:
		return

	var scale_factor := _button_scale(seed)
	var rect := Rect2(button.position, NODE_SIZE * scale_factor)
	var top_y := rect.position.y
	var usable_width := rect.size.x * 0.84
	var left_x := rect.position.x + rect.size.x * 0.08
	var seed_offset := float(abs(seed.hash()) % 997) / 997.0

	for index in range(count):
		var lane_t := (float(index) + 0.5) / float(count)
		var local_speed := speed * (0.84 + float(index % 4) * 0.07)
		var life := fmod(_phase * local_speed + seed_offset + float(index) * 0.137, 1.0)
		var rise := (3.0 + life * (22.0 + float(index % 3) * 5.0)) * scale_factor
		var sway := sin(_phase * 0.42 + float(index) * 1.71) * 2.2 * scale_factor
		var x := left_x + usable_width * lane_t + sway
		var y := top_y + 2.0 * scale_factor - rise

		var fade := sin(life * PI)
		var color := primary if index % 3 != 1 else secondary
		color.a = clampf((0.16 + fade * 0.34) * intensity, 0.08, 0.50)

		var block_width := (2.0 + float(index % 3)) * scale_factor
		var block_height := (4.0 + float((index * 3) % 5)) * scale_factor
		var main_rect := Rect2(
			Vector2(x - block_width * 0.5, y),
			Vector2(block_width, block_height)
		)
		draw_rect(main_rect, color, true)

		# A smaller offset block beneath each fragment creates a stepped, pixel-like
		# flame silhouette instead of generic spark/confetti particles.
		var trail_color := color
		trail_color.a *= 0.42
		var trail_width := maxf(1.0 * scale_factor, block_width * 0.62)
		var trail_height := maxf(1.5 * scale_factor, block_height * 0.46)
		var trail_shift := (-1.0 if index % 2 == 0 else 1.0) * 1.5 * scale_factor
		var trail_rect := Rect2(
			Vector2(x - trail_width * 0.5 + trail_shift, y + block_height + 1.5 * scale_factor),
			Vector2(trail_width, trail_height)
		)
		draw_rect(trail_rect, trail_color, true)

	# A very subtle segmented source line makes the fragments read as energy/flame
	# coming from behind the card rather than unrelated floating pixels.
	for segment in range(5):
		var segment_t := (float(segment) + 0.5) / 5.0
		var segment_width := rect.size.x * 0.095
		var segment_x := rect.position.x + rect.size.x * (0.18 + segment_t * 0.64) - segment_width * 0.5
		var source_color := primary if segment % 2 == 0 else secondary
		source_color.a = 0.11 * intensity
		draw_rect(
			Rect2(Vector2(segment_x, top_y - 1.5 * scale_factor), Vector2(segment_width, 2.0 * scale_factor)),
			source_color,
			true
		)


func _button_screen_center(seed: String) -> Vector2:
	var button := _buttons.get(seed) as Button
	if button == null:
		return Vector2.ZERO
	return button.position + NODE_SIZE * 0.5 * button.scale.x


func _button_scale(seed: String) -> float:
	var button := _buttons.get(seed) as Button
	return maxf(0.01, button.scale.x) if button != null else maxf(0.01, _zoom)
