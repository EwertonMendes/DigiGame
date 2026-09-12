extends Control
class_name EvolutionConstellationCanvas

signal node_selected(seed: String)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const NEBULA_TEXTURE = preload("res://assets/backgrounds/Nebula Blue.png")

const NODE_SIZE := Vector2(204.0, 92.0)
const COLUMN_GAP := 252.0
const ROW_GAP := 116.0
const MIN_ZOOM := 0.58
const MAX_ZOOM := 1.38
const DEFAULT_ZOOM := 0.94
const REVEAL_DURATION := 0.24

var _nodes: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _nodes_by_seed: Dictionary = {}
var _base_positions: Dictionary = {}
var _buttons: Dictionary = {}
var _fallback_icons: Dictionary = {}
var _current_seed := ""
var _selected_seed := ""
var _goal_seed := ""
var _history_edges: Dictionary = {}
var _goal_edges: Dictionary = {}
var _trail: Array[String] = []
var _branch_open := false
var _pan := Vector2.ZERO
var _zoom := DEFAULT_ZOOM
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
	_nodes_by_seed.clear()
	var raw_nodes = graph.get("nodes", [])
	if raw_nodes is Array:
		for raw in raw_nodes:
			if raw is Dictionary:
				var node := (raw as Dictionary).duplicate(true)
				_nodes.append(node)
				_nodes_by_seed[String(node.get("seed", ""))] = node
	var raw_edges = graph.get("edges", [])
	if raw_edges is Array:
		for raw in raw_edges:
			if raw is Dictionary:
				_edges.append((raw as Dictionary).duplicate(true))
	_current_seed = current_seed
	_selected_seed = current_seed
	_goal_seed = goal_seed
	_history_edges = history_edges.duplicate(true)
	_goal_edges = goal_edges.duplicate(true)
	_trail.clear()
	if not current_seed.is_empty():
		_trail.append(current_seed)
	_branch_open = false
	_zoom = DEFAULT_ZOOM
	_pan = Vector2.ZERO
	_has_centered = false
	_rebuild_visible_nodes("")
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
	_zoom = DEFAULT_ZOOM
	center_on(_current_seed)


func get_visible_seeds() -> Array[String]:
	var result: Array[String] = []
	for raw_seed in _buttons.keys():
		result.append(String(raw_seed))
	return result


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, 1000.0)
	for raw_seed in _fallback_icons.keys():
		var icon := _fallback_icons[raw_seed] as Label
		if icon == null or not is_instance_valid(icon):
			continue
		var offset := float(abs(String(raw_seed).hash()) % 100) / 100.0
		var pulse := 0.5 + 0.5 * sin(_phase * 2.1 + offset * TAU)
		icon.modulate.a = 0.48 + pulse * 0.32
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
	_draw_space_backdrop()
	var center := size * 0.5
	var visible := _visible_seed_dictionary()
	var trail_edges := _trail_edge_keys()
	for edge: Dictionary in _edges:
		var from_seed := String(edge.get("from", ""))
		var to_seed := String(edge.get("to", ""))
		if not visible.has(from_seed) or not visible.has(to_seed):
			continue
		if not _base_positions.has(from_seed) or not _base_positions.has(to_seed):
			continue
		var p1 := center + (Vector2(_base_positions[from_seed]) + NODE_SIZE * 0.5 + _pan) * _zoom
		var p2 := center + (Vector2(_base_positions[to_seed]) + NODE_SIZE * 0.5 + _pan) * _zoom
		var key := String(edge.get("key", ""))
		var color := Color(0.25, 0.49, 0.79, 0.42)
		var width := 1.7
		if _history_edges.has(key):
			color = Color(0.28, 0.83, 0.91, 0.82)
			width = 2.5
		if trail_edges.has(key):
			color = Color(0.38, 0.72, 1.0, 0.94)
			width = 3.0
		if _goal_edges.has(key):
			color = Color(0.72, 0.45, 1.0, 0.98)
			width = 3.5
		draw_line(p1, p2, Color(0.05, 0.11, 0.24, 0.84), (width + 3.0) * _zoom, true)
		draw_line(p1, p2, color, width * _zoom, true)
		var speed := 0.34 if trail_edges.has(key) or _goal_edges.has(key) else 0.20
		var pulse_t := fmod(_phase * speed + float(abs(key.hash()) % 100) / 100.0, 1.0)
		var pulse := p1.lerp(p2, pulse_t)
		var pulse_color := Color(color.r, color.g, color.b, minf(1.0, color.a + 0.20))
		draw_circle(pulse, (3.3 if trail_edges.has(key) or _goal_edges.has(key) else 2.1) * _zoom, pulse_color)

	if not _branch_open and _base_positions.has(_current_seed):
		var root_center := center + (Vector2(_base_positions[_current_seed]) + NODE_SIZE * 0.5 + _pan) * _zoom
		var ring := 54.0 + 4.0 * sin(_phase * 2.2)
		draw_arc(root_center, ring * _zoom, 0.0, TAU, 48, Color(0.42, 0.78, 1.0, 0.22), 2.0 * _zoom, true)
		draw_arc(root_center, (ring + 10.0) * _zoom, 0.0, TAU, 48, Color(0.72, 0.49, 1.0, 0.10), 1.0 * _zoom, true)


func _draw_space_backdrop() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_texture_rect(NEBULA_TEXTURE, Rect2(Vector2.ZERO, size), false, Color(0.20, 0.29, 0.52, 0.26))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.006, 0.013, 0.045, 0.76))
	for index in range(62):
		var fx := fmod(float(index * 97 + 31), 997.0) / 997.0
		var fy := fmod(float(index * 173 + 71), 991.0) / 991.0
		var pos := Vector2(fx * size.x, fy * size.y)
		var twinkle := 0.24 + 0.24 * (0.5 + 0.5 * sin(_phase * 1.35 + float(index) * 1.73))
		var radius := 0.65 + float(index % 3) * 0.42
		draw_circle(pos, radius, Color(0.55, 0.76, 1.0, twinkle))
	for index in range(8):
		var fx := fmod(float(index * 211 + 53), 983.0) / 983.0
		var fy := fmod(float(index * 149 + 23), 977.0) / 977.0
		var pos := Vector2(fx * size.x, fy * size.y)
		var glow := 0.035 + 0.018 * sin(_phase * 0.75 + float(index))
		draw_circle(pos, 24.0 + float(index % 4) * 10.0, Color(0.25, 0.20, 0.55, glow))


func _activate_node(seed: String) -> void:
	if not _buttons.has(seed):
		return
	_selected_seed = seed
	var trail_index := _trail.find(seed)
	if trail_index >= 0:
		while _trail.size() > trail_index + 1:
			_trail.remove_at(_trail.size() - 1)
		_branch_open = true
	elif not _trail.is_empty() and _are_neighbors(_trail[_trail.size() - 1], seed):
		_trail.append(seed)
		_branch_open = true
	else:
		_preview_node(seed)
		return
	_rebuild_visible_nodes(seed)
	node_selected.emit(seed)


func _preview_node(seed: String) -> void:
	if not _buttons.has(seed):
		return
	_selected_seed = seed
	_refresh_node_styles()
	node_selected.emit(seed)


func _rebuild_visible_nodes(source_seed: String) -> void:
	var visible_seeds := _visible_seeds_for_state()
	var visible_lookup: Dictionary = {}
	for seed: String in visible_seeds:
		visible_lookup[seed] = true

	for raw_seed in _buttons.keys().duplicate():
		var seed := String(raw_seed)
		if visible_lookup.has(seed):
			continue
		var old_button := _buttons[seed] as Button
		_buttons.erase(seed)
		_fallback_icons.erase(seed)
		if old_button != null:
			old_button.queue_free()

	_recalculate_positions(visible_seeds)
	var new_seeds: Array[String] = []
	for seed: String in visible_seeds:
		if _buttons.has(seed):
			continue
		var node := _nodes_by_seed.get(seed, {}) as Dictionary
		if node.is_empty():
			continue
		var button := _create_node_button(node)
		_buttons[seed] = button
		add_child(button)
		new_seeds.append(seed)

	_refresh_node_styles()
	_animate_relayout(new_seeds, source_seed)
	_configure_focus_neighbors()
	queue_redraw()


func _visible_seeds_for_state() -> Array[String]:
	var result: Array[String] = []
	for seed: String in _trail:
		if not result.has(seed):
			result.append(seed)
	if _branch_open and not _trail.is_empty():
		for neighbor: String in _neighbors(_trail[_trail.size() - 1]):
			if not result.has(neighbor):
				result.append(neighbor)
	return result


func _visible_seed_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for raw_seed in _buttons.keys():
		result[String(raw_seed)] = true
	return result


func _recalculate_positions(visible_seeds: Array[String]) -> void:
	_base_positions.clear()
	if visible_seeds.is_empty():
		return
	var current_rank := int((_nodes_by_seed.get(_current_seed, {}) as Dictionary).get("rank_index", 0))
	var by_rank: Dictionary = {}
	for seed: String in visible_seeds:
		var node := _nodes_by_seed.get(seed, {}) as Dictionary
		if node.is_empty():
			continue
		var rank_index := int(node.get("rank_index", 99))
		if not by_rank.has(rank_index):
			by_rank[rank_index] = []
		(by_rank[rank_index] as Array).append(seed)

	for raw_rank in by_rank.keys():
		var rank_index := int(raw_rank)
		var group: Array = by_rank[raw_rank]
		group.sort_custom(func(a, b) -> bool:
			var a_node := _nodes_by_seed.get(String(a), {}) as Dictionary
			var b_node := _nodes_by_seed.get(String(b), {}) as Dictionary
			return String(a_node.get("name", "")) < String(b_node.get("name", ""))
		)
		var total_height := maxf(0.0, float(group.size() - 1) * ROW_GAP)
		for row_index in range(group.size()):
			var seed := String(group[row_index])
			var x := float(rank_index - current_rank) * COLUMN_GAP
			var y := float(row_index) * ROW_GAP - total_height * 0.5
			_base_positions[seed] = Vector2(x, y)


func _create_node_button(node: Dictionary) -> Button:
	var seed := String(node.get("seed", ""))
	var species_name := String(node.get("name", "Unknown"))
	var rank := String(node.get("rank", "Unknown"))
	var button := Button.new()
	button.name = "EvolutionNode_%s" % seed.replace("-", "_")
	button.text = ""
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true
	button.tooltip_text = "Inspect this form. Activate it to reveal the routes connected to it."
	button.pressed.connect(_activate_node.bind(seed))
	button.focus_entered.connect(_preview_node.bind(seed))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var visual_frame := PanelContainer.new()
	visual_frame.custom_minimum_size = Vector2(68.0, 68.0)
	visual_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.09, 0.14, 0.25, 0.90), Vector4(4, 4, 4, 4), 8.0))
	visual_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(visual_frame)

	var visual_key := _resolve_field_visual_key(species_name)
	if not visual_key.is_empty():
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.custom_minimum_size = Vector2(60.0, 60.0)
		preview.set_species(visual_key)
		preview.set_active(true)
		visual_frame.add_child(preview)
	else:
		var fallback := Label.new()
		fallback.text = "✦"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 28)
		fallback.add_theme_color_override("font_color", Color(0.50, 0.73, 1.0, 0.76))
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual_frame.add_child(fallback)
		_fallback_icons[seed] = fallback

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var name_label := Label.new()
	name_label.text = species_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UI.TEXT)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name_label)

	var rank_label := Label.new()
	rank_label.text = rank.to_upper()
	rank_label.add_theme_font_size_override("font_size", 9)
	rank_label.add_theme_color_override("font_color", UI.rank_color(rank).lightened(0.16))
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(rank_label)

	var status := Label.new()
	status.name = "Status"
	status.text = "EXPLORE"
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", UI.SUBTLE)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(status)
	return button


func _refresh_node_styles() -> void:
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
		var node := _nodes_by_seed.get(seed, {}) as Dictionary
		var rank := String(node.get("rank", "Unknown"))
		var accent := UI.rank_color(rank)
		if _node_was_experienced(seed):
			accent = UI.CYAN
		if seed == _goal_seed:
			accent = UI.PURPLE.lightened(0.12)
		if seed == _current_seed:
			accent = UI.GOLD
		SKIN.apply_button(button, accent)
		if seed == _selected_seed:
			button.add_theme_stylebox_override("normal", SKIN.border_style(accent.lightened(0.10), Vector4(10, 8, 10, 8), 12.0))
			button.add_theme_stylebox_override("hover", SKIN.border_style(accent.lightened(0.16), Vector4(10, 8, 10, 8), 12.0))
		elif seed == _current_seed:
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.33, 0.25, 0.11, 0.98), Vector4(10, 8, 10, 8)))
		elif seed == _goal_seed:
			button.add_theme_stylebox_override("normal", SKIN.frame_style(Color(0.29, 0.16, 0.42, 0.98), Vector4(10, 8, 10, 8)))

		var status := button.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/Status") as Label
		if status == null:
			status = _find_status_label(button)
		if status != null:
			if seed == _current_seed:
				status.text = "CURRENT FORM"
				status.add_theme_color_override("font_color", UI.GOLD)
			elif seed == _goal_seed:
				status.text = "EVOLUTION GOAL"
				status.add_theme_color_override("font_color", UI.PURPLE.lightened(0.18))
			elif seed == _selected_seed:
				status.text = "SELECTED · OPEN ROUTES"
				status.add_theme_color_override("font_color", accent.lightened(0.18))
			else:
				status.text = "TAP TO EXPLORE"
				status.add_theme_color_override("font_color", UI.SUBTLE)


func _find_status_label(button: Button) -> Label:
	var stack: Array[Node] = [button]
	while not stack.is_empty():
		var node: Node = stack.pop_back() as Node
		if node is Label and node.name == "Status":
			return node as Label
		for child in node.get_children():
			stack.append(child)
	return null


func _node_was_experienced(seed: String) -> bool:
	if seed == _current_seed:
		return true
	for key in _history_edges.keys():
		if String(key).begins_with(seed + "|") or String(key).ends_with("|" + seed):
			return true
	return false


func _animate_relayout(new_seeds: Array[String], source_seed: String) -> void:
	var center := size * 0.5
	var source_position := center
	if _buttons.has(source_seed):
		var source_button := _buttons[source_seed] as Button
		if source_button != null:
			source_position = source_button.position
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
		var base := Vector2(_base_positions.get(seed, Vector2.ZERO))
		var target_position := center + (base + _pan) * _zoom
		if new_seeds.has(seed):
			button.position = source_position
			button.scale = Vector2.ONE * (_zoom * 0.78)
			button.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(button, "position", target_position, REVEAL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE * _zoom, REVEAL_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, minf(0.18, REVEAL_DURATION))


func _refresh_layout() -> void:
	if _buttons.is_empty():
		return
	var center := size * 0.5
	for raw_seed in _buttons.keys():
		var seed := String(raw_seed)
		var button := _buttons[seed] as Button
		if button == null:
			continue
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


func _neighbors(seed: String) -> Array[String]:
	var result: Array[String] = []
	for edge: Dictionary in _edges:
		var from_seed := String(edge.get("from", ""))
		var to_seed := String(edge.get("to", ""))
		if from_seed == seed and not to_seed.is_empty() and not result.has(to_seed):
			result.append(to_seed)
		elif to_seed == seed and not from_seed.is_empty() and not result.has(from_seed):
			result.append(from_seed)
	result.sort_custom(func(a: String, b: String) -> bool:
		var a_node := _nodes_by_seed.get(a, {}) as Dictionary
		var b_node := _nodes_by_seed.get(b, {}) as Dictionary
		var ar := int(a_node.get("rank_index", 99))
		var br := int(b_node.get("rank_index", 99))
		if ar == br:
			return String(a_node.get("name", "")) < String(b_node.get("name", ""))
		return ar < br
	)
	return result


func _are_neighbors(a: String, b: String) -> bool:
	return _neighbors(a).has(b)


func _trail_edge_keys() -> Dictionary:
	var result: Dictionary = {}
	for index in range(maxi(0, _trail.size() - 1)):
		var a := _trail[index]
		var b := _trail[index + 1]
		result[_edge_key(a, b)] = true
	return result


func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func _resolve_field_visual_key(species_name: String) -> String:
	var normalized := species_name.to_lower().strip_edges()
	var candidates: Array[String] = []
	for candidate in [
		normalized,
		normalized.replace(" ", ""),
		normalized.replace(" ", "_"),
		normalized.replace("-", "").replace(" ", ""),
	]:
		var key := String(candidate)
		if not key.is_empty() and not candidates.has(key):
			candidates.append(key)
	for key: String in candidates:
		if ResourceLoader.exists("res://assets/resources/%s.tres" % key):
			return key
	return ""


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
