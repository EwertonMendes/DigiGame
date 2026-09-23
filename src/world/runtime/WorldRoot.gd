extends Node2D
class_name WorldRoot

signal world_ready

const CatalogScript = preload("res://src/world/runtime/WorldAreaCatalog.gd")
const ActorScript = preload("res://src/world/runtime/OverworldActor.gd")
const FollowersScript = preload("res://src/world/runtime/WorldPartyFollowers.gd")
const CENTRAL_CITY_AREA_SCENE = preload("res://scenes/world/central_city_area.tscn")
const InteractionScript = preload("res://src/world/runtime/InteractionSystem.gd")
const ServiceHostScript = preload("res://src/world/runtime/WorldServiceHost.gd")
const InteriorManagerScript = preload("res://src/world/runtime/WorldInteriorManager.gd")
const PerformanceMonitorScript = preload("res://src/world/runtime/WorldPerformanceMonitor.gd")
const PromptScript = preload("res://src/ui/components/DigiInteractionPrompt.gd")
const AreaTitleScript = preload("res://src/ui/AreaTitleOverlay.gd")
const TouchJoystickScript = preload("res://src/ui/TouchJoystick.gd")
const UI = preload("res://src/ui/TacticalTheme.gd")
const DebugAccessScript = preload("res://src/debug/DebugToolkitAccess.gd")
const PLAYER_TEXTURE = preload("res://assets/characters/world/player_blond.png")
const BACKGROUND_SHADER = preload("res://shaders/hub_background.gdshader")

const REGION_ID := "central_city"
const AREA_ID := "central_city"
const TEST_HUB_SCENE := "res://scenes/world/hub.tscn"
const AUTO_SAVE_SECONDS := 5.0
const SAFE_CITY_SPAWN := Vector2(-96.0, 272.0)
const ACTOR_CLEARANCE := 7.0
const CLEARANCE_SAMPLES: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(ACTOR_CLEARANCE, 0.0),
	Vector2(-ACTOR_CLEARANCE, 0.0),
	Vector2(0.0, ACTOR_CLEARANCE),
	Vector2(0.0, -ACTOR_CLEARANCE),
]

var _area_definition: Dictionary = {}
var _player: OverworldActor = null
var _area_scene: WorldAreaScene = null
var _current_section := Vector2i.ZERO
var _interaction: InteractionSystem = null
var _services: WorldServiceHost = null
var _interior_manager: WorldInteriorManager = null
var _world_camera: Camera2D = null
var _followers: WorldPartyFollowers = null
var _performance_monitor: WorldPerformanceMonitor = null
var _prompt: DigiInteractionPrompt = null
var _area_title: AreaTitleOverlay = null
var _mobile_root: Control = null
var _touch_joystick: TouchJoystick = null
var _touch_interact: Button = null
var _touch_menu: Button = null
var _fallback_action_touch := -1
var _dialog: PanelContainer = null
var _dialog_title: Label = null
var _dialog_body: Label = null
var _movement_dirty := false
var _save_elapsed := 0.0
var _world_ready := false
var _area_load_layer: CanvasLayer = null
var _area_load_progress: ProgressBar = null
var _area_load_status: Label = null


func _ready() -> void:
	if _debug_hub_requested():
		call_deferred("_open_debug_hub")
		return
	if WorldState.current_area != AREA_ID:
		WorldState.reset_to_defaults()

	_build_background()
	_build_area_loading_overlay()

	_area_scene = CENTRAL_CITY_AREA_SCENE.instantiate() as WorldAreaScene
	if _area_scene == null:
		push_error("Central City scene must use WorldAreaScene.gd")
		return
	add_child(_area_scene)
	_area_scene.load_progress.connect(_on_area_load_progress)

	var interiors_root := Node2D.new()
	interiors_root.name = "Interiors"
	add_child(interiors_root)
	var actors_root := Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	_build_player(actors_root)
	_player.visible = false
	_player.movement_enabled = false

	var catalog := CatalogScript.new() as WorldAreaCatalog
	_area_definition = catalog.load_area(AREA_ID)
	if _area_definition.is_empty():
		push_error("Central City could not be loaded")
		_set_area_loading_error("CENTRAL CITY DATA ERROR")
		return

	print("[World] AREA_LOAD_BEGIN")
	# Explicitly yield once before area construction so Web/mobile can display a
	# real first frame instead of leaving the browser download bar stuck at 100%.
	await get_tree().process_frame
	print("[World] AREA_LOAD_VISIBLE")

	var area_loaded: bool = await _area_scene.configure(_area_definition, _player, self)
	if not area_loaded:
		push_error("Central City area construction failed")
		_set_area_loading_error("CENTRAL CITY LOAD FAILED")
		return

	_recover_invalid_spawn()
	_current_section = _area_scene.world_to_section(_player.global_position)

	_followers = FollowersScript.new() as WorldPartyFollowers
	_followers.name = "PartyFollowers"
	_followers.configure(self, _player)
	add_child(_followers)

	_interaction = InteractionScript.new() as InteractionSystem
	_interaction.name = "InteractionSystem"
	add_child(_interaction)
	_interaction.candidate_changed.connect(_on_interaction_candidate_changed)
	_interaction.interaction_requested.connect(_on_interaction_requested)
	_interaction.configure(_player)

	_services = ServiceHostScript.new() as WorldServiceHost
	_services.name = "WorldServiceHost"
	_services.configure(_player)
	_services.service_state_changed.connect(_on_service_state_changed)
	add_child(_services)

	_interior_manager = InteriorManagerScript.new() as WorldInteriorManager
	_interior_manager.name = "WorldInteriorManager"
	add_child(_interior_manager)
	_interior_manager.configure(self, _player, _world_camera, _area_scene, interiors_root)
	_interior_manager.interior_state_changed.connect(_on_interior_state_changed)

	_build_world_ui()
	_performance_monitor = PerformanceMonitorScript.new() as WorldPerformanceMonitor
	_performance_monitor.name = "WorldPerformanceMonitor"
	add_child(_performance_monitor)
	_performance_monitor.configure(_area_scene)
	MusicDirector.play_zone_1()
	_player.visible = true
	_player.movement_enabled = true
	_world_ready = true
	_finish_area_loading_overlay()
	call_deferred("_announce_area")
	var debug_interior := _debug_interior_requested()
	if not debug_interior.is_empty():
		call_deferred("_open_debug_interior", debug_interior)
	world_ready.emit()
	print("[World] AREA_LOAD_COMPLETE")
	print("[World] READY area=%s sections=%d" % [AREA_ID, _area_scene.get_section_count()])


func _process(delta: float) -> void:
	if not _world_ready or _player == null or _area_scene == null:
		return
	if _movement_dirty:
		_save_elapsed += delta
		if _save_elapsed >= AUTO_SAVE_SECONDS:
			_save_elapsed = 0.0
			_persist_world_location()
			OverworldState.save_progress()


func _input(event: InputEvent) -> void:
	if not _world_ready:
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _fallback_action_touch != -1:
			return
		if _mobile_root == null or not _mobile_root.visible:
			return
		if _touch_menu != null and _control_contains_viewport_point(_touch_menu, touch.position, 10.0):
			_fallback_action_touch = touch.index
			_on_touch_menu()
			get_viewport().set_input_as_handled()
			return
		if (
			_touch_interact != null
			and not _touch_interact.disabled
			and _control_contains_viewport_point(_touch_interact, touch.position, 10.0)
		):
			_fallback_action_touch = touch.index
			_on_touch_interact()
			get_viewport().set_input_as_handled()
			return
	elif touch.index == _fallback_action_touch:
		_fallback_action_touch = -1


func _unhandled_input(event: InputEvent) -> void:
	if not _world_ready:
		return
	if _services != null and _services.is_open():
		return
	if _dialog != null and _dialog.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_close_dialog()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("game_menu"):
		if _services != null:
			_services.open_main_menu()
			get_viewport().set_input_as_handled()
		return
	if _is_interact_event(event) and _interaction != null and _interaction.try_interact():
		get_viewport().set_input_as_handled()


func can_actor_move_to(candidate: Vector2, _actor: Node) -> bool:
	if not _world_ready:
		return false
	if _interior_manager != null and _interior_manager.is_active():
		return _interior_manager.can_move_to(candidate)
	if _area_scene == null:
		return true
	for sample: Vector2 in CLEARANCE_SAMPLES:
		if not _area_scene.is_walkable_world_position(candidate + sample):
			return false
	return true


func is_world_ready() -> bool:
	return _world_ready


func get_player() -> OverworldActor:
	return _player


func get_area_scene() -> WorldAreaScene:
	return _area_scene


func get_interior_manager() -> WorldInteriorManager:
	return _interior_manager


func request_interior_entry(payload: Dictionary) -> void:
	if _interior_manager == null or _interior_manager.is_active() or _interior_manager.is_transitioning():
		return
	_persist_world_location()
	OverworldState.save_progress()
	_interior_manager.enter_interior(payload.duplicate(true))


func request_interior_exit() -> void:
	if _interior_manager == null or not _interior_manager.is_active() or _interior_manager.is_transitioning():
		return
	_interior_manager.exit_interior()


func _build_area_loading_overlay() -> void:
	_area_load_layer = CanvasLayer.new()
	_area_load_layer.name = "AreaLoading"
	_area_load_layer.layer = 100
	add_child(_area_load_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.055, 0.065, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_area_load_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area_load_layer.add_child(center)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(360.0, 120.0)
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)

	var title := Label.new()
	title.text = "LOADING CENTRAL CITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UI.CYAN)
	UI.apply_heading_font(title)
	stack.add_child(title)

	_area_load_status = Label.new()
	_area_load_status.text = "Preparing area..."
	_area_load_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_load_status.add_theme_font_size_override("font_size", 13)
	_area_load_status.add_theme_color_override("font_color", UI.MUTED)
	UI.apply_body_font(_area_load_status)
	stack.add_child(_area_load_status)

	_area_load_progress = ProgressBar.new()
	_area_load_progress.min_value = 0.0
	_area_load_progress.max_value = 100.0
	_area_load_progress.value = 0.0
	_area_load_progress.show_percentage = true
	_area_load_progress.custom_minimum_size = Vector2(360.0, 22.0)
	stack.add_child(_area_load_progress)


func _on_area_load_progress(completed: int, total: int) -> void:
	if total <= 0:
		return
	var percent := float(completed) / float(total) * 100.0
	if _area_load_progress != null:
		_area_load_progress.value = percent
	if _area_load_status != null:
		_area_load_status.text = "Building city · %d / %d" % [completed, total]
	if completed == 1 or completed == total or completed % 5 == 0:
		print("[World] AREA_LOAD_PROGRESS %d/%d" % [completed, total])


func _set_area_loading_error(message: String) -> void:
	if _area_load_status != null:
		_area_load_status.text = message
		_area_load_status.add_theme_color_override("font_color", UI.RED)


func _finish_area_loading_overlay() -> void:
	if _area_load_progress != null:
		_area_load_progress.value = 100.0
	if _area_load_status != null:
		_area_load_status.text = "Ready"
	if _area_load_layer != null:
		_area_load_layer.queue_free()
	_area_load_layer = null
	_area_load_progress = null
	_area_load_status = null


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldBackdrop"
	layer.layer = -50
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	backdrop.material = material
	backdrop.color = Color(0.06, 0.12, 0.13, 1.0)
	layer.add_child(backdrop)


func _build_player(parent: Node2D) -> void:
	_player = ActorScript.new() as OverworldActor
	_player.name = "Player"
	_player.configure(PLAYER_TEXTURE, true, self, WorldState.player_facing)
	parent.add_child(_player)
	_player.global_position = WorldState.player_position
	_player.world_position_changed.connect(_on_player_moved)
	_world_camera = Camera2D.new()
	_world_camera.name = "WorldCamera"
	_world_camera.position_smoothing_enabled = true
	_world_camera.position_smoothing_speed = 7.5
	_world_camera.zoom = Vector2.ONE * 1.18
	_player.add_child(_world_camera)


func _build_world_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldUI"
	layer.layer = 60
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_area_title = AreaTitleScript.new() as AreaTitleOverlay
	root.add_child(_area_title)

	_prompt = PromptScript.new() as DigiInteractionPrompt
	_prompt.visible = false
	root.add_child(_prompt)

	_build_dialog(root)
	_build_mobile_controls(root)
	get_viewport().size_changed.connect(_layout_ui)
	call_deferred("_layout_ui")


func _build_dialog(root: Control) -> void:
	_dialog = PanelContainer.new()
	_dialog.name = "WorldDialogue"
	_dialog.visible = false
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	root.add_child(_dialog)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_dialog.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	_dialog_title = Label.new()
	_dialog_title.add_theme_font_size_override("font_size", 14)
	_dialog_title.add_theme_color_override("font_color", UI.CYAN)
	UI.apply_heading_font(_dialog_title)
	stack.add_child(_dialog_title)
	_dialog_body = Label.new()
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.add_theme_font_size_override("font_size", 17)
	_dialog_body.add_theme_color_override("font_color", UI.TEXT)
	UI.apply_body_font(_dialog_body)
	stack.add_child(_dialog_body)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(140, 46)
	close_button.pressed.connect(_close_dialog)
	stack.add_child(close_button)


func _build_mobile_controls(root: Control) -> void:
	_mobile_root = Control.new()
	_mobile_root.name = "MobileControls"
	_mobile_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mobile_root)

	_touch_joystick = TouchJoystickScript.new() as TouchJoystick
	_touch_joystick.name = "MovementJoystick"
	_touch_joystick.direction_changed.connect(_on_touch_direction)
	_mobile_root.add_child(_touch_joystick)

	_touch_menu = Button.new()
	_touch_menu.name = "Menu"
	_touch_menu.text = "MENU"
	_touch_menu.custom_minimum_size = Vector2(118.0, 58.0)
	_touch_menu.focus_mode = Control.FOCUS_NONE
	_touch_menu.button_down.connect(_on_touch_menu)
	_style_touch_button(_touch_menu, UI.BLUE)
	_mobile_root.add_child(_touch_menu)

	_touch_interact = Button.new()
	_touch_interact.name = "Interact"
	_touch_interact.text = "INTERACT"
	_touch_interact.custom_minimum_size = Vector2(118.0, 58.0)
	_touch_interact.focus_mode = Control.FOCUS_NONE
	# button_down responds on contact instead of waiting for a synthesized click.
	# _input above is an explicit ScreenTouch fallback for mobile Web/APK devices
	# where GUI mouse emulation can be inconsistent.
	_touch_interact.button_down.connect(_on_touch_interact)
	_style_touch_button(_touch_interact, UI.CYAN)
	_mobile_root.add_child(_touch_interact)


func _layout_ui() -> void:
	if _prompt == null:
		return
	var viewport_obj := get_viewport()
	var viewport_size := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 760.0)
	var touch_layout := UI.is_touch_runtime() or compact
	var landscape := physical.x > physical.y
	var prompt_width := minf(270.0, viewport_size.x - 28.0)
	_prompt.position = Vector2(
		(viewport_size.x - prompt_width) * 0.5,
		viewport_size.y - (92.0 if not touch_layout else 190.0)
	)
	_prompt.size = Vector2(prompt_width, 54.0)

	if _dialog != null:
		var dialog_width := minf(620.0, viewport_size.x - 28.0)
		var dialog_height := 220.0
		_dialog.position = Vector2(
			(viewport_size.x - dialog_width) * 0.5,
			viewport_size.y - dialog_height - 24.0
		)
		_dialog.size = Vector2(dialog_width, dialog_height)

	if _mobile_root != null:
		var blocked := (_services != null and _services.is_open()) or (_dialog != null and _dialog.visible)
		_mobile_root.visible = touch_layout and not blocked
		_mobile_root.scale = Vector2.ONE * ui_scale

		var edge := 18.0 if landscape else 24.0
		var bottom := 18.0 if landscape else 30.0
		var joystick_side := 146.0 if landscape else clampf(physical.x * 0.42, 158.0, 174.0)
		_mobile_root.position = Vector2(
			edge * ui_scale,
			(physical.y - joystick_side - bottom) * ui_scale
		)
		_mobile_root.size = Vector2(maxf(1.0, physical.x - edge * 2.0), joystick_side)

		if _touch_joystick != null:
			_touch_joystick.position = Vector2.ZERO
			_touch_joystick.size = Vector2(joystick_side, joystick_side)

		var action_width := 112.0 if landscape else 118.0
		var action_height := 54.0 if landscape else 60.0
		var action_gap := 10.0
		var action_x := maxf(joystick_side + 24.0, _mobile_root.size.x - action_width)
		var action_y := maxf(
			0.0,
			(joystick_side - (action_height * 2.0 + action_gap)) * 0.5
		)
		if _touch_menu != null:
			_touch_menu.position = Vector2(action_x, action_y)
			_touch_menu.size = Vector2(action_width, action_height)
		if _touch_interact != null:
			_touch_interact.position = Vector2(action_x, action_y + action_height + action_gap)
			_touch_interact.size = Vector2(action_width, action_height)

		print(
			"[World] TOUCH_UI visible=%s touch_runtime=%s compact=%s physical=%s"
			% [str(_mobile_root.visible), str(UI.is_touch_runtime()), str(compact), str(physical)]
		)


func _on_player_moved(world_position: Vector2) -> void:
	if not _world_ready:
		return
	if _interior_manager != null and (_interior_manager.is_active() or _interior_manager.is_transitioning()):
		return
	_movement_dirty = true
	if _area_scene != null:
		var next_section := _area_scene.world_to_section(world_position)
		WorldState.capture_location(
			REGION_ID,
			AREA_ID,
			next_section,
			world_position,
			_player.facing_direction
		)
		if next_section != _current_section:
			_current_section = next_section
			print("[World] SECTION %s" % str(_current_section))


func _on_interaction_candidate_changed(action_text: String) -> void:
	if _prompt == null:
		return
	var blocked := (_services != null and _services.is_open()) or (_dialog != null and _dialog.visible)
	var touch_layout := UI.is_touch_runtime() or UI.is_compact(get_viewport(), 760.0)
	_prompt.visible = not action_text.is_empty() and not blocked and not touch_layout
	if not action_text.is_empty():
		_prompt.set_action(action_text)
	if _touch_interact != null:
		_touch_interact.disabled = action_text.is_empty() or blocked
		_touch_interact.text = action_text if not action_text.is_empty() else "INTERACT"


func _on_interaction_requested(action_id: String, payload: Dictionary) -> void:
	match action_id:
		"enter_interior":
			request_interior_entry(payload)
		"exit_interior":
			request_interior_exit()
		"digilab", "training", "hospital":
			if _services != null:
				_services.open_service(action_id)
		"guide":
			_open_dialog(
				"CITY GUIDE",
				"Welcome to Central City. DigiLab is west of the plaza, the Hospital is east, Training is north and the Data Market is south. The whole city is one continuous area; larger regions use separate area scenes."
			)
		"shop":
			_open_dialog(
				"DATA MARKET",
				"This storefront already uses the seamless interior contract. Its commerce inventory will plug into this interaction when the item and equipment catalogue is authored."
			)
		"archive":
			_open_dialog(
				"DIGITAL ARCHIVE",
				"The Archive is prepared as a full interior service space for research, records and future encyclopedia systems."
			)
		"interior_greeting":
			_open_dialog(
				String(payload.get("title", "CITY STAFF")),
				String(payload.get("body", "Welcome to Central City."))
			)
		_:
			_open_dialog(String(payload.get("title", "CENTRAL CITY")), "This interaction is connected to the new world runtime.")


func _on_interior_state_changed(active: bool, title: String) -> void:
	_movement_dirty = false
	_save_elapsed = 0.0
	if active:
		if _area_title != null:
			_area_title.present(title, "Interior · seamless focus", 1.15)
	else:
		if _area_scene != null and _player != null:
			_current_section = _area_scene.world_to_section(_player.global_position)
			WorldState.capture_location(
				REGION_ID,
				AREA_ID,
				_current_section,
				_player.global_position,
				_player.facing_direction
			)
		OverworldState.save_progress()
	_layout_ui()


func _on_service_state_changed(open: bool, _service_id: String) -> void:
	if _touch_joystick != null and open:
		_touch_joystick.force_release()
	if open:
		if _prompt != null:
			_prompt.visible = false
	else:
		_on_interaction_candidate_changed(_interaction.current_action_text() if _interaction != null else "")
	_layout_ui()


func _open_dialog(title: String, body: String) -> void:
	if _dialog == null or _player == null:
		return
	_dialog_title.text = title
	_dialog_body.text = body
	_dialog.visible = true
	_player.movement_enabled = false
	_player.velocity = Vector2.ZERO
	if _prompt != null:
		_prompt.visible = false
	if _touch_joystick != null:
		_touch_joystick.force_release()
	_layout_ui()
	UiSfxDirector.play_open()


func _close_dialog() -> void:
	if _dialog == null or not _dialog.visible or _player == null:
		return
	_dialog.visible = false
	_player.movement_enabled = true
	UiSfxDirector.play_back()
	_on_interaction_candidate_changed(_interaction.current_action_text() if _interaction != null else "")
	_layout_ui()


func _on_touch_direction(direction: Vector2) -> void:
	if _player == null:
		return
	_player.set_touch_direction(direction)
	if direction.length_squared() > 0.01:
		print("[World] TOUCH_MOVE direction=%s" % str(direction))


func _on_touch_menu() -> void:
	if _services == null or _services.is_open() or (_dialog != null and _dialog.visible):
		return
	print("[World] TOUCH_MENU")
	_services.open_main_menu()


func _on_touch_interact() -> void:
	if _interaction == null or (_services != null and _services.is_open()):
		return
	if _dialog != null and _dialog.visible:
		return
	if _interaction.try_interact():
		print("[World] TOUCH_INTERACT")


func _style_touch_button(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_pressed_color", UI.TEXT)
	button.add_theme_color_override("font_disabled_color", UI.DISABLED)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(accent, "disabled"))
	UI.apply_heading_font(button)


func _control_contains_viewport_point(control: Control, viewport_pos: Vector2, padding: float = 0.0) -> bool:
	if control == null or not control.visible:
		return false
	var local_pos := control.get_global_transform_with_canvas().affine_inverse() * viewport_pos
	return Rect2(
		Vector2(-padding, -padding),
		control.size + Vector2.ONE * padding * 2.0
	).has_point(local_pos)


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and (key.keycode == KEY_E or key.physical_keycode == KEY_E)
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index == JOY_BUTTON_A
	return false


func present_area_banner(title: String, subtitle: String = "", duration: float = 1.7) -> void:
	if _area_title != null:
		_area_title.present(title, subtitle, duration)


func _announce_area() -> void:
	# Area banners are explicit major-location events. Authoring sections are
	# invisible implementation metadata and never trigger this overlay.
	present_area_banner(
		String(_area_definition.get("display_name", "Central City")),
		String(_area_definition.get("subtitle", "Recovery District")),
		1.7
	)


func _persist_world_location() -> void:
	if _player == null or _area_scene == null:
		return
	if _interior_manager != null and (_interior_manager.is_active() or _interior_manager.is_transitioning()):
		return
	WorldState.capture_location(
		REGION_ID,
		AREA_ID,
		_current_section,
		_player.global_position,
		_player.facing_direction
	)
	_movement_dirty = false


func _recover_invalid_spawn() -> void:
	if _area_scene == null or _player == null:
		return
	if _area_scene.is_walkable_world_position(_player.global_position):
		return
	_player.global_position = SAFE_CITY_SPAWN
	_player.velocity = Vector2.ZERO
	WorldState.capture_location(REGION_ID, AREA_ID, Vector2i.ZERO, SAFE_CITY_SPAWN, _player.facing_direction)
	OverworldState.save_progress()
	print("[World] RECOVERED_INVALID_SPAWN position=%s" % str(SAFE_CITY_SPAWN))


func _debug_interior_requested() -> String:
	if not DebugAccessScript.is_available():
		return ""
	for arg in OS.get_cmdline_user_args():
		var normalized := String(arg).strip_edges().to_lower()
		if normalized.begins_with("--interior-test="):
			return normalized.trim_prefix("--interior-test=")
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('interior_test')", true)
		var value := String(raw).strip_edges().to_lower()
		if value in ["digilab", "hospital", "training", "shop", "archive"]:
			return value
	return ""


func _open_debug_interior(service_id: String) -> void:
	if _interior_manager == null or _player == null:
		return
	var titles := {
		"digilab": "DIGILAB",
		"hospital": "DIGI HOSPITAL",
		"training": "TRAINING CENTER",
		"shop": "DATA MARKET",
		"archive": "DIGITAL ARCHIVE",
	}
	var accents := {
		"digilab": Color(0.28, 0.88, 1.0, 1.0),
		"hospital": Color(0.66, 0.96, 1.0, 1.0),
		"training": Color(0.56, 0.95, 0.43, 1.0),
		"shop": Color(1.0, 0.78, 0.28, 1.0),
		"archive": Color(0.72, 0.52, 1.0, 1.0),
	}
	if not titles.has(service_id):
		return
	var accent: Color = accents[service_id]
	request_interior_entry({
		"interior_id": "debug_%s" % service_id,
		"service": service_id,
		"title": String(titles[service_id]),
		"accent": [accent.r, accent.g, accent.b, accent.a],
		"return_position": [_player.global_position.x, _player.global_position.y],
	})


func _debug_hub_requested() -> bool:
	if not DebugAccessScript.is_available():
		return false
	for arg in OS.get_cmdline_user_args():
		if String(arg).strip_edges().to_lower() == "--test-hub":
			return true
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('test_hub')", true)
		return String(raw).to_lower() in ["1", "true", "yes", "on"]
	return false


func _open_debug_hub() -> void:
	print("[World] DEBUG_HUB")
	get_tree().change_scene_to_file(TEST_HUB_SCENE)
