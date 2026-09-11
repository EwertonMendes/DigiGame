extends Control
class_name BattleTopBar

const UI = preload("res://src/ui/TacticalTheme.gd")

var _controller: Node = null
var _panel: Panel = null
var _map_label: Label = null
var _turn_label: Label = null
var _objective_label: Label = null
var _left_tick: ColorRect = null
var _right_tick: ColorRect = null
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
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
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
	var turn_number := int(state.get("turn_number", 1))
	_map_label.text = "DIGITAL PLAINS"
	_turn_label.text = "TURN  %d" % turn_number
	_objective_label.text = "Defeat all opponents"
	if turn_number != _last_turn:
		_last_turn = turn_number
		_pulse_turn()
	_layout()


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "BattleContextRibbon"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UI.ribbon(UI.GOLD, 0.62))
	add_child(_panel)

	_map_label = _label("", 13, UI.MUTED)
	_panel.add_child(_map_label)
	_turn_label = _label("", 14, UI.GOLD)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_turn_label)
	_objective_label = _label("", 13, UI.MUTED)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_objective_label)

	_left_tick = ColorRect.new()
	_left_tick.color = Color(1.0, 1.0, 1.0, 0.34)
	_left_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_left_tick)
	_right_tick = ColorRect.new()
	_right_tick.color = UI.separator(UI.GOLD, 0.28)
	_right_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_right_tick)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	UI.apply_body_font(label)
	return label


func _layout() -> void:
	if _panel == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = viewport_obj.get_visible_rect().size
	_last_window_size = DisplayServer.window_get_size()
	var compact := UI.is_compact(viewport_obj, 760.0)
	var very_narrow := physical.x < 560.0
	var margin := 10.0 if compact else 16.0
	var width := minf(690.0, physical.x - margin * 2.0)
	var height := 38.0 if compact else 42.0
	_panel.scale = Vector2.ONE * ui_scale
	_panel.position = Vector2((physical.x - width) * 0.5 * ui_scale, margin * ui_scale)
	_panel.size = Vector2(width, height)
	_left_tick.position = Vector2(0.0, height - 2.0)
	_left_tick.size = Vector2(minf(76.0, width * 0.18), 2.0)
	_right_tick.position = Vector2(width - minf(46.0, width * 0.12), height - 2.0)
	_right_tick.size = Vector2(minf(46.0, width * 0.12), 2.0)

	if very_narrow:
		_map_label.visible = false
		_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_turn_label.position = Vector2(12.0, 0.0)
		_turn_label.size = Vector2(width * 0.34, height - 2.0)
		_objective_label.position = Vector2(width * 0.34, 0.0)
		_objective_label.size = Vector2(width * 0.66 - 12.0, height - 2.0)
		_turn_label.add_theme_font_size_override("font_size", 13)
		_objective_label.add_theme_font_size_override("font_size", 12)
	else:
		_map_label.visible = true
		_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var third := width / 3.0
		_map_label.position = Vector2(12.0, 0.0)
		_map_label.size = Vector2(third - 12.0, height - 2.0)
		_turn_label.position = Vector2(third, 0.0)
		_turn_label.size = Vector2(third, height - 2.0)
		_objective_label.position = Vector2(third * 2.0, 0.0)
		_objective_label.size = Vector2(third - 12.0, height - 2.0)
		_map_label.add_theme_font_size_override("font_size", 12 if compact else 13)
		_turn_label.add_theme_font_size_override("font_size", 13 if compact else 14)
		_objective_label.add_theme_font_size_override("font_size", 12 if compact else 13)


func _pulse_turn() -> void:
	if _turn_label == null:
		return
	_turn_label.modulate = Color(1.0, 1.0, 1.0, 0.35)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_label, "modulate:a", 1.0, 0.18)
