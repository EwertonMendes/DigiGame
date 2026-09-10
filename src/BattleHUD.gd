extends Control

var _controller: Node
var _panel: PanelContainer
var _turn_label: Label
var _phase_label: Label
var _mov_label: Label
var _buttons: HBoxContainer
var _move_button: Button
var _defend_button: Button
var _wait_button: Button
var _undo_button: Button
var _cancel_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_controller = get_node_or_null("../../BattleController")
	_refresh_connections()
	refresh_from_controller()
	get_viewport().size_changed.connect(_layout_panel)
	call_deferred("_layout_panel")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TurnPanel"
	_panel.custom_minimum_size = Vector2(420.0, 116.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	_turn_label = Label.new()
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 18)
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_turn_label)

	var info_row := HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 16)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info_row)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 13)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_phase_label)

	_mov_label = Label.new()
	_mov_label.add_theme_font_size_override("font_size", 13)
	_mov_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_mov_label)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_buttons)

	_move_button = _make_button("MOVER")
	_defend_button = _make_button("DEFENDER")
	_wait_button = _make_button("ESPERAR")
	_undo_button = _make_button("VOLTAR")
	_cancel_button = _make_button("CANCELAR")

	_buttons.add_child(_move_button)
	_buttons.add_child(_defend_button)
	_buttons.add_child(_wait_button)
	_buttons.add_child(_undo_button)
	_buttons.add_child(_cancel_button)


func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(78.0, 34.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 13)
	return button


func _refresh_connections() -> void:
	if _controller == null:
		return
	_move_button.pressed.connect(_controller.begin_move_selection)
	_defend_button.pressed.connect(_controller.defend_current)
	_wait_button.pressed.connect(_controller.wait_current)
	_undo_button.pressed.connect(_controller.undo_move)
	_cancel_button.pressed.connect(_controller.cancel_move_selection)


func refresh_from_controller() -> void:
	if _controller == null:
		_controller = get_node_or_null("../../BattleController")
	if _controller == null or not _controller.has_method("get_hud_state"):
		_panel.visible = false if _panel != null else false
		return

	var state: Dictionary = _controller.call("get_hud_state")
	_panel.visible = true
	var actor_name := String(state.get("actor_name", ""))
	var is_user_turn := bool(state.get("is_user_turn", false))
	_turn_label.text = "Turno: %s" % actor_name if not actor_name.is_empty() else "Preparando batalha..."
	_phase_label.text = String(state.get("phase", ""))
	_mov_label.text = "MOV: %d" % int(state.get("mov", 4))

	_move_button.visible = bool(state.get("can_move", false))
	_defend_button.visible = bool(state.get("can_defend", false))
	_wait_button.visible = bool(state.get("can_wait", false))
	_undo_button.visible = bool(state.get("can_undo", false))
	_cancel_button.visible = bool(state.get("can_cancel", false))

	if not is_user_turn:
		_phase_label.text = "Turno inimigo"


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _panel.custom_minimum_size
	_panel.position = Vector2(
		maxf(12.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(12.0, viewport_size.y - panel_size.y - 16.0)
	)
