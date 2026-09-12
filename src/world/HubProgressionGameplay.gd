extends "res://src/world/HubMobileGameplay.gd"

const DigimonRosterMenuScript = preload("res://src/ui/DigimonProgressionMenu.gd")

var _digimon_menu: DigimonRosterMenu = null
var _menu_open := false
var _touch_menu_button: Button = null


func _ready() -> void:
	super._ready()
	_build_digimon_menu()
	call_deferred("_layout_ui")


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel"):
			if _digimon_menu is DigimonProgressionMenu and (_digimon_menu as DigimonProgressionMenu).has_nested_view_open():
				return
			_close_digimon_menu()
			get_viewport().set_input_as_handled()
		return
	if not _dialog_open and not _transitioning and event.is_action_pressed("game_menu"):
		_open_digimon_menu()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _build_digimon_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DigimonMenuUI"
	layer.layer = 85
	add_child(layer)
	_digimon_menu = DigimonRosterMenuScript.new()
	_digimon_menu.name = "DigimonRosterMenu"
	_digimon_menu.visible = false
	_digimon_menu.close_requested.connect(_close_digimon_menu)
	layer.add_child(_digimon_menu)

	_touch_menu_button = _dialog_button("DIGIMON", UI.GOLD)
	_touch_menu_button.name = "OpenDigimonMenu"
	_touch_menu_button.focus_mode = Control.FOCUS_NONE
	_touch_menu_button.pressed.connect(_open_digimon_menu)
	_ui_root.add_child(_touch_menu_button)


func _open_digimon_menu() -> void:
	if _menu_open or _dialog_open or _transitioning or _digimon_menu == null:
		return
	_menu_open = true
	_release_touch_movement()
	if _player != null:
		_player.set_physics_process(false)
	_digimon_menu.open_menu()
	_layout_ui()
	print("[Hub] DIGIMON_MENU open")


func _close_digimon_menu() -> void:
	if not _menu_open:
		return
	_menu_open = false
	if _digimon_menu != null:
		_digimon_menu.visible = false
	if _player != null:
		_player.set_physics_process(true)
	_layout_ui()
	print("[Hub] DIGIMON_MENU close")


func _layout_ui() -> void:
	super._layout_ui()
	if _touch_menu_button == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var scale_factor := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 820.0)
	var touch_layout := DisplayServer.is_touchscreen_available() or compact
	_touch_menu_button.visible = touch_layout and not _menu_open and not _dialog_open and not _transitioning
	_touch_menu_button.scale = Vector2.ONE * scale_factor
	_touch_menu_button.size = Vector2(118.0, 46.0)
	_touch_menu_button.position = Vector2(physical.x - 132.0, physical.y - 132.0) * scale_factor
