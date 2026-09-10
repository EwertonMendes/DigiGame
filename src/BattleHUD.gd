extends Control

const UI = preload("res://src/ui/TacticalTheme.gd")
const ICON_ROOT := "res://assets/ui/icons"
const PORTRAIT_ROOT := "res://assets/characters"

var _controller: Node = null
var _dock: Panel = null
var _signal_line: ColorRect = null
var _unit_block: HBoxContainer = null
var _portrait_frame: Panel = null
var _portrait: TextureRect = null
var _identity_stack: VBoxContainer = null
var _actor_label: Label = null
var _hp_bar: ProgressBar = null
var _sp_bar: ProgressBar = null
var _hp_value: Label = null
var _sp_value: Label = null
var _phase_label: Label = null
var _mov_label: Label = null
var _action_grid: GridContainer = null
var _context_row: HBoxContainer = null
var _move_button: Button = null
var _attack_button: Button = null
var _skill_button: Button = null
var _defend_button: Button = null
var _wait_button: Button = null
var _confirm_move_button: Button = null
var _undo_button: Button = null
var _cancel_button: Button = null
var _primary_buttons: Array[Button] = []
var _accent_by_button: Dictionary = {}
var _last_actor_key := ""
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO
var _cached_state: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_controller = get_node_or_null("../../BattleController")
	_refresh_connections()
	get_viewport().size_changed.connect(_layout_dock)
	set_process(true)
	refresh_from_controller()
	call_deferred("_layout_dock")


func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout_dock()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or _controller == null:
		return
	if not bool(_cached_state.get("is_user_turn", false)):
		return
	match key.physical_keycode:
		KEY_1:
			if not _move_button.disabled:
				_move_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
		KEY_4:
			if not _defend_button.disabled:
				_defend_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
		KEY_5:
			if not _wait_button.disabled:
				_wait_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_dock = Panel.new()
	_dock.name = "ActionDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, 0.965, 0.28, 12, 4))
	add_child(_dock)

	_signal_line = ColorRect.new()
	_signal_line.color = UI.GOLD
	_signal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_signal_line)

	_build_unit_summary()

	_phase_label = Label.new()
	_phase_label.add_theme_color_override("font_color", UI.MUTED)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.clip_text = true
	UI.apply_body_font(_phase_label)
	_dock.add_child(_phase_label)

	_mov_label = Label.new()
	_mov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mov_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mov_label.add_theme_color_override("font_color", UI.TEXT)
	_mov_label.add_theme_stylebox_override("normal", UI.pill(UI.GOLD, 0.10))
	_mov_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_heading_font(_mov_label)
	_dock.add_child(_mov_label)

	_action_grid = GridContainer.new()
	_action_grid.name = "PrimaryActions"
	_action_grid.columns = 5
	_action_grid.add_theme_constant_override("h_separation", 8)
	_action_grid.add_theme_constant_override("v_separation", 8)
	_action_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_action_grid)

	_move_button = _make_action_button("Move", "move.svg", "1", "Plan movement")
	_attack_button = _make_action_button("Attack", "attack.svg", "2", "Use a basic attack")
	_skill_button = _make_action_button("Skill", "skill.svg", "3", "Choose a technique")
	_defend_button = _make_action_button("Defend", "defend.svg", "4", "Defend and end this Digimon's turn")
	_wait_button = _make_action_button("Wait", "wait.svg", "5", "End this Digimon's turn")
	_primary_buttons = [_move_button, _attack_button, _skill_button, _defend_button, _wait_button]
	for button: Button in _primary_buttons:
		_action_grid.add_child(button)

	_undo_button = _make_context_button("Undo move", "undo.svg", UI.GOLD)
	_action_grid.add_child(_undo_button)

	_context_row = HBoxContainer.new()
	_context_row.name = "ContextActions"
	_context_row.alignment = BoxContainer.ALIGNMENT_END
	_context_row.add_theme_constant_override("separation", 8)
	_context_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_context_row)

	_cancel_button = _make_context_button("Cancel", "cancel.svg", UI.RED)
	_confirm_move_button = _make_context_button("Confirm", "confirm.svg", UI.GOLD)
	_context_row.add_child(_cancel_button)
	_context_row.add_child(_confirm_move_button)


func _build_unit_summary() -> void:
	_unit_block = HBoxContainer.new()
	_unit_block.name = "ActiveUnit"
	_unit_block.add_theme_constant_override("separation", 10)
	_unit_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_unit_block)

	_portrait_frame = Panel.new()
	_portrait_frame.custom_minimum_size = Vector2(58.0, 58.0)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, 0.98, 0.34, 9, 0))
	_unit_block.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 5.0
	_portrait.offset_top = 5.0
	_portrait.offset_right = -5.0
	_portrait.offset_bottom = -5.0
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)

	_identity_stack = VBoxContainer.new()
	_identity_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_identity_stack.add_theme_constant_override("separation", 3)
	_identity_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_block.add_child(_identity_stack)

	_actor_label = Label.new()
	_actor_label.add_theme_color_override("font_color", UI.TEXT)
	_actor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_actor_label.clip_text = true
	_actor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_heading_font(_actor_label)
	_identity_stack.add_child(_actor_label)

	var hp_row := _make_resource_row("HP", UI.GREEN)
	_hp_bar = hp_row[0] as ProgressBar
	_hp_value = hp_row[1] as Label
	_identity_stack.add_child(hp_row[2] as Control)

	var sp_row := _make_resource_row("SP", UI.BLUE)
	_sp_bar = sp_row[0] as ProgressBar
	_sp_value = sp_row[1] as Label
	_identity_stack.add_child(sp_row[2] as Control)


func _make_resource_row(caption: String, accent: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(24.0, 0.0)
	label.add_theme_color_override("font_color", accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_heading_font(label)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(86.0, 8.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.14, 0.15, 0.16, 0.96)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var value := Label.new()
	value.text = "0/0"
	value.custom_minimum_size = Vector2(70.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", UI.TEXT)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_body_font(value)
	row.add_child(value)
	return [bar, value, row]


func _make_action_button(label_text: String, icon_name: String, shortcut: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(104.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s  [%s]" % [tooltip, shortcut]
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 22
	UI.apply_heading_font(button)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.59, 0.59, 0.55))
	button.add_theme_color_override("icon_normal_color", Color(0.86, 0.86, 0.83, 1.0))
	button.add_theme_color_override("icon_hover_color", UI.GOLD)
	button.add_theme_color_override("icon_pressed_color", UI.GOLD)
	button.add_theme_color_override("icon_disabled_color", Color(0.48, 0.49, 0.49, 0.46))
	button.add_theme_stylebox_override("normal", UI.action_style(UI.GOLD, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(UI.GOLD, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(UI.GOLD, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(UI.GOLD, "disabled"))
	button.mouse_entered.connect(Callable(self, "_on_action_hover").bind(button, true))
	button.mouse_exited.connect(Callable(self, "_on_action_hover").bind(button, false))
	button.button_down.connect(Callable(self, "_on_action_pressed_visual").bind(button))
	_accent_by_button[button] = UI.GOLD
	return button


func _make_context_button(label_text: String, icon_name: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(112.0, 44.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 17
	UI.apply_heading_font(button)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(accent, "disabled"))
	return button


func _refresh_connections() -> void:
	if _controller == null:
		return
	_move_button.pressed.connect(Callable(_controller, "begin_move_selection"))
	_confirm_move_button.pressed.connect(Callable(_controller, "confirm_move_path"))
	_defend_button.pressed.connect(Callable(_controller, "defend_current"))
	_wait_button.pressed.connect(Callable(_controller, "wait_current"))
	_undo_button.pressed.connect(Callable(_controller, "undo_move"))
	_cancel_button.pressed.connect(Callable(_controller, "cancel_move_selection"))


func refresh_from_controller() -> void:
	if _controller == null:
		_controller = get_node_or_null("../../BattleController")
	if _controller == null or not _controller.has_method("get_hud_state"):
		_dock.visible = false
		return

	var state: Dictionary = _controller.call("get_hud_state")
	_cached_state = state
	_dock.visible = true
	var actor := _controller.get("current_actor") as Node
	var actor_key := ""
	var player_team := true
	if actor != null:
		actor_key = String(actor.get("digimon_key")).to_lower()
		player_team = bool(actor.get("is_player_controlled"))
	_update_unit_summary(actor, state)

	var planning := bool(state.get("is_planning_move", false))
	_phase_label.text = _phase_copy(state)
	_mov_label.text = "%d MOV left" % int(state.get("move_remaining", 0)) if planning else "%d MOV" % int(state.get("mov", 4))
	_mov_label.add_theme_stylebox_override("normal", UI.pill(UI.GOLD if player_team else UI.RED, 0.10))

	_move_button.disabled = not bool(state.get("can_move", false))
	_attack_button.disabled = not bool(state.get("can_attack", false)) if state.has("can_attack") else true
	_skill_button.disabled = not bool(state.get("can_skill", false)) if state.has("can_skill") else true
	_defend_button.disabled = not bool(state.get("can_defend", false))
	_wait_button.disabled = not bool(state.get("can_wait", false))
	_confirm_move_button.disabled = not bool(state.get("can_confirm_move", false))
	_undo_button.visible = bool(state.get("can_undo", false))
	_cancel_button.disabled = false

	_set_action_selected(_move_button, planning)
	_signal_line.color = UI.GOLD if player_team else UI.RED
	_portrait_frame.add_theme_stylebox_override("panel", UI.panel(UI.GOLD if player_team else UI.RED, 0.98, 0.34, 9, 0))
	_apply_interaction_mode(state)

	if actor_key != _last_actor_key:
		_last_actor_key = actor_key
		_portrait.texture = _load_portrait(actor_key)
		_animate_actor_change()
	_layout_dock()


func _update_unit_summary(actor: Node, state: Dictionary) -> void:
	var actor_name := String(state.get("actor_name", "Digimon"))
	var level := int(state.get("level", 1))
	_actor_label.text = "%s  Lv. %d" % [actor_name, level]
	if actor == null:
		_hp_bar.max_value = 1
		_hp_bar.value = 0
		_sp_bar.max_value = 1
		_sp_bar.value = 0
		_hp_value.text = "—"
		_sp_value.text = "—"
		return

	var max_hp := maxi(1, int(actor.call("get_final_stat", "hp"))) if actor.has_method("get_final_stat") else 1
	var current_hp := max_hp
	if actor.has_method("get_current_hp"):
		current_hp = int(actor.call("get_current_hp"))
	else:
		var battle_state = actor.get("battle_state")
		if battle_state != null:
			current_hp = int(battle_state.get("current_hp"))

	var max_sp := int(state.get("max_sp", 0))
	if max_sp <= 0 and actor.has_method("get_final_stat"):
		max_sp = int(actor.call("get_final_stat", "mp"))
	max_sp = maxi(1, max_sp)
	var current_sp := int(state.get("current_sp", max_sp))
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(current_hp, 0, max_hp)
	_sp_bar.max_value = max_sp
	_sp_bar.value = clampi(current_sp, 0, max_sp)
	_hp_value.text = "%d/%d" % [current_hp, max_hp]
	_sp_value.text = "%d/%d" % [current_sp, max_sp]


func _apply_interaction_mode(state: Dictionary) -> void:
	var user_turn := bool(state.get("is_user_turn", false))
	var planning := bool(state.get("is_planning_move", false))
	var targeting := bool(state.get("is_targeting", false))
	var battle_over := bool(state.get("battle_over", false))
	var contextual := user_turn and (planning or targeting) and not battle_over
	_action_grid.visible = user_turn and not contextual and not battle_over
	_context_row.visible = contextual
	_mov_label.visible = user_turn and not battle_over
	_phase_label.visible = not (_action_grid.visible and not bool(state.get("can_undo", false)))
	_dock.modulate = Color.WHITE if user_turn else Color(0.90, 0.90, 0.88, 0.88)


func _set_action_selected(button: Button, selected: bool) -> void:
	var accent: Color = _accent_by_button.get(button, UI.GOLD)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if not bool(state.get("is_user_turn", false)):
		return "Opponent turn"
	if bool(state.get("is_targeting", false)):
		return "Choose a target"
	match raw_phase:
		"Turn Start": return "Preparing turn"
		"Choose an action": return "Choose an action"
		"Preview movement": return "Trace a route, then confirm"
		"Plan movement": return "Trace a route, then confirm"
		"Moving": return "Moving"
		"Resolving action": return "Resolving action"
		"Turn End": return "Ending turn"
	return raw_phase


func _layout_dock() -> void:
	if _dock == null:
		return
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := UI.is_compact(viewport_obj, 820.0)
	var user_turn := bool(_cached_state.get("is_user_turn", false))
	var contextual := _context_row.visible
	var actions_visible := _action_grid.visible
	var side_margin := 10.0 if compact else 18.0
	var width := minf(1040.0, physical.x - side_margin * 2.0)
	var height := 128.0
	if compact:
		height = 188.0 if actions_visible else 116.0
	elif not user_turn or contextual:
		height = 90.0
	var bottom_margin := 8.0 if compact else 14.0
	_dock.scale = Vector2.ONE * ui_scale
	_dock.position = Vector2((physical.x - width) * 0.5 * ui_scale, (physical.y - height - bottom_margin) * ui_scale)
	_dock.size = Vector2(width, height)
	_signal_line.position = Vector2(16.0, 0.0)
	_signal_line.size = Vector2(72.0, 2.0)

	var pad := 12.0
	var actor_font := 17 if compact else 18
	_actor_label.add_theme_font_size_override("font_size", actor_font)
	_hp_value.add_theme_font_size_override("font_size", 14)
	_sp_value.add_theme_font_size_override("font_size", 14)
	for row in [_hp_bar.get_parent(), _sp_bar.get_parent()]:
		var caption := (row as HBoxContainer).get_child(0) as Label
		caption.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_font_size_override("font_size", 14 if compact else 15)
	_mov_label.add_theme_font_size_override("font_size", 14)

	if compact:
		_portrait_frame.custom_minimum_size = Vector2(50.0, 50.0)
		_unit_block.position = Vector2(pad, 10.0)
		_unit_block.size = Vector2(width - pad * 2.0, 58.0)
		_phase_label.position = Vector2(pad, 72.0)
		_phase_label.size = Vector2(width - 116.0, 30.0)
		_mov_label.position = Vector2(width - 98.0, 74.0)
		_mov_label.size = Vector2(86.0, 27.0)
		if actions_visible:
			_action_grid.columns = 3
			_action_grid.position = Vector2(pad, 108.0)
			_action_grid.size = Vector2(width - pad * 2.0, height - 118.0)
			for button: Button in _primary_buttons:
				button.custom_minimum_size = Vector2(0.0, 52.0)
			_undo_button.custom_minimum_size = Vector2(0.0, 52.0)
		elif contextual:
			_context_row.position = Vector2(pad, 68.0)
			_context_row.size = Vector2(width - pad * 2.0, 42.0)
			_phase_label.position = Vector2(pad, 68.0)
			_phase_label.size = Vector2(maxf(80.0, width - 250.0), 42.0)
	else:
		_portrait_frame.custom_minimum_size = Vector2(58.0, 58.0)
		var unit_width := minf(318.0, width * 0.34)
		_unit_block.position = Vector2(pad, 14.0)
		_unit_block.size = Vector2(unit_width, 64.0)
		if actions_visible:
			var action_x := unit_width + 26.0
			_action_grid.columns = 6 if _undo_button.visible else 5
			_action_grid.position = Vector2(action_x, 14.0)
			_action_grid.size = Vector2(width - action_x - pad, 60.0)
			_phase_label.position = Vector2(action_x, 80.0)
			_phase_label.size = Vector2(width - action_x - 110.0, 30.0)
			_mov_label.position = Vector2(width - 100.0, 82.0)
			_mov_label.size = Vector2(88.0, 27.0)
		elif contextual:
			_phase_label.position = Vector2(unit_width + 28.0, 16.0)
			_phase_label.size = Vector2(maxf(120.0, width - unit_width - 300.0), 58.0)
			_context_row.position = Vector2(width - 252.0, 18.0)
			_context_row.size = Vector2(240.0, 52.0)
			_mov_label.position = Vector2(unit_width + 28.0, 54.0)
			_mov_label.size = Vector2(96.0, 27.0)
		else:
			_phase_label.position = Vector2(unit_width + 28.0, 16.0)
			_phase_label.size = Vector2(width - unit_width - 40.0, 58.0)
			_mov_label.visible = false

	_context_row.visible = contextual
	_action_grid.visible = actions_visible


func _load_portrait(digimon_key: String) -> Texture2D:
	if digimon_key.is_empty():
		return null
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return null
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return null
	var strip := load(strip_path) as Texture2D
	if strip == null:
		return null
	var frame_width := float(metadata.get("frame_width", 0))
	var frame_height := float(metadata.get("frame_height", 0))
	if frame_width <= 0.0 or frame_height <= 0.0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, 0.0, frame_width, frame_height)
	return atlas


func _animate_actor_change() -> void:
	if _dock == null:
		return
	_dock.modulate.a = 0.62
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dock, "modulate:a", 1.0 if bool(_cached_state.get("is_user_turn", false)) else 0.88, 0.16)


func _on_action_hover(button: Button, entered: bool) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.018, 1.018) if entered else Vector2.ONE, 0.09)


func _on_action_pressed_visual(button: Button) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.985, 0.985)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)
