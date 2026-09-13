extends Control
class_name DigiLabHubScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const CreateScreenScript = preload("res://src/ui/ProgressionDigiLabCreateScreen.gd")
const PartyStorageScript = preload("res://src/ui/PartyStorageScreen.gd")
const DigimonMenuScript = preload("res://src/ui/DigimonProgressionMenu.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")

var _frame: PanelContainer
var _close: Button
var _create_screen: DigiLabScreen
var _party_screen: PartyStorageScreen
var _digimon_menu: DigimonProgressionMenu
var _nested_open := false
var _service_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false

func open_lab() -> void:
	_nested_open = false
	_hide_nested_views()
	visible = true
	_frame.visible = true
	call_deferred("_layout")
	call_deferred("_focus_first_service")
	_frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_frame, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close_view() -> void:
	if _nested_open:
		_close_nested()
		return
	visible = false
	close_requested.emit()

func is_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		if _nested_open:
			_close_nested()
		else:
			close_view()
		get_viewport().set_input_as_handled()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "DigiLabHubPanel"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", MENU.screen_frame())
	add_child(_frame)

	var margin := MENU.margin(18, 16, 18, 18)
	_frame.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 11)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	heading.add_child(_label("DIGILAB", 25, UI.TEXT, true))
	heading.add_child(_label("Manage your Digimon, reconstruction and active party.", 11, UI.MUTED))
	_close = MENU.icon_button(CLOSE_ICON, UI.MUTED, "Close DigiLab", Vector2(44, 44))
	_close.pressed.connect(close_view)
	header.add_child(_close)

	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = UI.separator(UI.CYAN, 0.20)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(divider)

	root.add_child(_label("Choose a service. Click, tap or focus a card and confirm.", 10, UI.SUBTLE, true))
	var modules := VBoxContainer.new()
	modules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modules.add_theme_constant_override("separation", 10)
	root.add_child(modules)
	_service_buttons.clear()
	_service_buttons.append(_module_card("DIGIMON", "Inspect levels, XP, stats, skills, Potential and evolution routes.", UI.GOLD, _open_digimon))
	_service_buttons.append(_module_card("CREATE DIGIMON", "Use Digi Data collected in battle to reconstruct a new persistent individual.", UI.CYAN, _open_create))
	_service_buttons.append(_module_card("PARTY / STORAGE", "Organize the active squad, reorder slots and manage reserve Digimon.", UI.GREEN, _open_party))
	for button: Button in _service_buttons:
		modules.add_child(button)

	_create_screen = CreateScreenScript.new() as DigiLabScreen
	_create_screen.name = "CreateDigimon"
	_create_screen.visible = false
	_create_screen.close_requested.connect(_close_nested)
	add_child(_create_screen)

	_party_screen = PartyStorageScript.new() as PartyStorageScreen
	_party_screen.name = "PartyStorage"
	_party_screen.visible = false
	_party_screen.close_requested.connect(_close_nested)
	add_child(_party_screen)

	_digimon_menu = DigimonMenuScript.new() as DigimonProgressionMenu
	_digimon_menu.name = "DigimonProgression"
	_digimon_menu.visible = false
	_digimon_menu.close_requested.connect(_close_nested)
	add_child(_digimon_menu)

func _module_card(title: String, description: String, accent: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.tooltip_text = "Open %s" % title.capitalize()
	button.pressed.connect(callback)
	MENU.style_action_button(button, accent)

	var margin := MENU.margin(16, 11, 14, 11)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(_label(title, 17, accent.lightened(0.10), true))
	var body := _label(description, 11, UI.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(body)
	var cue := _label(">", 22, accent, true)
	cue.custom_minimum_size.x = 34
	cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(cue)
	return button

func _focus_first_service() -> void:
	if visible and _frame.visible and not _service_buttons.is_empty():
		_service_buttons[0].grab_focus()

func _open_create() -> void:
	_nested_open = true
	_hide_nested_views()
	_frame.visible = false
	_create_screen.open_lab()

func _open_party() -> void:
	_nested_open = true
	_hide_nested_views()
	_frame.visible = false
	_party_screen.open_screen()

func _open_digimon() -> void:
	_nested_open = true
	_hide_nested_views()
	_frame.visible = false
	_digimon_menu.open_menu()

func _close_nested() -> void:
	_nested_open = false
	_hide_nested_views()
	_frame.visible = true
	call_deferred("_layout")
	call_deferred("_focus_first_service")

func _hide_nested_views() -> void:
	if _create_screen != null:
		_create_screen.visible = false
	if _party_screen != null:
		_party_screen.visible = false
	if _digimon_menu != null:
		_digimon_menu.visible = false

func _layout() -> void:
	if not visible or _frame == null:
		return
	var layout := MENU.apply_safe_frame(_frame, get_viewport(), Vector2(1040, 620), 820.0)
	var compact := bool(layout.get("compact", false))
	for button: Button in _service_buttons:
		button.custom_minimum_size.y = 82 if compact else 94

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label
