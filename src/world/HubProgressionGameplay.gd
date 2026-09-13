extends "res://src/world/HubMobileGameplay.gd"

const DigimonRosterMenuScript = preload("res://src/ui/DigimonProgressionMenu.gd")
const DigiLabHubScreenScript = preload("res://src/ui/DigiLabHubScreen.gd")

var _digimon_menu: DigimonRosterMenu = null
var _menu_open := false
var _touch_menu_button: Button = null
var _digilab: DigiLabHubScreen = null
var _digilab_open := false
var _digilab_terminal: Node2D = null
var _touch_digilab_button: Button = null


func _ready() -> void:
	super._ready()
	_build_digimon_menu()
	_build_digilab_terminal()
	_build_digilab_ui()
	call_deferred("_layout_ui")


func _unhandled_input(event: InputEvent) -> void:
	if _digilab_open:
		return
	if _menu_open:
		if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel"):
			if _digimon_menu is DigimonProgressionMenu and (_digimon_menu as DigimonProgressionMenu).has_nested_view_open():
				return
			_close_digimon_menu()
			get_viewport().set_input_as_handled()
		return
	if not _dialog_open and not _transitioning and _is_interact_event(event) and _is_digilab_nearby():
		_open_digilab()
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


func _build_digilab_terminal() -> void:
	var actors := get_node_or_null("Actors") as Node2D
	if actors == null:
		return
	_digilab_terminal = Node2D.new()
	_digilab_terminal.name = "DigiLabTerminal"
	_digilab_terminal.position = _grid_to_world(Vector2(2, 3))
	_digilab_terminal.z_index = 960 + int(round(_digilab_terminal.position.y))
	actors.add_child(_digilab_terminal)
	var base := Sprite2D.new()
	base.texture = CRATE_TEXTURE
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.position = Vector2(0, -28)
	base.scale = Vector2(0.9, 0.9)
	base.modulate = Color(0.58, 0.95, 1.0, 1.0)
	_digilab_terminal.add_child(base)
	var glow := PointLight2D.new()
	glow.energy = 0.55
	glow.texture_scale = 1.4
	glow.color = UI.CYAN
	glow.position = Vector2(0, -32)
	_digilab_terminal.add_child(glow)
	var label := Label.new()
	label.position = Vector2(-72, -76)
	label.size = Vector2(144, 24)
	label.text = "DIGILAB"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UI.CYAN)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	_digilab_terminal.add_child(label)
	_blockers.append({"position": _digilab_terminal.position, "radius": 24.0})


func _build_digilab_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DigiLabUI"
	layer.layer = 92
	add_child(layer)
	_digilab = DigiLabHubScreenScript.new() as DigiLabHubScreen
	_digilab.name = "DigiLab"
	_digilab.visible = false
	_digilab.close_requested.connect(_close_digilab)
	layer.add_child(_digilab)

	_touch_digilab_button = _dialog_button("DIGILAB", UI.CYAN)
	_touch_digilab_button.name = "OpenDigiLab"
	_touch_digilab_button.focus_mode = Control.FOCUS_NONE
	_touch_digilab_button.pressed.connect(_open_digilab)
	_ui_root.add_child(_touch_digilab_button)


func _open_digimon_menu() -> void:
	if _menu_open or _digilab_open or _dialog_open or _transitioning or _digimon_menu == null:
		return
	_menu_open = true
	_release_touch_movement()
	if _player != null:
		_player.set_physics_process(false)
	_digimon_menu.open_menu()
	_layout_ui()
	if OS.is_debug_build():
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
	if OS.is_debug_build():
		print("[Hub] DIGIMON_MENU close")


func _open_digilab() -> void:
	if _digilab_open or _menu_open or _dialog_open or _transitioning or _digilab == null:
		return
	_digilab_open = true
	_release_touch_movement()
	if _player != null:
		_player.set_physics_process(false)
	_digilab.open_lab()
	_layout_ui()
	if OS.is_debug_build():
		print("[Hub] DIGILAB open")


func _close_digilab() -> void:
	if not _digilab_open:
		return
	_digilab_open = false
	if _digilab != null:
		_digilab.visible = false
	if _player != null:
		_player.set_physics_process(true)
	_layout_ui()
	if OS.is_debug_build():
		print("[Hub] DIGILAB close")


func _refresh_interaction() -> void:
	if _interaction_prompt == null:
		return
	if _digilab_open or _menu_open or _dialog_open:
		_interaction_prompt.visible = false
		return
	if _is_digilab_nearby():
		_interaction_prompt.visible = true
		_prompt_label.text = "E / ENTER   OPEN DIGILAB"
		return
	super._refresh_interaction()


func _is_digilab_nearby() -> bool:
	return _player != null and _digilab_terminal != null and _player.position.distance_to(_digilab_terminal.position) <= INTERACTION_DISTANCE


func _layout_ui() -> void:
	super._layout_ui()
	if _touch_menu_button == null or _touch_digilab_button == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var scale_factor := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 820.0)
	var touch_layout := DisplayServer.is_touchscreen_available() or compact
	var actions_visible := touch_layout and not _menu_open and not _digilab_open and not _dialog_open and not _transitioning
	_touch_menu_button.visible = actions_visible
	_touch_digilab_button.visible = actions_visible
	_touch_menu_button.scale = Vector2.ONE * scale_factor
	_touch_digilab_button.scale = Vector2.ONE * scale_factor
	_touch_menu_button.size = Vector2(118.0, 46.0)
	_touch_digilab_button.size = Vector2(118.0, 46.0)
	_touch_menu_button.position = Vector2(physical.x - 132.0, physical.y - 132.0) * scale_factor
	_touch_digilab_button.position = Vector2(physical.x - 260.0, physical.y - 132.0) * scale_factor
