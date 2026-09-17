extends Control
class_name DigiSystemSettingsPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const SettingsRowScript = preload("res://src/ui/components/DigiSettingsRow.gd")
const SettingsToggleScript = preload("res://src/ui/components/DigiSettingsToggle.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")

const CATEGORY_WIDTH := 250.0
const PANEL_GAP := 12

var _sidebar: PanelContainer
var _content: PanelContainer
var _compact_category: Button
var _mute_button: DigiSettingsToggle
var _rows: Array[DigiSettingsRow] = []
var _focusables: Array[Control] = []
var _analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate
var _compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	GameSettings.audio_volume_changed.connect(_on_external_volume_changed)
	GameSettings.audio_mute_changed.connect(_on_external_mute_changed)


func focus_default() -> void:
	if not _rows.is_empty():
		_rows[0].grab_focus()
	elif _mute_button != null:
		_mute_button.grab_focus()
	_analog_gate.reset()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_Y:
			var vertical := _analog_gate.vertical_step(motion.axis_value)
			if vertical != 0:
				_move_focus(vertical)
			return true
		if motion.axis == JOY_AXIS_LEFT_X:
			var horizontal := _analog_gate.horizontal_step(motion.axis_value)
			if horizontal != 0:
				_adjust_focused(horizontal)
			return true
		return false

	if event.is_action_pressed("ui_up"):
		_move_focus(-1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_focus(1)
		return true
	if event.is_action_pressed("ui_left"):
		_adjust_focused(-1)
		return true
	if event.is_action_pressed("ui_right"):
		_adjust_focused(1)
		return true
	return false


func set_compact(enabled: bool) -> void:
	if _compact == enabled:
		return
	_compact = enabled
	if _sidebar != null:
		_sidebar.visible = not enabled
	if _compact_category != null:
		_compact_category.visible = enabled
	for row: DigiSettingsRow in _rows:
		row.set_compact(enabled)


func get_volume_row(setting_key: String) -> DigiSettingsRow:
	for row: DigiSettingsRow in _rows:
		if row.get_setting_key() == setting_key:
			return row
	return null


func get_mute_button() -> DigiSettingsToggle:
	return _mute_button


func _build() -> void:
	var root := HBoxContainer.new()
	root.name = "SystemWorkspace"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", PANEL_GAP)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	_sidebar = PanelContainer.new()
	_sidebar.name = "SettingsCategories"
	_sidebar.custom_minimum_size.x = CATEGORY_WIDTH
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.CYAN))
	root.add_child(_sidebar)

	var sidebar_stack := VBoxContainer.new()
	_sidebar.add_child(sidebar_stack)
	var sidebar_header := SectionHeaderScript.new() as DigiSectionHeader
	sidebar_header.configure("SYSTEM", "", V2.CYAN, "gear")
	sidebar_header.set_workspace_mode(true)
	sidebar_stack.add_child(sidebar_header)

	var category_margin := MarginContainer.new()
	category_margin.add_theme_constant_override("margin_left", 10)
	category_margin.add_theme_constant_override("margin_top", 10)
	category_margin.add_theme_constant_override("margin_right", 10)
	category_margin.add_theme_constant_override("margin_bottom", 10)
	sidebar_stack.add_child(category_margin)
	var categories := VBoxContainer.new()
	categories.add_theme_constant_override("separation", 8)
	category_margin.add_child(categories)
	var audio_category := _category_button("AUDIO", true)
	audio_category.name = "SystemCategoryAudio"
	categories.add_child(audio_category)

	_content = PanelContainer.new()
	_content.name = "AudioSettingsPanel"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.CYAN))
	root.add_child(_content)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_content.add_child(stack)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("AUDIO", "Balance music and sound", V2.CYAN, "gear")
	header.set_workspace_mode(true)
	stack.add_child(header)

	var action_margin := MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 12)
	action_margin.add_theme_constant_override("margin_top", 8)
	action_margin.add_theme_constant_override("margin_right", 12)
	action_margin.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(action_margin)
	var action_row := HBoxContainer.new()
	action_row.custom_minimum_size.y = 46.0
	action_row.add_theme_constant_override("separation", 10)
	action_margin.add_child(action_row)

	_compact_category = _category_button("AUDIO", true)
	_compact_category.name = "CompactSystemCategoryAudio"
	_compact_category.custom_minimum_size = Vector2(116.0, 42.0)
	_compact_category.visible = false
	action_row.add_child(_compact_category)

	var summary := Label.new()
	summary.text = "Adjust channels independently or silence the whole game instantly."
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_body(summary)
	action_row.add_child(summary)

	_mute_button = SettingsToggleScript.new() as DigiSettingsToggle
	_mute_button.name = "MuteAllAudio"
	_mute_button.configure("MUTE ALL", "MUTED", GameSettings.is_audio_muted(), V2.CYAN)
	_mute_button.toggled.connect(_on_mute_toggled)
	action_row.add_child(_mute_button)
	_focusables.append(_mute_button)

	var rows_margin := MarginContainer.new()
	rows_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_margin.add_theme_constant_override("margin_left", 12)
	rows_margin.add_theme_constant_override("margin_top", 0)
	rows_margin.add_theme_constant_override("margin_right", 12)
	rows_margin.add_theme_constant_override("margin_bottom", 12)
	stack.add_child(rows_margin)
	var rows_stack := VBoxContainer.new()
	rows_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_stack.add_theme_constant_override("separation", 8)
	rows_margin.add_child(rows_stack)

	_add_volume_row(rows_stack, "master", "Master Volume", "Overall game volume")
	_add_volume_row(rows_stack, "music", "Music", "Background music, battle themes and result themes")
	_add_volume_row(rows_stack, "sfx", "Sound Effects", "All gameplay and interface sound effects")
	_add_volume_row(rows_stack, "battle", "Battle Effects", "Attacks, techniques and combat impacts")
	_add_volume_row(rows_stack, "ui", "UI Effects", "Menu navigation, confirmation, back and open sounds")


func _add_volume_row(parent: VBoxContainer, key: String, title: String, description: String) -> void:
	var row := SettingsRowScript.new() as DigiSettingsRow
	row.name = "Audio_%s" % key.capitalize()
	row.configure(key, title, description, GameSettings.get_audio_volume(key))
	row.value_changed.connect(_on_volume_changed)
	parent.add_child(row)
	_rows.append(row)
	_focusables.append(row)


func _category_button(text: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", V2.WHITE if selected else V2.MUTED)
	button.add_theme_stylebox_override("normal", V2.button_style(V2.CYAN, "selected" if selected else "normal"))
	V2.apply_heading(button)
	return button


func _move_focus(delta: int) -> void:
	if _focusables.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var current := _focusables.find(owner)
	if current < 0:
		current = 1 if _focusables.size() > 1 else 0
	var next := posmod(current + delta, _focusables.size())
	_focusables[next].grab_focus()


func _adjust_focused(direction: int) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if not owner is DigiSettingsRow:
		return
	var row := owner as DigiSettingsRow
	if row.adjust(direction):
		UiSfxDirector.play_navigation()


func _on_volume_changed(setting_key: String, value: float) -> void:
	GameSettings.set_audio_volume(setting_key, value)


func _on_mute_toggled(muted: bool) -> void:
	GameSettings.set_audio_muted(muted)


func _on_external_volume_changed(setting_key: String, value: float) -> void:
	var row := get_volume_row(setting_key)
	if row != null:
		row.set_value(value)


func _on_external_mute_changed(muted: bool) -> void:
	if _mute_button != null:
		_mute_button.set_active(muted)
