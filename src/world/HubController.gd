extends Node2D
class_name HubController

const HubActorScript = preload("res://src/world/HubActor.gd")
const HubPortalScript = preload("res://src/world/HubPortal.gd")
const UI = preload("res://src/ui/TacticalTheme.gd")
const BACKGROUND_SHADER = preload("res://shaders/hub_background.gdshader")
const PLAYER_TEXTURE = preload("res://assets/characters/world/player_blond.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")
const GRASS_TEXTURE = preload("res://assets/world/hawkbirdtree/grass.png")
const PATH_TEXTURE = preload("res://assets/world/hawkbirdtree/path.png")
const FLOWER_RED_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_red.png")
const FLOWER_PURPLE_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_purple.png")
const FLOWER_YELLOW_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_yellow.png")
const WATER_TEXTURE = preload("res://assets/world/hawkbirdtree/water.png")
const TREE_TEXTURE = preload("res://assets/world/hawkbirdtree/tree.png")
const ROCK_TEXTURE = preload("res://assets/world/hawkbirdtree/rock.png")
const CRATE_TEXTURE = preload("res://assets/world/hawkbirdtree/crate.png")

const BATTLE_SCENE_PATH := "res://scenes/main.tscn"
const MAP_RADIUS := 6.15
const INTERACTION_DISTANCE := 94.0
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0

var _player: HubActor = null
var _operator: HubActor = null
var _water_tiles: Array[Sprite2D] = []
var _trees: Array[Sprite2D] = []
var _blockers: Array[Dictionary] = []
var _ui_root: Control = null
var _location_panel: PanelContainer = null
var _objective_label: Label = null
var _interaction_prompt: PanelContainer = null
var _prompt_label: Label = null
var _dialog_panel: PanelContainer = null
var _start_battle_button: Button = null
var _mobile_controls: Control = null
var _mobile_talk_button: Button = null
var _touch_flags := {"left": false, "right": false, "up": false, "down": false}
var _transition_rect: ColorRect = null
var _elapsed := 0.0
var _dialog_open := false
var _transitioning := false


func _ready() -> void:
	_build_background()
	_build_world()
	_build_actors()
	_build_ambient_particles()
	_build_ui()
	get_viewport().size_changed.connect(_layout_ui)
	call_deferred("_layout_ui")
	call_deferred("_refresh_interaction")
	print("[Hub] READY")


func _process(delta: float) -> void:
	_elapsed += delta
	_animate_environment()
	_refresh_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if _dialog_open:
		if event.is_action_pressed("ui_cancel"):
			_close_dialog()
			get_viewport().set_input_as_handled()
		return
	if _is_interact_event(event) and _is_operator_nearby():
		_open_dialog()
		get_viewport().set_input_as_handled()


func can_actor_move_to(candidate: Vector2, actor: Node) -> bool:
	if actor != _player:
		return true
	var grid := _world_to_grid(candidate)
	if absf(grid.x) > MAP_RADIUS or absf(grid.y) > MAP_RADIUS:
		return false
	for blocker: Dictionary in _blockers:
		var center := Vector2(blocker.get("position", Vector2.ZERO))
		var radius := float(blocker.get("radius", 20.0))
		if candidate.distance_squared_to(center) < radius * radius:
			return false
	return true


func open_test_battle_dialog() -> void:
	if _is_operator_nearby():
		_open_dialog()


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BackgroundLayer"
	layer.layer = -20
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.name = "DigitalBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	backdrop.material = material
	layer.add_child(backdrop)


func _build_world() -> void:
	var water_layer := Node2D.new()
	water_layer.name = "Water"
	add_child(water_layer)
	for grid_x in range(-9, 10):
		for grid_y in range(-9, 10):
			var tile := Sprite2D.new()
			tile.texture = WATER_TEXTURE
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.position = _grid_to_world(Vector2(grid_x, grid_y))
			tile.z_index = -500 + int(round(tile.position.y))
			tile.set_meta("base_position", tile.position)
			tile.set_meta("phase", fmod(float(grid_x * 17 + grid_y * 29), 13.0))
			water_layer.add_child(tile)
			_water_tiles.append(tile)

	var ground_layer := Node2D.new()
	ground_layer.name = "Ground"
	add_child(ground_layer)
	for grid_x in range(-6, 7):
		for grid_y in range(-6, 7):
			var tile := Sprite2D.new()
			tile.texture = _ground_texture_for(Vector2i(grid_x, grid_y))
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.position = _grid_to_world(Vector2(grid_x, grid_y)) + Vector2(0.0, 16.0)
			tile.z_index = -120 + int(round(tile.position.y))
			ground_layer.add_child(tile)

	_build_props()


func _ground_texture_for(grid: Vector2i) -> Texture2D:
	if grid.x == grid.y and grid.x >= -4 and grid.x <= 5:
		return PATH_TEXTURE
	if absi(grid.x) <= 1 and absi(grid.y) <= 1:
		return PATH_TEXTURE
	if absi(grid.x) >= 5 or absi(grid.y) >= 5:
		var variation := posmod(grid.x * 11 + grid.y * 7, 17)
		if variation == 0:
			return FLOWER_RED_TEXTURE
		if variation == 4:
			return FLOWER_PURPLE_TEXTURE
		if variation == 9:
			return FLOWER_YELLOW_TEXTURE
	return GRASS_TEXTURE


func _build_props() -> void:
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	var tree_grids: Array[Vector2i] = [
		Vector2i(-5, -5), Vector2i(0, -5), Vector2i(5, -5),
		Vector2i(-5, 0), Vector2i(5, 0), Vector2i(-5, 5), Vector2i(5, 5),
	]
	for index in range(tree_grids.size()):
		var foot_position := _grid_to_world(Vector2(tree_grids[index]))
		var tree := Sprite2D.new()
		tree.name = "Tree%02d" % index
		tree.texture = TREE_TEXTURE
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.position = foot_position + Vector2(0.0, -47.0)
		tree.z_index = 1000 + int(round(foot_position.y))
		tree.set_meta("base_rotation", -0.012 if index % 2 == 0 else 0.012)
		tree.set_meta("phase", float(index) * 0.8)
		props.add_child(tree)
		_trees.append(tree)
		_blockers.append({"position": foot_position, "radius": 31.0})

	_add_prop(props, ROCK_TEXTURE, Vector2i(-4, 2), Vector2(0.0, -15.0), 20.0, "Rock")
	_add_prop(props, ROCK_TEXTURE, Vector2i(3, -4), Vector2(0.0, -15.0), 20.0, "Rock")
	_add_prop(props, CRATE_TEXTURE, Vector2i(4, 3), Vector2(0.0, -31.0), 27.0, "SupplyCrate")
	_add_prop(props, CRATE_TEXTURE, Vector2i(3, 4), Vector2(0.0, -31.0), 27.0, "SupplyCrate")


func _add_prop(parent: Node2D, texture: Texture2D, grid: Vector2i, offset: Vector2, radius: float, label: String) -> void:
	var foot_position := _grid_to_world(Vector2(grid))
	var sprite := Sprite2D.new()
	sprite.name = "%s_%d_%d" % [label, grid.x, grid.y]
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = foot_position + offset
	sprite.z_index = 1000 + int(round(foot_position.y))
	parent.add_child(sprite)
	_blockers.append({"position": foot_position, "radius": radius})


func _build_actors() -> void:
	var actors := Node2D.new()
	actors.name = "Actors"
	add_child(actors)

	var portal := HubPortalScript.new()
	portal.name = "TestBattlePortal"
	portal.position = _grid_to_world(Vector2(-1, -1))
	portal.z_index = 930 + int(round(portal.position.y))
	actors.add_child(portal)

	_operator = HubActorScript.new()
	_operator.name = "BattleOperator"
	_operator.configure(NPC_TEXTURE, false, self, "down_left")
	_operator.position = _grid_to_world(Vector2(1, 1))
	actors.add_child(_operator)
	_blockers.append({"position": _operator.position, "radius": 30.0})
	_add_operator_label(_operator)

	_player = HubActorScript.new()
	_player.name = "Player"
	_player.configure(PLAYER_TEXTURE, true, self, "up_right")
	_player.position = _grid_to_world(Vector2(3, 3))
	_player.world_position_changed.connect(_on_player_moved)
	actors.add_child(_player)

	var camera := Camera2D.new()
	camera.name = "HubCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.5
	_player.add_child(camera)
	_update_camera_zoom(camera)


func _add_operator_label(actor: Node2D) -> void:
	var label := Label.new()
	label.name = "RoleLabel"
	label.position = Vector2(-78.0, -84.0)
	label.size = Vector2(156.0, 24.0)
	label.text = "BATTLE OPERATOR"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UI.GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.add_child(label)


func _build_ambient_particles() -> void:
	var motes := CPUParticles2D.new()
	motes.name = "DataMotes"
	motes.amount = 34
	motes.lifetime = 5.0
	motes.randomness = 0.85
	motes.position = Vector2(0.0, 40.0)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(430.0, 210.0)
	motes.direction = Vector2(0.0, -1.0)
	motes.spread = 18.0
	motes.gravity = Vector2(0.0, -7.0)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 12.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.color = Color(0.47, 0.94, 0.96, 0.44)
	motes.z_index = 1800
	add_child(motes)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HubUI"
	layer.layer = 50
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.name = "Root"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)

	_location_panel = PanelContainer.new()
	_location_panel.name = "LocationPanel"
	_location_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_location_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.84, 0.30, 10, 3))
	_ui_root.add_child(_location_panel)
	var location_margin := _margin_container(16, 14, 16, 14)
	_location_panel.add_child(location_margin)
	var location_stack := VBoxContainer.new()
	location_stack.add_theme_constant_override("separation", 2)
	location_margin.add_child(location_stack)
	var sector := _label("RECOVERY SECTOR 01", 12, UI.CYAN)
	var title := _label("TERMINAL COMMONS", 24, UI.TEXT)
	var subtitle := _label("Prototype hub · systems online", 13, UI.MUTED)
	_objective_label = _label("OBJECTIVE  ·  Talk to the Battle Operator", 14, UI.GOLD)
	for child: Label in [sector, title, subtitle, _objective_label]:
		location_stack.add_child(child)

	_interaction_prompt = PanelContainer.new()
	_interaction_prompt.name = "InteractionPrompt"
	_interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_prompt.add_theme_stylebox_override("panel", UI.panel_strong(UI.GOLD, 10))
	_ui_root.add_child(_interaction_prompt)
	_prompt_label = _label("E / ENTER   TALK", 16, UI.TEXT)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt.add_child(_prompt_label)

	_build_dialog()
	_build_mobile_controls()

	_transition_rect = ColorRect.new()
	_transition_rect.name = "Transition"
	_transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_rect.color = Color(0.005, 0.02, 0.03, 0.0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.z_index = 100
	_ui_root.add_child(_transition_rect)


func _build_dialog() -> void:
	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "BattleDialog"
	_dialog_panel.visible = false
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	_ui_root.add_child(_dialog_panel)
	var margin := _margin_container(22, 18, 22, 18)
	_dialog_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("BATTLE OPERATOR", 13, UI.CYAN))
	var body := _label("Combat systems are online. Start a test battle with the current Digimon squad?", 19, UI.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 58.0
	stack.add_child(body)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	var cancel := _dialog_button("NOT NOW", UI.MUTED)
	cancel.pressed.connect(_close_dialog)
	actions.add_child(cancel)
	_start_battle_button = _dialog_button("START TEST BATTLE", UI.GOLD)
	_start_battle_button.pressed.connect(_start_test_battle)
	actions.add_child(_start_battle_button)


func _build_mobile_controls() -> void:
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.z_index = 20
	_ui_root.add_child(_mobile_controls)
	_add_touch_button("Up", "▲", Rect2(58.0, 0.0, 58.0, 58.0), "up")
	_add_touch_button("Left", "◀", Rect2(0.0, 58.0, 58.0, 58.0), "left")
	_add_touch_button("Down", "▼", Rect2(58.0, 116.0, 58.0, 58.0), "down")
	_add_touch_button("Right", "▶", Rect2(116.0, 58.0, 58.0, 58.0), "right")
	_mobile_talk_button = _dialog_button("TALK", UI.GOLD)
	_mobile_talk_button.name = "Talk"
	_mobile_talk_button.custom_minimum_size = Vector2(104.0, 64.0)
	_mobile_talk_button.position = Vector2(220.0, 92.0)
	_mobile_talk_button.size = Vector2(104.0, 64.0)
	_mobile_talk_button.button_down.connect(_on_mobile_interact)
	_mobile_controls.add_child(_mobile_talk_button)


func _add_touch_button(node_name: String, text_value: String, rect: Rect2, direction: String) -> void:
	var button := _dialog_button(text_value, UI.CYAN)
	button.name = node_name
	button.custom_minimum_size = rect.size
	button.position = rect.position
	button.size = rect.size
	button.button_down.connect(Callable(self, "_set_touch_flag").bind(direction, true))
	button.button_up.connect(Callable(self, "_set_touch_flag").bind(direction, false))
	_mobile_controls.add_child(button)


func _dialog_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(accent, 8))
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.apply_body_font(label)
	return label


func _margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _layout_ui() -> void:
	if _ui_root == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 760.0)
	var portrait_mobile := compact and physical.y > physical.x

	_location_panel.scale = Vector2.ONE * ui_scale
	_interaction_prompt.scale = Vector2.ONE * ui_scale
	_dialog_panel.scale = Vector2.ONE * ui_scale
	_mobile_controls.scale = Vector2.ONE * ui_scale

	var location_width := minf(360.0, physical.x - 28.0)
	_location_panel.position = Vector2(14.0 if compact else 18.0, 14.0 if compact else 18.0) * ui_scale
	_location_panel.size = Vector2(location_width, 118.0 if compact else 132.0)
	var prompt_width := minf(250.0, physical.x - 28.0)
	_interaction_prompt.position = Vector2(
		(physical.x - prompt_width) * 0.5 * ui_scale,
		(physical.y - (212.0 if compact else 84.0)) * ui_scale
	)
	_interaction_prompt.size = Vector2(prompt_width, 50.0)
	var dialog_width := minf(660.0, physical.x - 28.0)
	var dialog_height := 236.0 if portrait_mobile else 206.0
	_dialog_panel.position = Vector2(
		(physical.x - dialog_width) * 0.5 * ui_scale,
		(physical.y - dialog_height - (14.0 if compact else 22.0)) * ui_scale
	)
	_dialog_panel.size = Vector2(dialog_width, dialog_height)
	_mobile_controls.visible = compact and not _dialog_open and not _transitioning
	_mobile_controls.position = Vector2(18.0 * ui_scale, (physical.y - 192.0) * ui_scale)
	_mobile_controls.size = Vector2(maxf(324.0, physical.x - 36.0), 174.0)
	if _mobile_talk_button != null:
		_mobile_talk_button.position.x = maxf(190.0, physical.x - 140.0)
	if _player != null:
		var camera := _player.get_node_or_null("HubCamera") as Camera2D
		_update_camera_zoom(camera)


func _update_camera_zoom(camera: Camera2D) -> void:
	if camera == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 760.0)
	var zoom_value := 1.14
	if compact and physical.y > physical.x:
		zoom_value = 1.55
	elif compact:
		zoom_value = 1.18
	camera.zoom = Vector2.ONE * zoom_value


func _refresh_interaction() -> void:
	if _interaction_prompt == null or _dialog_open:
		return
	var nearby := _is_operator_nearby()
	var compact := UI.is_compact(get_viewport(), 760.0)
	_interaction_prompt.visible = nearby and not _transitioning and not compact
	if _mobile_talk_button != null:
		_mobile_talk_button.disabled = not nearby or _transitioning
	if nearby:
		_objective_label.text = "OBJECTIVE  ·  Talk to the Battle Operator"


func _is_operator_nearby() -> bool:
	return _player != null and _operator != null and _player.position.distance_to(_operator.position) <= INTERACTION_DISTANCE


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


func _open_dialog() -> void:
	if _dialog_open or _transitioning:
		return
	_dialog_open = true
	_player.movement_enabled = false
	_player.velocity = Vector2.ZERO
	_player.set_facing("up_right")
	_operator.set_facing("down_left")
	_interaction_prompt.visible = false
	_mobile_controls.visible = false
	_dialog_panel.visible = true
	_start_battle_button.grab_focus()
	print("[Hub] DIALOGUE_OPEN")


func _close_dialog() -> void:
	if not _dialog_open or _transitioning:
		return
	_dialog_open = false
	_dialog_panel.visible = false
	_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()


func _start_test_battle() -> void:
	if _transitioning:
		return
	_transitioning = true
	_player.movement_enabled = false
	_mobile_controls.visible = false
	print("[Hub] START_TEST_BATTLE")
	var tween := create_tween()
	tween.tween_property(_transition_rect, "color:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_mobile_interact() -> void:
	if _dialog_open:
		return
	if _is_operator_nearby():
		_open_dialog()


func _set_touch_flag(direction: String, pressed: bool) -> void:
	_touch_flags[direction] = pressed
	print("[Hub] TOUCH_MOVE direction=%s pressed=%s" % [direction, pressed])
	var touch_direction := Vector2(
		(1.0 if bool(_touch_flags["right"]) else 0.0) - (1.0 if bool(_touch_flags["left"]) else 0.0),
		(1.0 if bool(_touch_flags["down"]) else 0.0) - (1.0 if bool(_touch_flags["up"]) else 0.0)
	)
	if _player != null:
		_player.set_touch_direction(touch_direction)


func _on_player_moved(_world_position: Vector2) -> void:
	_refresh_interaction()


func _animate_environment() -> void:
	for tile: Sprite2D in _water_tiles:
		var phase := float(tile.get_meta("phase", 0.0))
		var base_position := Vector2(tile.get_meta("base_position", tile.position))
		var wave := sin(_elapsed * 1.7 + phase) * 0.5
		tile.position = base_position + Vector2(0.0, wave)
		tile.modulate = Color(0.90 + wave * 0.025, 0.96 + wave * 0.02, 1.0, 1.0)
	for tree: Sprite2D in _trees:
		var phase := float(tree.get_meta("phase", 0.0))
		var base_rotation := float(tree.get_meta("base_rotation", 0.0))
		tree.rotation = base_rotation + sin(_elapsed * 0.85 + phase) * 0.012


func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


func _world_to_grid(world_position: Vector2) -> Vector2:
	var grid_x := (world_position.x / TILE_HALF_WIDTH + world_position.y / TILE_HALF_HEIGHT) * 0.5
	var grid_y := (world_position.y / TILE_HALF_HEIGHT - world_position.x / TILE_HALF_WIDTH) * 0.5
	return Vector2(grid_x, grid_y)
