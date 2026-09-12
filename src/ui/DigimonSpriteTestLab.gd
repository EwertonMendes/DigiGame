extends Control
class_name DigimonSpriteTestLab

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const FollowerScript = preload("res://src/world/OverworldDigimonFollower.gd")
const FACINGS: Array[String] = ["down_left", "down_right", "up_right", "up_left"]
const AUTO_VECTORS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
const AUTO_STEP := 1.1
const PADDING := 56.0
const INSPECT_SCALES: Array[float] = [1.0, 1.5, 2.0]

var _picker: OptionButton
var _field: Control
var _field_dark: ColorRect
var _field_light: ColorRect
var _name_label: Label
var _state_label: Label
var _auto_button: Button
var _zoom_button: Button
var _entries: Array[Dictionary] = []
var _index := 0
var _follower = null
var _touch := Vector2.ZERO
var _auto := false
var _auto_index := 0
var _auto_time := 0.0
var _inspect_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_load_entries()
	visible = false
	set_process(false)


func open_lab() -> void:
	visible = true
	set_process(true)
	_auto = false
	_touch = Vector2.ZERO
	_refresh_auto_text()
	call_deferred("_spawn_selected")


func close_lab() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	_auto = false
	_touch = Vector2.ZERO
	if _follower != null:
		_follower.set_idle()
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.physical_keycode:
				KEY_ESCAPE:
					close_lab()
				KEY_Q:
					_rotate(-1)
				KEY_E:
					_rotate(1)
				KEY_R:
					_reset_actor()
				KEY_SPACE:
					_toggle_auto()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _follower == null:
		return
	var direction := _movement_input()
	if _auto:
		_auto_time += delta
		if _auto_time >= AUTO_STEP:
			_auto_time = 0.0
			_auto_index = (_auto_index + 1) % AUTO_VECTORS.size()
		direction = AUTO_VECTORS[_auto_index]
	if direction.length_squared() > 0.01:
		var target := _follower.global_position + direction.normalized() * 1000.0
		_follower.step_toward(target, delta, [])
		_clamp_actor()
	else:
		_follower.set_idle()
	_refresh_state()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.004, 0.01, 0.025, 0.985)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		outer.add_theme_constant_override("margin_%s" % side, 18)
	add_child(outer)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	outer.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	frame.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("DIGIMON SPRITE TEST LAB", 24, UI.TEXT))
	titles.add_child(_label("Temporary tool · production movement, animation, facing and transparency", 11, UI.MUTED))
	var close := _button("CLOSE", UI.MUTED)
	close.pressed.connect(close_lab)
	header.add_child(close)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	root.add_child(toolbar)
	var previous := _button("◀ PREV", UI.CYAN)
	previous.pressed.connect(_select_relative.bind(-1))
	toolbar.add_child(previous)
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.custom_minimum_size.x = 220
	_picker.add_theme_font_size_override("font_size", 13)
	_picker.add_theme_color_override("font_color", UI.TEXT)
	_picker.item_selected.connect(_select_species)
	toolbar.add_child(_picker)
	var next := _button("NEXT ▶", UI.CYAN)
	next.pressed.connect(_select_relative.bind(1))
	toolbar.add_child(next)
	_auto_button = _button("AUTO: OFF", UI.PURPLE)
	_auto_button.pressed.connect(_toggle_auto)
	toolbar.add_child(_auto_button)
	var reset := _button("RESET", UI.GOLD)
	reset.pressed.connect(_reset_actor)
	toolbar.add_child(reset)
	_zoom_button = _button("INSPECT 1.0×", UI.CYAN)
	_zoom_button.pressed.connect(_cycle_zoom)
	toolbar.add_child(_zoom_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var field_panel := PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_panel.custom_minimum_size = Vector2(380, 300)
	field_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.86, 0.2, 8, 2))
	body.add_child(field_panel)
	_field = Control.new()
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_panel.add_child(_field)
	_field.resized.connect(_on_field_resized)

	# Two high-contrast halves make stray background pixels obvious without
	# changing the sprite texture itself.
	_field_dark = ColorRect.new()
	_field_dark.color = Color(0.035, 0.055, 0.08, 1.0)
	_field_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_dark.z_index = -10
	_field.add_child(_field_dark)
	_field_light = ColorRect.new()
	_field_light.color = Color(0.68, 0.70, 0.72, 1.0)
	_field_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_light.z_index = -10
	_field.add_child(_field_light)

	var side := PanelContainer.new()
	side.custom_minimum_size.x = 320
	side.add_theme_stylebox_override("panel", UI.panel(UI.PURPLE, 0.9, 0.25, 10, 2))
	body.add_child(side)
	var side_margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		side_margin.add_theme_constant_override("margin_%s" % edge, 14)
	side.add_child(side_margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	side_margin.add_child(stack)
	_name_label = _label("NO SPRITE", 19, UI.TEXT)
	stack.add_child(_name_label)
	_state_label = _label("", 11, UI.CYAN)
	stack.add_child(_state_label)
	stack.add_child(_label("MOVE · HOLD", 10, UI.GOLD))
	var move_grid := GridContainer.new()
	move_grid.columns = 2
	stack.add_child(move_grid)
	_add_move(move_grid, "↖ UP LEFT", Vector2(-1, -1))
	_add_move(move_grid, "UP RIGHT ↗", Vector2(1, -1))
	_add_move(move_grid, "↙ DOWN LEFT", Vector2(-1, 1))
	_add_move(move_grid, "DOWN RIGHT ↘", Vector2(1, 1))
	stack.add_child(_label("FACE · CLICK", 10, UI.GOLD))
	var face_grid := GridContainer.new()
	face_grid.columns = 2
	stack.add_child(face_grid)
	_add_face(face_grid, "FRONT LEFT", "down_left")
	_add_face(face_grid, "FRONT RIGHT", "down_right")
	_add_face(face_grid, "BACK LEFT", "up_left")
	_add_face(face_grid, "BACK RIGHT", "up_right")
	var help := _label("WASD / arrows: move\nQ / E: rotate facing\nR: reset\nSpace: auto patrol\nDark/light field: inspect residue", 11, UI.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(help)


func _load_entries() -> void:
	_entries.clear()
	_picker.clear()
	var directory := DirAccess.open("res://assets/resources")
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".tres"):
			var path := "res://assets/resources/%s" % filename
			var resource := load(path) as Digimon
			if resource != null and resource.texture != null:
				var key := filename.get_basename()
				var display := resource.display_name.strip_edges()
				if display.is_empty():
					display = key.capitalize()
				_entries.append({"key": key, "name": display, "path": path})
		filename = directory.get_next()
	directory.list_dir_end()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	var metal := -1
	for i in range(_entries.size()):
		_picker.add_item(String(_entries[i].get("name", "")))
		if String(_entries[i].get("name", "")).to_lower() == "metal greymon":
			metal = i
	if not _entries.is_empty():
		_index = metal if metal >= 0 else 0
		_picker.select(_index)


func _spawn_selected() -> void:
	if not visible or _entries.is_empty():
		return
	if _follower != null:
		_follower.queue_free()
		_follower = null
	var entry := _entries[_index]
	var resource := load(String(entry.get("path", ""))) as Digimon
	if resource == null:
		return
	_follower = FollowerScript.new()
	_follower.configure(resource, String(entry.get("key", "")), 0)
	_field.add_child(_follower)
	_follower.scale = Vector2.ONE * INSPECT_SCALES[_inspect_index]
	_name_label.text = String(entry.get("name", "")).to_upper()
	_reset_actor()


func _select_species(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_index = index
	_auto = false
	_refresh_auto_text()
	_spawn_selected()


func _select_relative(offset: int) -> void:
	if _entries.is_empty():
		return
	_index = posmod(_index + offset, _entries.size())
	_picker.select(_index)
	_select_species(_index)


func _movement_input() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if wasd.length_squared() > direction.length_squared():
		direction = wasd
	if _touch.length_squared() > direction.length_squared():
		direction = _touch
	return direction.limit_length(1.0)


func _add_move(parent: Control, text_value: String, direction: Vector2) -> void:
	var button := _button(text_value, UI.CYAN)
	button.custom_minimum_size = Vector2(138, 42)
	button.button_down.connect(_set_touch.bind(direction.normalized()))
	button.button_up.connect(_clear_touch)
	button.mouse_exited.connect(_clear_touch)
	parent.add_child(button)


func _add_face(parent: Control, text_value: String, facing: String) -> void:
	var button := _button(text_value, UI.PURPLE)
	button.custom_minimum_size = Vector2(138, 40)
	button.pressed.connect(_set_facing.bind(facing))
	parent.add_child(button)


func _set_touch(direction: Vector2) -> void:
	_auto = false
	_refresh_auto_text()
	_touch = direction


func _clear_touch() -> void:
	_touch = Vector2.ZERO


func _set_facing(facing: String) -> void:
	if _follower == null:
		return
	_auto = false
	_touch = Vector2.ZERO
	_refresh_auto_text()
	_follower.teleport_to(_follower.global_position, facing)


func _rotate(offset: int) -> void:
	if _follower == null:
		return
	var current := String(_follower.get("facing_direction"))
	var i := FACINGS.find(current)
	if i < 0:
		i = 0
	_set_facing(FACINGS[posmod(i + offset, FACINGS.size())])


func _toggle_auto() -> void:
	_auto = not _auto
	_auto_time = 0.0
	_auto_index = 0
	_touch = Vector2.ZERO
	_refresh_auto_text()


func _refresh_auto_text() -> void:
	if _auto_button != null:
		_auto_button.text = "AUTO: ON" if _auto else "AUTO: OFF"


func _cycle_zoom() -> void:
	_inspect_index = (_inspect_index + 1) % INSPECT_SCALES.size()
	_zoom_button.text = "INSPECT %.1f×" % INSPECT_SCALES[_inspect_index]
	if _follower != null:
		_follower.scale = Vector2.ONE * INSPECT_SCALES[_inspect_index]
		_reset_actor()


func _reset_actor() -> void:
	if _follower == null or _field.size.x < 2.0:
		return
	_auto_time = 0.0
	var center_global := _field.get_global_transform() * (_field.size * 0.5 + Vector2(0, 20))
	_follower.teleport_to(center_global, "down_right")
	_clamp_actor()


func _clamp_actor() -> void:
	if _follower == null:
		return
	var inverse := _field.get_global_transform().affine_inverse()
	var p := inverse * _follower.global_position
	p.x = clampf(p.x, PADDING, maxf(PADDING, _field.size.x - PADDING))
	p.y = clampf(p.y, PADDING, maxf(PADDING, _field.size.y - PADDING))
	_follower.global_position = _field.get_global_transform() * p


func _on_field_resized() -> void:
	if _field_dark == null:
		return
	_field_dark.position = Vector2.ZERO
	_field_dark.size = Vector2(_field.size.x * 0.5, _field.size.y)
	_field_light.position = Vector2(_field.size.x * 0.5, 0)
	_field_light.size = Vector2(_field.size.x * 0.5, _field.size.y)
	if visible and _follower != null:
		_reset_actor()


func _refresh_state() -> void:
	if _follower == null or _entries.is_empty():
		return
	var resource := load(String(_entries[_index].get("path", ""))) as Digimon
	_state_label.text = "Facing: %s\nLayout: %s · %dx%d\nRuntime sprite scale: 1.5×\nInspection multiplier: %.1f×" % [String(_follower.get("facing_direction")), resource.sprite_layout, resource.sprite_hframes, resource.sprite_vframes, INSPECT_SCALES[_inspect_index]]


func _button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_body_font(label)
	return label
