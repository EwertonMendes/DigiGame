extends Control
class_name DigiLabHubScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const CreateScreenScript = preload("res://src/ui/DigiLabScreen.gd")
const PartyStorageScript = preload("res://src/ui/PartyStorageScreen.gd")
const DigimonMenuScript = preload("res://src/ui/DigimonProgressionMenu.gd")

var _frame: PanelContainer
var _title: Label
var _subtitle: Label
var _close: Button
var _create_screen: DigiLabScreen
var _party_screen: PartyStorageScreen
var _digimon_menu: DigimonProgressionMenu
var _nested_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_lab() -> void:
	_nested_open = false
	visible = true
	call_deferred("_layout")


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
	backdrop.color = Color(0.004, 0.012, 0.030, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(0.075, 0.13, 0.22, 0.99), Vector4.ZERO, 16.0))
	add_child(_frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 86)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	_frame.add_child(margin)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)

	_title = _label("DIGILAB", 28, UI.TEXT, true)
	add_child(_title)
	_subtitle = _label("Manage your Digimon outside battle", 12, UI.MUTED)
	add_child(_subtitle)
	_close = _button("CLOSE", UI.MUTED)
	_close.pressed.connect(close_view)
	add_child(_close)

	body.add_child(_module_card("DIGIMON", "Inspect level, XP, stats, skills, Potential and evolution goals.", UI.GOLD, _open_digimon))
	body.add_child(_module_card("EVOLUTION / DEGENERATION", "Choose a Digimon, inspect every route and requirement, then change form outside battle.", UI.PURPLE, _open_digimon))
	body.add_child(_module_card("CREATE DIGIMON", "Spend species Digi Data to reconstruct a new Level 1 individual.", UI.CYAN, _open_create))
	body.add_child(_module_card("PARTY / STORAGE", "Build a valid three-unit party, reorder it, or swap Digimon with storage.", UI.GREEN, _open_party))

	_create_screen = CreateScreenScript.new() as DigiLabScreen
	_create_screen.name = "CreateDigimon"
	_create_screen.close_requested.connect(_close_nested)
	add_child(_create_screen)

	_party_screen = PartyStorageScript.new() as PartyStorageScreen
	_party_screen.name = "PartyStorage"
	_party_screen.close_requested.connect(_close_nested)
	add_child(_party_screen)

	_digimon_menu = DigimonMenuScript.new() as DigimonProgressionMenu
	_digimon_menu.name = "DigimonProgression"
	_digimon_menu.close_requested.connect(_close_nested)
	add_child(_digimon_menu)


func _module_card(title: String, description: String, accent: Color, callback: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	panel.add_theme_stylebox_override("panel", SKIN.border_style(accent, Vector4(18, 14, 18, 14), 11.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	copy.add_child(_label(title, 17, accent.lightened(0.12), true))
	copy.add_child(_label(description, 11, UI.MUTED))
	var open := _button("OPEN", accent)
	open.custom_minimum_size = Vector2(112, 54)
	open.pressed.connect(callback)
	row.add_child(open)
	return panel


func _open_create() -> void:
	_nested_open = true
	_frame.visible = false
	_title.visible = false
	_subtitle.visible = false
	_close.visible = false
	_create_screen.open_lab()


func _open_party() -> void:
	_nested_open = true
	_frame.visible = false
	_title.visible = false
	_subtitle.visible = false
	_close.visible = false
	_party_screen.open_screen()


func _open_digimon() -> void:
	_nested_open = true
	_frame.visible = false
	_title.visible = false
	_subtitle.visible = false
	_close.visible = false
	_digimon_menu.open_menu()


func _close_nested() -> void:
	_nested_open = false
	if _create_screen != null:
		_create_screen.visible = false
	if _party_screen != null:
		_party_screen.visible = false
	if _digimon_menu != null:
		_digimon_menu.visible = false
	_frame.visible = true
	_title.visible = true
	_subtitle.visible = true
	_close.visible = true
	call_deferred("_layout")


func _layout() -> void:
	if not visible or _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var edge := 12.0
	var width := minf(820.0, physical.x - edge * 2.0)
	var height := minf(680.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = origin
	_frame.size = Vector2(width, height)
	_title.scale = Vector2.ONE * scale_factor
	_title.position = origin + Vector2(28, 18) * scale_factor
	_title.size = Vector2(width - 170, 36)
	_subtitle.scale = Vector2.ONE * scale_factor
	_subtitle.position = origin + Vector2(30, 50) * scale_factor
	_subtitle.size = Vector2(width - 190, 26)
	_close.scale = Vector2.ONE * scale_factor
	_close.position = origin + Vector2(width - 108, 18) * scale_factor
	_close.size = Vector2(82, 42)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	SKIN.apply_button(button, accent)
	return button
