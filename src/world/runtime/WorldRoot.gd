extends Node2D
class_name WorldRoot

const CatalogScript = preload("res://src/world/runtime/WorldAreaCatalog.gd")
const ActorScript = preload("res://src/world/runtime/OverworldActor.gd")
const FollowersScript = preload("res://src/world/runtime/WorldPartyFollowers.gd")
const StreamerScript = preload("res://src/world/runtime/AreaStreamer.gd")
const InteractionScript = preload("res://src/world/runtime/InteractionSystem.gd")
const ServiceHostScript = preload("res://src/world/runtime/WorldServiceHost.gd")
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

var _area_definition: Dictionary = {}
var _player: OverworldActor = null
var _streamer: AreaStreamer = null
var _interaction: InteractionSystem = null
var _services: WorldServiceHost = null
var _prompt: DigiInteractionPrompt = null
var _area_title: AreaTitleOverlay = null
var _mobile_root: Control = null
var _touch_joystick: TouchJoystick = null
var _touch_interact: Button = null
var _dialog: PanelContainer = null
var _dialog_title: Label = null
var _dialog_body: Label = null
var _movement_dirty := false
var _save_elapsed := 0.0


func _ready() -> void:
	if _debug_hub_requested():
		call_deferred("_open_debug_hub")
		return
	if WorldState.current_area != AREA_ID:
		WorldState.reset_to_defaults()

	_build_background()
	var chunks_root := Node2D.new()
	chunks_root.name = "StreamedChunks"
	add_child(chunks_root)
	var actors_root := Node2D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	_build_player(actors_root)

	var catalog := CatalogScript.new() as WorldAreaCatalog
	_area_definition = catalog.load_area(AREA_ID)
	if _area_definition.is_empty():
		push_error("Central City could not be loaded")
		return

	_streamer = StreamerScript.new() as AreaStreamer
	_streamer.name = "AreaStreamer"
	_streamer.current_chunk_changed.connect(_on_chunk_changed)
	add_child(_streamer)
	_streamer.configure(_area_definition, _player, chunks_root, self)

	var followers := FollowersScript.new() as WorldPartyFollowers
	followers.name = "PartyFollowers"
	followers.configure(self, _player)
	add_child(followers)

	_interaction = InteractionScript.new() as InteractionSystem
	_interaction.name = "InteractionSystem"
	_interaction.configure(_player)
	_interaction.candidate_changed.connect(_on_interaction_candidate_changed)
	_interaction.interaction_requested.connect(_on_interaction_requested)
	add_child(_interaction)

	_services = ServiceHostScript.new() as WorldServiceHost
	_services.name = "WorldServiceHost"
	_services.configure(_player)
	_services.service_state_changed.connect(_on_service_state_changed)
	add_child(_services)

	_build_world_ui()
	MusicDirector.play_zone_1()
	call_deferred("_announce_area")
	print("[World] READY area=%s chunk=%s" % [AREA_ID, str(_streamer.get_current_chunk())])


func _process(delta: float) -> void:
	if _player == null or _streamer == null:
		return
	if _movement_dirty:
		_save_elapsed += delta
		if _save_elapsed >= AUTO_SAVE_SECONDS:
			_save_elapsed = 0.0
			_persist_world_location()
			OverworldState.save_progress()


func _unhandled_input(event: InputEvent) -> void:
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
	return _streamer == null or _streamer.is_walkable_world_position(candidate)


func get_player() -> OverworldActor:
	return _player


func get_streamer() -> AreaStreamer:
	return _streamer


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
	var camera := Camera2D.new()
	camera.name = "WorldCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.5
	camera.zoom = Vector2.ONE * 1.18
	_player.add_child(camera)


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
	_touch_joystick.direction_changed.connect(_on_touch_direction)
	_mobile_root.add_child(_touch_joystick)
	_touch_interact = Button.new()
	_touch_interact.text = "INTERACT"
	_touch_interact.custom_minimum_size = Vector2(118, 58)
	_touch_interact.focus_mode = Control.FOCUS_NONE
	_touch_interact.pressed.connect(_on_touch_interact)
	_mobile_root.add_child(_touch_interact)


func _layout_ui() -> void:
	if _prompt == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := UI.is_compact(get_viewport(), 760.0)
	var prompt_width := minf(270.0, viewport_size.x - 28.0)
	_prompt.position = Vector2(
		(viewport_size.x - prompt_width) * 0.5,
		viewport_size.y - (92.0 if not compact else 190.0)
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
		_mobile_root.visible = compact and (_services == null or not _services.is_open()) and (_dialog == null or not _dialog.visible)
		_mobile_root.position = Vector2.ZERO
		_mobile_root.size = viewport_size
		if _touch_joystick != null:
			_touch_joystick.position = Vector2(18.0, viewport_size.y - 178.0)
			_touch_joystick.size = Vector2(156.0, 156.0)
		if _touch_interact != null:
			_touch_interact.position = Vector2(viewport_size.x - 142.0, viewport_size.y - 100.0)
			_touch_interact.size = Vector2(118.0, 58.0)


func _on_player_moved(world_position: Vector2) -> void:
	_movement_dirty = true
	if _streamer != null:
		WorldState.capture_location(
			REGION_ID,
			AREA_ID,
			_streamer.world_to_chunk(world_position),
			world_position,
			_player.facing_direction
		)


func _on_chunk_changed(chunk: Vector2i) -> void:
	if _player == null:
		return
	WorldState.capture_location(REGION_ID, AREA_ID, chunk, _player.global_position, _player.facing_direction)
	_movement_dirty = false
	_save_elapsed = 0.0
	OverworldState.save_progress()
	var chunk_definition := _chunk_definition(chunk)
	if not chunk_definition.is_empty() and _area_title != null:
		_area_title.present(
			String(chunk_definition.get("title", "Central City")),
			String(chunk_definition.get("subtitle", "")),
			1.15
		)
	print("[World] CHUNK %s" % str(chunk))


func _on_interaction_candidate_changed(action_text: String) -> void:
	if _prompt == null:
		return
	var blocked := (_services != null and _services.is_open()) or (_dialog != null and _dialog.visible)
	_prompt.visible = not action_text.is_empty() and not blocked and not UI.is_compact(get_viewport(), 760.0)
	if not action_text.is_empty():
		_prompt.set_action(action_text)
	if _touch_interact != null:
		_touch_interact.disabled = action_text.is_empty() or blocked
		_touch_interact.text = action_text if not action_text.is_empty() else "INTERACT"


func _on_interaction_requested(action_id: String, payload: Dictionary) -> void:
	match action_id:
		"digilab", "training", "hospital":
			if _services != null:
				_services.open_service(action_id)
		"guide":
			_open_dialog(
				"CITY GUIDE",
				"Welcome to Central City. DigiLab is west of the plaza, the Hospital is east, Training is north and the Data Market is south. Keep walking: districts stream continuously without scene loads."
			)
		"shop":
			_open_dialog(
				"DATA MARKET",
				"This storefront already uses the seamless interior contract. Its commerce inventory will plug into this interaction when the item and equipment catalogue is authored."
			)
		"archive":
			_open_dialog(
				"DIGITAL ARCHIVE",
				"The Archive is prepared as a streamed service interior. Future research and encyclopedia systems can attach here without adding a new world controller."
			)
		_:
			_open_dialog(String(payload.get("title", "CENTRAL CITY")), "This interaction is connected to the new world runtime.")


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


func _on_touch_interact() -> void:
	if _interaction != null and not (_services != null and _services.is_open()):
		_interaction.try_interact()


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


func _announce_area() -> void:
	if _area_title != null:
		_area_title.present(
			String(_area_definition.get("display_name", "Central City")),
			String(_area_definition.get("subtitle", "Recovery District")),
			1.7
		)


func _persist_world_location() -> void:
	if _player == null or _streamer == null:
		return
	WorldState.capture_location(
		REGION_ID,
		AREA_ID,
		_streamer.get_current_chunk(),
		_player.global_position,
		_player.facing_direction
	)
	_movement_dirty = false


func _chunk_definition(coord: Vector2i) -> Dictionary:
	var raw_chunks = _area_definition.get("chunks", [])
	if not raw_chunks is Array:
		return {}
	for raw in raw_chunks:
		if not raw is Dictionary:
			continue
		var entry := raw as Dictionary
		var raw_coord = entry.get("coord", [])
		if raw_coord is Array and raw_coord.size() >= 2:
			if int(raw_coord[0]) == coord.x and int(raw_coord[1]) == coord.y:
				return entry
	return {}


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
