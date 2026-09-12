extends "res://src/ui/EvolutionConstellation.gd"
class_name EvolutionChart

const ChartCanvasScript = preload("res://src/ui/EvolutionChartCanvas.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")

var _content_root: Control = null


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
		_detail_body.add_child(_label("LV %d   ·   POTENTIAL %d" % [_instance.level, _instance.potential], 13, UI.TEXT, true))
		if not _instance.evolution_goal_seed.is_empty():
			var goal_species := _database.get_by_seed(_instance.evolution_goal_seed)
			if not goal_species.is_empty():
				_detail_body.add_child(_section_label("TARGET", UI.PURPLE))
				_detail_body.add_child(_label(String(goal_species.get("name", "Unknown")), 14, UI.PURPLE.lightened(0.18), true))
		return

	var direction := _graph_service.route_direction(_instance.species_seed, _selected_seed, _database)
	var path := _graph_service.find_shortest_path(_instance.species_seed, _selected_seed, _database)
	if path.size() > 1:
		_detail_body.add_child(_section_label("ROUTE", UI.CYAN))
		_detail_body.add_child(_route_path_label(path))

	if direction == "digivolution" or direction == "degeneration":
		var route := _direct_route(_selected_seed, direction)
		var route_accent := UI.GREEN if direction == "digivolution" else UI.CYAN
		_detail_body.add_child(_section_label("REQUIREMENTS", route_accent))
		_add_requirement_rows(route.get("requirements", []))
		var unlocked := bool(route.get("unlocked", false))
		var action := _button("DIGIVOLVE" if direction == "digivolution" else "DEGENERATE", route_accent)
		action.disabled = not unlocked
		action.tooltip_text = "Meet every requirement first." if not unlocked else "Change to %s and return to Level 1." % species_name
		action.pressed.connect(_show_transition_confirmation.bind(direction, _selected_seed))
		_detail_body.add_child(action)

	_add_goal_controls(path)


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
	# Keep tiny statuses typographic; the surrounding Kenney frame is the chrome.
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
	# Override the legacy constellation factory so every label produced by the
	# inherited requirement/route helpers also gets the new font family.
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
	# The base constellation predates the shared typography system. Keep its
	# Kenney chrome but explicitly apply Exo 2 to actions in this chart.
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(110, 40)
	SKIN.apply_button(button, accent)
	UI.apply_body_font(button)
	return button
