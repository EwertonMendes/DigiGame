extends "res://src/ui/EvolutionConstellationCanvas.gd"
class_name EvolutionChartCanvas

# Progressive exploration: the current form and all direct Digivolution /
# Degeneration routes are visible immediately. Selecting a connected form then
# advances the trail and reveals only that form's next choices.

var _initializing_chart := false
var _ignore_center_requests := false


func set_graph(graph: Dictionary, current_seed: String, history_edges: Dictionary, goal_seed: String = "", goal_edges: Dictionary = {}) -> void:
	# Suppress the parent canvas' deferred centering/tween during first build.
	# Those asynchronous operations could finish after the chart was laid out and
	# move the cards away from the connection lines for a few frames (or until the
	# user interacted with the canvas).
	_initializing_chart = true
	_ignore_center_requests = true
	super.set_graph(graph, current_seed, history_edges, goal_seed, goal_edges)
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
	var fit_zoom := minf(DEFAULT_ZOOM, safe_size.x / maxf(1.0, content_size.x), safe_size.y / maxf(1.0, content_size.y))
	_zoom = clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)
	_pan = -graph_center
	_has_centered = true
	_refresh_layout()


func _animate_relayout(new_seeds: Array[String], source_seed: String) -> void:
	if _initializing_chart:
		for raw_seed in _buttons.keys():
			var button := _buttons[raw_seed] as Button
			if button != null:
				button.modulate.a = 1.0
				button.scale = Vector2.ONE * _zoom
		_refresh_layout()
		return
	super._animate_relayout(new_seeds, source_seed)


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
	super._refresh_node_styles()
	# Keep the node copy clean: only the current form carries a status caption.
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
		var status := _find_status_label(button)
		if status == null:
			continue
		status.visible = seed == _current_seed
		status.custom_minimum_size = Vector2.ZERO
		if status.visible:
			status.text = "CURRENT FORM"
			status.add_theme_color_override("font_color", UI.GOLD)
