extends Control
class_name DebugSpeciesPicker

signal species_selected(seed: String)
signal dismissed

const UI = preload("res://src/ui/TacticalTheme.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const MAX_VISIBLE_RESULTS := 56
const MAX_FRAME_SIZE := Vector2(860, 650)

var _catalog: Array[Dictionary] = []
var _database: DigimonDatabase
var _selected_seed := ""
var _title: Label
var _panel: PanelContainer
var _search: LineEdit
var _rank: OptionButton
var _summary: Label
var _list: VBoxContainer

func configure(catalog: Array[Dictionary], database: DigimonDatabase) -> void:
	_catalog = catalog.duplicate(true)
	_database = database
	if is_inside_tree():
		_rebuild_results()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	get_viewport().size_changed.connect(_layout)

func open_picker(title: String, selected_seed: String = "") -> void:
	_selected_seed = selected_seed
	_title.text = title
	_search.clear()
	_rank.select(0)
	visible = true
	_rebuild_results()
	call_deferred("_layout")
	call_deferred("_focus_search")

func close_picker() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_picker()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_panel = PanelContainer.new()
	_panel.name = "DebugSpeciesPickerPanel"
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	add_child(_panel)
	var outer := _margin(18, 16, 18, 18)
	_panel.add_child(outer)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	outer.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	_title = _label("CHOOSE DIGIMON", 22, UI.TEXT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := _button("CLOSE - ESC", UI.MUTED)
	close.pressed.connect(close_picker)
	header.add_child(close)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	root.add_child(filter_row)
	_search = LineEdit.new()
	_search.placeholder_text = "Search by Digimon name or seed"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.y = 40
	UI.apply_body_font(_search)
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_results())
	filter_row.add_child(_search)
	_rank = OptionButton.new()
	_rank.custom_minimum_size = Vector2(170, 40)
	for label in ["ALL RANKS", "FRESH", "IN-TRAINING", "ROOKIE", "CHAMPION", "ULTIMATE", "MEGA", "ULTRA", "FUSION"]:
		_rank.add_item(label)
	UI.apply_body_font(_rank)
	_rank.item_selected.connect(func(_index: int) -> void: _rebuild_results())
	filter_row.add_child(_rank)
	_summary = _label("", 10, UI.SUBTLE)
	root.add_child(_summary)
	var surface := PanelContainer.new()
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.clip_contents = true
	surface.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.82, 10))
	root.add_child(surface)
	var surface_margin := _margin(10, 10, 10, 10)
	surface.add_child(surface_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	surface_margin.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_list)

func _rebuild_results() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var query := _search.text.to_lower().strip_edges() if _search != null else ""
	var rank_filter := ""
	if _rank != null and _rank.selected > 0:
		rank_filter = _rank.get_item_text(_rank.selected).to_lower()
	var matches: Array[Dictionary] = []
	for row: Dictionary in _catalog:
		var name := String(row.get("name", ""))
		var seed := String(row.get("seed", ""))
		var rank := String(row.get("rank", "Unknown"))
		if not query.is_empty() and name.to_lower().find(query) < 0 and seed.to_lower().find(query) < 0:
			continue
		if not rank_filter.is_empty() and rank.to_lower() != rank_filter:
			continue
		matches.append(row)
	var shown := mini(matches.size(), MAX_VISIBLE_RESULTS)
	_summary.text = "%d matches%s" % [matches.size(), " - showing first %d" % shown if matches.size() > shown else ""]
	if matches.is_empty():
		_list.add_child(_label("No Digimon matches these filters.", 12, UI.MUTED))
		return
	for index in range(shown):
		_list.add_child(_species_button(matches[index]))

func _species_button(row: Dictionary) -> Button:
	var seed := String(row.get("seed", ""))
	var name := String(row.get("name", "Unknown"))
	var rank := String(row.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var selected := seed == _selected_seed
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true
	button.tooltip_text = "Choose %s" % name
	_style_button(button, UI.GREEN if selected else accent, selected)
	button.pressed.connect(_choose.bind(seed))
	var margin := _margin(9, 6, 12, 6)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row_box := HBoxContainer.new()
	row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_box.add_theme_constant_override("separation", 10)
	margin.add_child(row_box)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(62, 58)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(name)
	preview.set_active(selected)
	row_box.add_child(preview)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row_box.add_child(copy)
	copy.add_child(_label(name.to_upper(), 13, UI.TEXT, true))
	copy.add_child(_label("%s - %s" % [rank.to_upper(), seed], 9, accent.lightened(0.08), true))
	if selected:
		copy.add_child(_label("CURRENT SELECTION", 9, UI.GREEN, true))
	return button

func _choose(seed: String) -> void:
	_selected_seed = seed
	visible = false
	species_selected.emit(seed)

func _focus_search() -> void:
	if visible and _search != null:
		_search.grab_focus()

func _layout() -> void:
	if _panel == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var edge := 14.0
	var available := Vector2(maxf(1.0, physical.x - edge * 2.0), maxf(1.0, physical.y - edge * 2.0))
	var requested := Vector2(minf(MAX_FRAME_SIZE.x, available.x), minf(MAX_FRAME_SIZE.y, available.y))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.size = requested
	_panel.position = Vector2((physical.x - requested.x) * 0.5, (physical.y - requested.y) * 0.5) * scale_factor

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 11)
	_style_button(button, accent, false)
	UI.apply_body_font(button)
	return button

func _style_button(button: Button, accent: Color, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.action_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_focus_color", UI.TEXT)

func _label(text: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", left)
	result.add_theme_constant_override("margin_top", top)
	result.add_theme_constant_override("margin_right", right)
	result.add_theme_constant_override("margin_bottom", bottom)
	return result
