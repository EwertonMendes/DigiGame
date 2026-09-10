extends Control
class_name BattleTopBar

const UI = preload("res://src/ui/TacticalTheme.gd")

var _controller: Node = null
var _panel: Panel = null
var _map_label: Label = null
var _turn_label: Label = null
var _objective_label: Label = null
var _signal_line: ColorRect = null
var _last_turn := -1
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	set_process(true)
	call_deferred("_layout")


func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout()


func setup(controller: Node) -> void:
	_controller = controller
	refresh()


func refresh() -> void:
	if _panel == null:
		return
	if _controller == null or not _controller.has_method("get_hud_state"):
		_panel.visible = false
		return
	var state: Dictionary = _controller.call("get_hud_state")
	_panel.visible = true
	var turn_number: int = int(state.get("turn_number", 1))
	_map_label.text = "DIGITAL PLAINS"
	_turn_label.text = "ACT %02d" % turn_number
	_objective_label.text = "DEFEAT ALL OPPONENTS"
	if turn_number != _last_turn:
		_last_turn = turn_number
		_pulse_turn()
	_layout()


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "BattleContextBar"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.92, 0.42, 11, 9))
	add_child(_panel)

	_map_label = _label("", 13, UI.TEXT, true)
	_panel.add_child(_map_label)
	_turn_label = _label("", 14, UI.CYAN, true)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_turn_label)
	_objective_label = _label("", 12, UI.MUTED, true)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_objective_label)

	_signal_line = ColorRect.new()
	_signal_line.color = UI.separator(UI.CYAN, 0.72)
	_signal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_signal_line)


func _label(text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _layout() -> void:
	if _panel == null:
		return
	var viewport_obj: Viewport = get_viewport()
	var logical: Vector2 = viewport_obj.get_visible_rect().size
	var physical: Vector2 = UI.physical_window_size(viewport_obj)
	var ui_scale: float = UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact: bool = UI.is_compact(viewport_obj, 760.0)
	var laptop: bool = UI.is_laptop(viewport_obj)
	var very_narrow: bool = physical.x < 520.0
	var debug_guard: float = 122.0 if compact else 0.0
	var available_width: float = physical.x - 20.0 - debug_guard
	var target_width: float = 760.0 if laptop else 720.0
	var width: float = minf(target_width, available_width)
	width = maxf(220.0, width)
	var height: float = 46.0 if compact else (56.0 if laptop else 54.0)
	var panel_x: float = 10.0 if compact else (physical.x - width) * 0.5
	if compact and not very_narrow:
		panel_x = maxf(10.0, (physical.x - debug_guard - width) * 0.5)
	_panel.scale = Vector2.ONE * ui_scale
	_panel.position = Vector2(panel_x * ui_scale, 10.0 * ui_scale)
	_panel.size = Vector2(width, height)
	_signal_line.position = Vector2(16.0, 0.0)
	_signal_line.size = Vector2(112.0 if not compact else 78.0, 2.0)

	if very_narrow:
		_objective_label.visible = false
		var half: float = width * 0.5
		_map_label.position = Vector2(14.0, 4.0)
		_map_label.size = Vector2(half - 16.0, height - 8.0)
		_turn_label.position = Vector2(half, 4.0)
		_turn_label.size = Vector2(half - 12.0, height - 8.0)
	else:
		_objective_label.visible = true
		var third: float = width / 3.0
		_map_label.position = Vector2(18.0, 4.0)
		_map_label.size = Vector2(third - 14.0, height - 8.0)
		_turn_label.position = Vector2(third, 4.0)
		_turn_label.size = Vector2(third, height - 8.0)
		_objective_label.position = Vector2(third * 2.0, 4.0)
		_objective_label.size = Vector2(third - 18.0, height - 8.0)

	if compact:
		_map_label.text = "PLAINS"
		_objective_label.text = "DEFEAT OPPONENTS"
		_map_label.add_theme_font_size_override("font_size", 10)
		_turn_label.add_theme_font_size_override("font_size", 11)
		_objective_label.add_theme_font_size_override("font_size", 9)
	else:
		_map_label.text = "DIGITAL PLAINS"
		_objective_label.text = "DEFEAT ALL OPPONENTS"
		_map_label.add_theme_font_size_override("font_size", 14 if laptop else 13)
		_turn_label.add_theme_font_size_override("font_size", 15 if laptop else 14)
		_objective_label.add_theme_font_size_override("font_size", 13 if laptop else 12)


func _pulse_turn() -> void:
	if _turn_label == null:
		return
	_turn_label.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_turn_label.scale = Vector2(0.96, 0.96)
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_label, "modulate:a", 1.0, 0.18)
	tween.tween_property(_turn_label, "scale", Vector2.ONE, 0.18)
