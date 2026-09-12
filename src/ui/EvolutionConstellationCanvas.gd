extends Control
class_name EvolutionConstellationCanvas

signal node_selected(seed: String)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")

const NODE_SIZE := Vector2(176.0, 66.0)
const COLUMN_GAP := 238.0
const ROW_GAP := 104.0
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.45

var _nodes: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _base_positions: Dictionary = {}
var _buttons: Dictionary = {}
var _current_seed := ""
var _goal_seed := ""
var _history_edges: Dictionary = {}
var _goal_edges: Dictionary = {}
var _pan := Vector2.ZERO
var _zoom := 0.92
var _phase := 0.0
var _dragging := false
var _drag_pointer := -1
var _last_pointer := Vector2.ZERO
var _has_centered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)
	resized.connect(_refresh_layout)


func set_graph(graph: Dictionary, current_seed: String, history_edges: Dictionary, goal_seed: String = "", goal_edges: Dictionary = {}) -> void:
	_nodes.clear()
	_edges.clear()
	var raw_nodes = graph.get("nodes", [])
	if raw_nodes is Array:
		for raw in raw_nodes:
			if raw is Dictionary:
				_nodes.append((raw as Dictionary).duplicate(true))
	var raw_edges = graph.get("edges", [])
	if raw_edges is Array:
		for raw in raw_edges:
			if raw is Dictionary:
				_edges.append((raw as Dictionary).duplicate(true))
	_current_seed = current_seed
	_goal_seed = goal_seed
	_history_edges = history_edges.duplicate(true)
	_goal_edges = goal_edges.duplicate(true)
	_rebuild_nodes()
	call_deferred("center_on", current_seed)


func set_goal(goal_seed: String, goal_edges: Dictionary) -> void:
	_goal_seed = goal_seed
	_goal_edges = goal_edges.duplicate(true)
	_refresh_node_styles()
	queue_redraw()


func center_on(seed: String) -> void:
	if not _base_positions.has(seed):
		return
	var base := Vector2(_base_positions[seed]) + NODE_SIZE * 0.5
	_pan = -base
	_has_centered = true
	_refresh_layout()


func zoom_in() -> void:
	_set_zoom(_zoom + 0.12)


func zoom_out() -> void:
	_set_zoom(_zoom - 0.12)


func reset_view() -> void:
	_zoom = 0.92
	center_on(_current_seed)


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, 1000.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_zoom_at(mouse.position, _zoom + 0.10)
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_zoom_at(mouse.position, _zoom - 0.10)
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mouse.pressed
			_drag_pointer = 0 if mouse.pressed else -1
			_last_pointer = mouse.position
			accept_event()
			return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_pan += motion.relative / maxf(0.01, _zoom)
		_refresh_layout()
		accept_event()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _dragging:
			_dragging = true
			_drag_pointer = touch.index
			_last_pointer = touch.position
		elif not touch.pressed and touch.index == _drag_pointer:
			_dragging = false
			_drag_pointer = -1
		accept_event()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _dragging and drag.index == _drag_pointer:
			_pan += drag.relative / maxf(0.01, _zoom)
			_last_pointer = drag.position
			_refresh_layout()
			accept_event()


func _draw() -> void:
	_draw_stars()
	var center := size * 0.5
	for edge: Dictionary in _edges:
		var from_seed := String(edge.get("from", ""))
		var to_seed := String(edge.get("to", ""))
		if not _base_positions.has(from_seed) or not _base_positions.has(to_seed):
			continue
		var p1 := center + (Vector2(_base_positions[from_seed]) + NODE_SIZE * 0.5 + _pan) * _zoom
		var p2 := center + (Vector2(_base_positions[to_seed]) + NODE_SIZE * 0.5 + _pan) * _zoom
		var key := String(edge.get("key", ""))
		var color := Color(0.24, 0.48, 0.78, 0.34)
		var width := 1.8
		if _history_edges.has(key):
			color = Color(0.31, 0.86, 0.91, 0.78)
			width = 2.6
		if _goal_edges.has(key):
			color = Color(0.76, 0.49, 1.0, 0.94)
			width = 3.4
		draw_line(p1, p2, color, width * _zoom, true)
		var pulse_t := fmod(_phase * (0.30 if _goal_edges.has(key) else 0.18) + float(abs(key.hash()) % 100) / 100.0, 1.0)
		var pulse := p1.lerp(p2, pulse_t)
		var pulse_color := Color(color.r, color.g, color.b, minf(1.0, color.a + 0.25))
		draw_circle(pulse, (3.0 if _goal_edges.has(key) else 2.0) * _zoom, pulse_color)


func _draw_stars() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	for index in range(74):
		var fx := fmod(float(index * 97 + 31), 997.0) / 997.0
		var fy := fmod(float(index * 173 + 71), 991.0) / 991.0
		var pos := Vector2(fx * size.x, fy * size.y)
		var twinkle := 0.28 + 0.22 * (0.5 + 0.5 * sin(_phase * 1.4 + float(index) * 1.73))
		var radius := 0.7 + float(index % 3) * 0.45
		draw_circle(pos, radius, Color(0.48, 0.72, 1.0, twinkle))
	for index in range(12):
		var fx := fmod(float(index * 211 + 53), 983.0) / 983.0
		var fy := fmod(float(index * 149 + 23), 977.0) / 977.0
		var pos := Vector2(fx * size.x, fy * size.y)
		var glow := 0.07 + 0.025 * sin(_phase + float(index))
		draw_circle(pos, 18.0 + float(index % 4) * 7.0, Color(0.22, 0.18, 0.48, glow))


func _rebuild_nodes() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	_base_positions.clear()
	var by_rank: Dictionary = {}
	for node: Dictionary in _nodes:
		var rank_index := int(node.get("rank_index", 99))
		if not by_rank.has(rank_index):
			by_rank[rank_index] = []
		(by_rank[rank_index] as Array).append(node)

	var rank_keys: Array = by_rank.keys()
	rank_keys.sort()
	for column_index in range(rank_keys.size()):
		var rank_key := int(rank_keys[column_index])
		var group: Array = by_rank[rank_key]
		var total_height := maxf(0.0, float(group.size() - 1) * ROW_GAP)
		for row_index in range(group.size()):
			var node := group[row_index] as Dictionary
			var seed := String(node.get("seed", ""))
			var base := Vector2(float(column_index) * COLUMN_GAP, float(row_index) * ROW_GAP - total_height * 0.5)
			_base_positions[seed] = base
			var button := _create_node_button(node)
			_buttons[seed] = button
			add_child(button)
	_refresh_node_styles()
	_refresh_layout()
	_configure_focus_neighbors()
	queue_redraw()


func _create_node_button(node: Dictionary) -> Button:
	var seed := String(node.get("seed", ""))
	var button := Button.new()
	button.name = "EvolutionNode_%s" % seed.replace("-", "_")
	button.text = "%s\n%s" % [String(node.get("name", "Unknown")).to_upper(), String(node.get("rank", "Unknown")).to_upper()]
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(func(): node_selected.emit(seed))
	return button


func _refresh_node_styles() -> void:
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
		var accent := UI.BLUE.lightened(0.05)
		if _node_was_experienced(seed):
			accent = UI.CYAN
		if seed == _goal_seed:
			accent = UI.PURPLE.lightened(0.12)
		if seed == _current_seed:
			accent = UI.GOLD
		SKIN.apply_button(button, accent)
		if seed == _current_seed:
			button.add_theme_stylebox_override("normal", SKIN.border_style(UI.GOLD, Vector4(14, 9, 14, 9), 12.0))
			button.add_theme_color_override("font_color", Color.WHITE)
		elif seed == _goal_seed:
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.34, 0.20, 0.48, 1.0), Vector4(14, 9, 14, 9)))


func _node_was_experienced(seed: String) -> bool:
	if seed == _current_seed:
		return true
	for key in _history_edges.keys():
		if String(key).begins_with(seed + "|") or String(key).ends_with("|" + seed):
			return true
	return false


func _refresh_layout() -> void:
	if _buttons.is_empty():
		return
	var center := size * 0.5
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		var base := Vector2(_base_positions.get(seed, Vector2.ZERO))
		button.scale = Vector2.ONE * _zoom
		button.position = center + (base + _pan) * _zoom
	queue_redraw()


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_refresh_layout()


func _zoom_at(pointer: Vector2, value: float) -> void:
	var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, _zoom):
		return
	var center := size * 0.5
	var world_before := (pointer - center) / _zoom - _pan
	_zoom = next_zoom
	_pan = (pointer - center) / _zoom - world_before
	_refresh_layout()


func _configure_focus_neighbors() -> void:
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		var source := Vector2(_base_positions.get(seed, Vector2.ZERO))
		button.focus_neighbor_left = _neighbor_path(seed, source, Vector2.LEFT)
		button.focus_neighbor_right = _neighbor_path(seed, source, Vector2.RIGHT)
		button.focus_neighbor_top = _neighbor_path(seed, source, Vector2.UP)
		button.focus_neighbor_bottom = _neighbor_path(seed, source, Vector2.DOWN)


func _neighbor_path(seed: String, source: Vector2, direction: Vector2) -> NodePath:
	var best_seed := ""
	var best_score := INF
	for raw_other in _buttons.keys():
		var other := String(raw_other)
		if other == seed:
			continue
		var delta := Vector2(_base_positions.get(other, Vector2.ZERO)) - source
		if delta.dot(direction) <= 8.0:
			continue
		var lateral := absf(delta.cross(direction))
		var score := delta.length() + lateral * 0.45
		if score < best_score:
			best_score = score
			best_seed = other
	if best_seed.is_empty():
		return NodePath("")
	return get_path_to(_buttons[best_seed] as Node)
