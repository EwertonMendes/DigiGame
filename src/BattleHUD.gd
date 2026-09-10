extends Control

const PORTRAIT_ROOT := "res://assets/characters"
const CYAN := Color(0.12, 0.88, 1.0, 1.0)
const BLUE := Color(0.16, 0.52, 1.0, 1.0)
const GOLD := Color(1.0, 0.76, 0.16, 1.0)
const GREEN := Color(0.18, 0.86, 0.62, 1.0)
const RED := Color(1.0, 0.30, 0.28, 1.0)
const TEXT := Color(0.93, 0.98, 1.0, 1.0)
const MUTED := Color(0.58, 0.72, 0.82, 1.0)
const PANEL_BG := Color(0.018, 0.055, 0.09, 0.94)

var _controller: Node
var _panel: PanelContainer
var _portrait: TextureRect
var _turn_label: Label
var _phase_label: Label
var _mov_label: Label
var _team_label: Label
var _move_button: Button
var _confirm_move_button: Button
var _defend_button: Button
var _wait_button: Button
var _undo_button: Button
var _cancel_button: Button
var _last_actor_key := ""

var _portrait_atlas: AtlasTexture
var _frame_size := Vector2.ZERO
var _frame_count := 0
var _frame_durations: Array = []
var _frame_index := 0
var _frame_elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_controller = get_node_or_null("../../BattleController")
	_refresh_connections()
	refresh_from_controller()
	get_viewport().size_changed.connect(_layout_panel)
	call_deferred("_layout_panel")


func _process(delta: float) -> void:
	if _frame_count <= 1 or _portrait_atlas == null or not _panel.visible:
		return
	_frame_elapsed += delta
	var duration := _frame_duration_seconds()
	while _frame_elapsed >= duration:
		_frame_elapsed -= duration
		_frame_index = (_frame_index + 1) % _frame_count
		_apply_portrait_frame()
		duration = _frame_duration_seconds()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TurnPanel"
	_panel.custom_minimum_size = Vector2(650.0, 166.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(112.0, 112.0)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _portrait_style())
	root.add_child(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(104.0, 104.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var eyebrow := Label.new()
	eyebrow.text = "TACTICAL LINK  //  ACTIVE UNIT"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", MUTED)
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(eyebrow)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(title_row)

	_turn_label = Label.new()
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.add_theme_font_size_override("font_size", 27)
	_turn_label.add_theme_color_override("font_color", TEXT)
	_turn_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.7, 1.0, 0.28))
	_turn_label.add_theme_constant_override("shadow_offset_x", 1)
	_turn_label.add_theme_constant_override("shadow_offset_y", 2)
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_turn_label)

	_team_label = Label.new()
	_team_label.custom_minimum_size = Vector2(92.0, 28.0)
	_team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_team_label.add_theme_font_size_override("font_size", 11)
	_team_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_team_label)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 10)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(meta_row)

	_phase_label = Label.new()
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_color_override("font_color", Color(0.72, 0.88, 0.96, 1.0))
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(_phase_label)

	_mov_label = Label.new()
	_mov_label.custom_minimum_size = Vector2(100.0, 28.0)
	_mov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mov_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mov_label.add_theme_font_size_override("font_size", 13)
	_mov_label.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0, 1.0))
	_mov_label.add_theme_stylebox_override("normal", _pill_style(CYAN))
	_mov_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(_mov_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.color = Color(0.12, 0.78, 1.0, 0.22)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(divider)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(buttons)

	_move_button = _make_button("MOVE", CYAN)
	_confirm_move_button = _make_button("CONFIRM", GREEN)
	_defend_button = _make_button("DEFEND", GREEN)
	_wait_button = _make_button("WAIT", BLUE)
	_undo_button = _make_button("UNDO", GOLD)
	_cancel_button = _make_button("CANCEL", RED)
	buttons.add_child(_move_button)
	buttons.add_child(_confirm_move_button)
	buttons.add_child(_defend_button)
	buttons.add_child(_wait_button)
	buttons.add_child(_undo_button)
	buttons.add_child(_cancel_button)


func _make_button(label: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(96.0, 38.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.64, 0.70, 0.72))
	button.add_theme_stylebox_override("normal", _button_style(accent, 0.16, 0.62))
	button.add_theme_stylebox_override("hover", _button_style(accent, 0.28, 0.98))
	button.add_theme_stylebox_override("pressed", _button_style(accent, 0.42, 1.0))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.25, 0.34, 0.40), 0.08, 0.25))
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
		if _panel != null:
			_panel.visible = false
		return

	var state: Dictionary = _controller.call("get_hud_state")
	var actor: Node = _controller.get("current_actor") as Node
	var actor_key := ""
	var player_team := true
	if actor != null:
		actor_key = String(actor.get("digimon_key")).to_lower()
		player_team = bool(actor.get("is_player_controlled"))

	_panel.visible = true
	var actor_name := String(state.get("actor_name", ""))
	_turn_label.text = actor_name.to_upper() if not actor_name.is_empty() else "PREPARING BATTLE"
	_phase_label.text = _phase_copy(state)
	var planning := bool(state.get("is_planning_move", false))
	if planning:
		_mov_label.text = "MOV LEFT  %d" % int(state.get("move_remaining", 0))
	else:
		_mov_label.text = "MOV  %d" % int(state.get("mov", 4))
	_team_label.text = "ALLY TURN" if player_team else "ENEMY TURN"
	_team_label.add_theme_color_override("font_color", Color(0.86, 0.98, 1.0) if player_team else Color(1.0, 0.88, 0.84))
	_team_label.add_theme_stylebox_override("normal", _pill_style(CYAN if player_team else RED))

	_move_button.visible = bool(state.get("can_move", false))
	_confirm_move_button.visible = planning and bool(state.get("is_user_turn", false))
	_confirm_move_button.disabled = not bool(state.get("can_confirm_move", false))
	_defend_button.visible = bool(state.get("can_defend", false))
	_wait_button.visible = bool(state.get("can_wait", false))
	_undo_button.visible = bool(state.get("can_undo", false))
	_cancel_button.visible = bool(state.get("can_cancel", false))

	if actor_key != _last_actor_key:
		_last_actor_key = actor_key
		_load_portrait_animation(actor_key)
		_animate_actor_change()


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if not bool(state.get("is_user_turn", false)):
		return "Opponent's turn..."
	match raw_phase:
		"Turn Start": return "Starting turn..."
		"Choose an action": return "Select an action for this Digimon"
		"Plan movement": return "Trace the route tile by tile • tap or drag adjacent tiles"
		"Moving": return "Following your tactical route..."
		"Choose a target": return "Select a target"
		"Resolving action": return "Resolving action..."
		"Turn End": return "Ending turn..."
	return raw_phase


func _load_portrait_animation(digimon_key: String) -> void:
	_portrait.texture = null
	_portrait_atlas = null
	_frame_size = Vector2.ZERO
	_frame_count = 0
	_frame_durations = []
	_frame_index = 0
	_frame_elapsed = 0.0
	if digimon_key.is_empty():
		return
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return
	var strip := load(strip_path) as Texture2D
	if strip == null:
		return
	_frame_size = Vector2(float(metadata.get("frame_width", 0)), float(metadata.get("frame_height", 0)))
	_frame_count = int(metadata.get("frame_count", 0))
	_frame_durations = metadata.get("durations_ms", [])
	if _frame_size.x <= 0.0 or _frame_size.y <= 0.0 or _frame_count <= 0:
		return
	_portrait_atlas = AtlasTexture.new()
	_portrait_atlas.atlas = strip
	_portrait.texture = _portrait_atlas
	_apply_portrait_frame()


func _frame_duration_seconds() -> float:
	if _frame_index < _frame_durations.size():
		return maxf(0.02, float(_frame_durations[_frame_index]) / 1000.0)
	return 0.1


func _apply_portrait_frame() -> void:
	if _portrait_atlas == null:
		return
	_portrait_atlas.region = Rect2(_frame_size.x * _frame_index, 0.0, _frame_size.x, _frame_size.y)


func _animate_actor_change() -> void:
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.scale = Vector2(0.985, 0.985)
	_panel.pivot_offset = _panel.custom_minimum_size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.18)


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _panel.custom_minimum_size
	_panel.position = Vector2(
		maxf(16.0, (viewport_size.x - panel_size.x) * 0.5),
		maxf(16.0, viewport_size.y - panel_size.y - 18.0)
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(0.10, 0.76, 1.0, 0.68)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.10, 0.15, 0.92)
	style.border_color = Color(0.15, 0.82, 1.0, 0.58)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


func _pill_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := accent
	bg.a = 0.14
	var border := accent
	border.a = 0.56
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _button_style(accent: Color, alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := accent
	bg.a = alpha
	var border := accent
	border.a = border_alpha
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style
