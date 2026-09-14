extends Control
class_name DigiLabHubScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const CreateScreenScript = preload("res://src/ui/ProgressionDigiLabCreateScreen.gd")
const PartyStorageScript = preload("res://src/ui/PartyStorageScreen.gd")
const DigimonMenuScript = preload("res://src/ui/DigimonProgressionMenu.gd")
const AscensionExpansionScript = preload("res://src/ui/AscensionExpansionScreen.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")

var _frame: PanelContainer
var _menu_root: Control
var _title: Label
var _subtitle: Label
var _hint: Label
var _divider: ColorRect
var _modules: VBoxContainer
var _close: Button
var _create_screen: DigiLabScreen
var _party_screen: PartyStorageScreen
var _digimon_menu: DigimonProgressionMenu
var _ascension_screen: AscensionExpansionScreen
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
	_layout()
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

	_menu_root = Control.new()
	_menu_root.name = "MenuContent"
	_menu_root.clip_contents = true
	_frame.add_child(_menu_root)

	_title = _label("DIGILAB", 25, UI.TEXT, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu_root.add_child(_title)
	_subtitle = _label("Manage your Digimon, reconstruction and active party.", 11, UI.MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu_root.add_child(_subtitle)

	_close = MENU.close_button(CLOSE_ICON, "Close DigiLab")
	_close.pressed.connect(close_view)
	_menu_root.add_child(_close)

	_divider = ColorRect.new()
	_divider.color = UI.separator(UI.CYAN, 0.20)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(_divider)

	_hint = _label("Choose a service. Click, tap or focus a card and confirm.", 10, UI.SUBTLE, true)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu_root.add_child(_hint)

	_modules = VBoxContainer.new()
	_modules.add_theme_constant_override("separation", 10)
	_menu_root.add_child(_modules)
	_service_buttons.clear()
	_service_buttons.append(_module_card("DIGIMON", "Inspect levels, XP, stats, skills, Potential and evolution routes.", UI.GOLD, _open_digimon))
	_service_buttons.append(_module_card("ASCENSION / EXPANSION", "Raise individual Tier, fuse duplicate knowledge and configure 1×1 or 2×2 size.", UI.ORANGE, _open_ascension))
	_service_buttons.append(_module_card("CONVERT DIGI DATA", "Use Digi Data collected in battle to reconstruct a new persistent individual.", UI.CYAN, _open_create))
	_service_buttons.append(_module_card("PARTY / STORAGE", "Organize the active squad, reorder slots and manage reserve Digimon.", UI.GREEN, _open_party))
	for button: Button in _service_buttons:
		_modules.add_child(button)

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

	_ascension_screen = AscensionExpansionScript.new() as AscensionExpansionScreen
	_ascension_screen.name = "AscensionExpansion"
	_ascension_screen.visible = false
	_ascension_screen.close_requested.connect(_close_nested)
	add_child(_ascension_screen)

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
	var title_label := _label(title, 17, accent.lightened(0.10), true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	copy.add_child(title_label)
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

func _open_ascension() -> void:
	_nested_open = true
	_hide_nested_views()
	_frame.visible = false
	_ascension_screen.open_screen()

func _close_nested() -> void:
	_nested_open = false
	_hide_nested_views()
	_frame.visible = true
	_layout()
	call_deferred("_layout")
	call_deferred("_focus_first_service")

func _hide_nested_views() -> void:
	if _create_screen != null:
		_create_screen.visible = false
	if _party_screen != null:
		_party_screen.visible = false
	if _digimon_menu != null:
		_digimon_menu.visible = false
	if _ascension_screen != null:
		_ascension_screen.visible = false

func _layout() -> void:
	if not visible or _frame == null or _menu_root == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 820.0)
	var edge := 12.0 if compact else 24.0
	var width := minf(1040.0, maxf(1.0, physical.x - edge * 2.0))
	var height := minf(620.0, maxf(1.0, physical.y - edge * 2.0))
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_frame.clip_contents = true
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	_title.position = Vector2(24.0, 15.0)
	_title.size = Vector2(width - 110.0, 30.0)
	_subtitle.position = Vector2(24.0, 45.0)
	_subtitle.size = Vector2(width - 110.0, 22.0)
	_close.position = Vector2(width - 68.0, 14.0)
	_close.size = Vector2(44.0, 44.0)
	_divider.position = Vector2(22.0, 76.0)
	_divider.size = Vector2(width - 44.0, 1.0)
	_hint.position = Vector2(24.0, 84.0)
	_hint.size = Vector2(width - 48.0, 22.0)
	_modules.position = Vector2(22.0, 114.0)
	_modules.size = Vector2(width - 44.0, height - 136.0)
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
