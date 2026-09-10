extends Control
class_name BattleTopBar

const UI = preload("res://src/ui/TacticalTheme.gd")

var _controller: Node = null
var _panel: Panel = null
var _map_label: Label = null
var _turn_label: Label = null
var _objective_label: Label = null
var _last_turn := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")


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
	_map_label.text = "◆  DIGITAL PLAINS"
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
	_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.88, 0.34, 9, 7))
	add_child(_panel)

	_map_label = _label("", 11, UI.TEXT)
	_panel.add_child(_map_label)
	_turn_label = _label("", 12, UI.CYAN)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_turn_label)
	_objective_label = _label("", 10, UI.MUTED)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_objective_label)

	var top_line := ColorRect.new()
	top_line.name = "SignalLine"
	top_line.color = UI.separator(UI.CYAN, 0.62)
	top_line.position = Vector2(14.0, 0.0)
	top_line.size = Vector2(82.0, 2.0)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(top_line)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _layout() -> void:
	if _panel == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	var compact := viewport.x < 760.0
	var width := minf(620.0, viewport.x - (24.0 if compact else 330.0))
	width = maxf(300.0, width)
	var height := 44.0 if compact else 48.0
	_panel.position = Vector2((viewport.x - width) * 0.5, 12.0)
	_panel.size = Vector2(width, height)

	var third := width / 3.0
	_map_label.position = Vector2(16.0, 4.0)
	_map_label.size = Vector2(third - 12.0, height - 8.0)
	_turn_label.position = Vector2(third, 4.0)
	_turn_label.size = Vector2(third, height - 8.0)
	_objective_label.position = Vector2(third * 2.0, 4.0)
	_objective_label.size = Vector2(third - 16.0, height - 8.0)

	if compact:
		_map_label.text = "◆  PLAINS"
		_objective_label.text = "DEFEAT OPPONENTS"
		_map_label.add_theme_font_size_override("font_size", 9)
		_turn_label.add_theme_font_size_override("font_size", 10)
		_objective_label.add_theme_font_size_override("font_size", 8)
	else:
		_map_label.add_theme_font_size_override("font_size", 11)
		_turn_label.add_theme_font_size_override("font_size", 12)
		_objective_label.add_theme_font_size_override("font_size", 10)


func _pulse_turn() -> void:
	if _turn_label == null:
		return
	_turn_label.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_turn_label.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_label, "modulate:a", 1.0, 0.18)
	tween.tween_property(_turn_label, "scale", Vector2.ONE, 0.18)
