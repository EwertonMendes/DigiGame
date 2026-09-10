extends Node

const MovementSystemScript = preload("res://src/MovementSystem.gd")
const DATABASE_PATH := "res://database/base-digimon-list.json"
const DEFAULT_MOV := 4
const ENEMY_PLACEHOLDER_TURN_SECONDS := 0.45

enum Phase {
	TURN_START,
	COMMAND,
	MOVE_SELECT,
	MOVING,
	ACTION_SELECT,
	TARGET_SELECT,
	ACTION_RESOLVE,
	TURN_END,
}

var phase: Phase = Phase.TURN_START
var current_actor: Node = null
var _field: Node = null
var _controller: Node = null
var _movement_system = MovementSystemScript.new()
var _turn_order: Array[Node] = []
var _turn_index := -1
var _reachable_tiles: Dictionary = {}
var _turn_start_grid := Vector2i.ZERO
var _last_move_path: Array[Vector2i] = []
var _has_moved := false
var _input_locked := false
var _mov_by_key: Dictionary = {}


func _ready() -> void:
	_field = get_node_or_null("../Blocks")
	_controller = get_node_or_null("../DigimonController")
	_load_movement_database()
	if _field != null and _field.has_signal("hovered_grid_changed"):
		_field.connect("hovered_grid_changed", _on_hovered_grid_changed)
	call_deferred("_start_battle")


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked or current_actor == null or not _is_user_controlled(current_actor):
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if phase == Phase.MOVE_SELECT:
				cancel_move_selection()
				get_viewport().set_input_as_handled()
			return

	if GlobalVariables.TouchInputActive or not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	handle_world_tap(_pointer_world_position())


func uses_tactical_input() -> bool:
	return true


func handle_world_tap(world_position: Vector2) -> bool:
	if _input_locked or current_actor == null or not _is_user_controlled(current_actor):
		return false
	if _field == null or not _field.has_method("select_tile_from_world"):
		return false
	if not bool(_field.call("select_tile_from_world", world_position)):
		return false

	var grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
	match phase:
		Phase.COMMAND:
			var hovered: Node = null
			if _controller != null and _controller.has_method("get_digimon_under_pointer"):
				hovered = _controller.call("get_digimon_under_pointer", world_position) as Node
			if hovered == current_actor:
				begin_move_selection()
				return true
		Phase.MOVE_SELECT:
			if grid == _turn_start_grid:
				cancel_move_selection()
				return true
			if _reachable_tiles.has(grid):
				_perform_move_to(grid)
				return true
	return false


func begin_move_selection() -> void:
	if current_actor == null or _input_locked or _has_moved or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND:
		return

	_turn_start_grid = _grid_for_actor(current_actor)
	_reachable_tiles = _movement_system.get_reachable_tiles(
		_field,
		_controller,
		current_actor,
		_turn_start_grid,
		_movement_for(current_actor)
	)
	phase = Phase.MOVE_SELECT
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", true)
	if _field != null and _field.has_method("set_movement_range"):
		_field.call("set_movement_range", _reachable_tiles, _turn_start_grid, current_actor)
	_refresh_hud()


func cancel_move_selection() -> void:
	if phase != Phase.MOVE_SELECT or _input_locked:
		return
	_reachable_tiles.clear()
	if _field != null:
		if _field.has_method("clear_movement_range"):
			_field.call("clear_movement_range")
		if _field.has_method("clear_movement_path"):
			_field.call("clear_movement_path")
	if current_actor != null and current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	phase = Phase.COMMAND
	_refresh_hud()


func defend_current() -> void:
	if current_actor == null or _input_locked or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return
	phase = Phase.ACTION_RESOLVE
	current_actor.set("is_defending", true)
	_refresh_hud()
	call_deferred("_end_turn")


func wait_current() -> void:
	if current_actor == null or _input_locked or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()
	call_deferred("_end_turn")


func undo_move() -> void:
	if current_actor == null or _input_locked or not _has_moved or phase != Phase.ACTION_SELECT:
		return
	if not current_actor.has_method("move_along_grid_path"):
		return

	var route: Array[Vector2i] = [_turn_start_grid]
	for grid in _last_move_path:
		route.append(grid)
	route.reverse()
	if not route.is_empty():
		route.remove_at(0)

	_input_locked = true
	phase = Phase.MOVING
	_refresh_hud()
	await current_actor.call("move_along_grid_path", route, _field)
	_has_moved = false
	_last_move_path.clear()
	_input_locked = false
	phase = Phase.COMMAND
	_refresh_hud()


func get_hud_state() -> Dictionary:
	var actor_name := ""
	if current_actor != null:
		actor_name = String(current_actor.get("digimon_key")).capitalize()
	var user_turn := current_actor != null and _is_user_controlled(current_actor)
	return {
		"actor_name": actor_name,
		"phase": phase_name(),
		"mov": _movement_for(current_actor) if current_actor != null else DEFAULT_MOV,
		"is_user_turn": user_turn,
		"can_move": user_turn and phase == Phase.COMMAND and not _has_moved and not _input_locked,
		"can_defend": user_turn and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT) and not _input_locked,
		"can_wait": user_turn and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT) and not _input_locked,
		"can_undo": user_turn and phase == Phase.ACTION_SELECT and _has_moved and not _input_locked,
		"can_cancel": user_turn and phase == Phase.MOVE_SELECT and not _input_locked,
	}


func phase_name() -> String:
	match phase:
		Phase.TURN_START: return "Início do turno"
		Phase.COMMAND: return "Escolha uma ação"
		Phase.MOVE_SELECT: return "Escolha o destino"
		Phase.MOVING: return "Movendo"
		Phase.ACTION_SELECT: return "Escolha uma ação"
		Phase.TARGET_SELECT: return "Escolha o alvo"
		Phase.ACTION_RESOLVE: return "Resolvendo ação"
		Phase.TURN_END: return "Fim do turno"
	return ""


func _start_battle() -> void:
	if _controller == null:
		return
	_turn_order.clear()
	for child in _controller.get_children():
		if child is CharacterBody2D:
			_turn_order.append(child)
	if _turn_order.is_empty():
		return
	_turn_index = -1
	_start_next_turn()


func _start_next_turn() -> void:
	if _turn_order.is_empty():
		return

	_turn_index = (_turn_index + 1) % _turn_order.size()
	var attempts := 0
	while attempts < _turn_order.size() and not is_instance_valid(_turn_order[_turn_index]):
		_turn_index = (_turn_index + 1) % _turn_order.size()
		attempts += 1
	if attempts >= _turn_order.size():
		return

	current_actor = _turn_order[_turn_index]
	phase = Phase.TURN_START
	_has_moved = false
	_last_move_path.clear()
	_reachable_tiles.clear()
	_input_locked = false
	current_actor.set("is_defending", false)
	_turn_start_grid = _grid_for_actor(current_actor)
	_sync_turn_highlight()
	_focus_current_actor()

	phase = Phase.COMMAND
	_refresh_hud()
	if not _is_user_controlled(current_actor):
		_skip_enemy_placeholder_turn(current_actor)


func _skip_enemy_placeholder_turn(actor: Node) -> void:
	await get_tree().create_timer(ENEMY_PLACEHOLDER_TURN_SECONDS).timeout
	if current_actor != actor or phase != Phase.COMMAND:
		return
	if GlobalVariables.DebugMode:
		_refresh_hud()
		return
	_end_turn()


func _end_turn() -> void:
	if current_actor == null:
		return
	phase = Phase.TURN_END
	_input_locked = true
	if _field != null:
		if _field.has_method("clear_movement_range"):
			_field.call("clear_movement_range")
		if _field.has_method("clear_movement_path"):
			_field.call("clear_movement_path")
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	if current_actor.has_method("set_turn_active"):
		current_actor.call("set_turn_active", false)
	_refresh_hud()
	call_deferred("_start_next_turn")


func _perform_move_to(destination: Vector2i) -> void:
	if _input_locked or phase != Phase.MOVE_SELECT or not _reachable_tiles.has(destination):
		return
	var path: Array[Vector2i] = _movement_system.find_path(
		_field,
		_controller,
		current_actor,
		_turn_start_grid,
		destination,
		_movement_for(current_actor)
	)
	if path.is_empty():
		return

	_input_locked = true
	phase = Phase.MOVING
	if _field != null:
		_field.call("clear_movement_range")
		_field.call("clear_movement_path")
	_refresh_hud()
	await current_actor.call("move_along_grid_path", path, _field)
	_last_move_path = path.duplicate()
	_has_moved = true
	_reachable_tiles.clear()
	_input_locked = false
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	phase = Phase.ACTION_SELECT
	_refresh_hud()


func _on_hovered_grid_changed(grid: Vector2i, block_reason: String) -> void:
	if phase != Phase.MOVE_SELECT or current_actor == null or _input_locked or _field == null:
		return
	if not block_reason.is_empty() or not _reachable_tiles.has(grid):
		if _field.has_method("clear_movement_path"):
			_field.call("clear_movement_path")
		return

	var path: Array[Vector2i] = _movement_system.find_path(
		_field,
		_controller,
		current_actor,
		_turn_start_grid,
		grid,
		_movement_for(current_actor)
	)
	if _field.has_method("set_movement_path"):
		_field.call("set_movement_path", path)


func _grid_for_actor(actor: Node) -> Vector2i:
	if actor == null or _field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var tile_world_position := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(_field.call("world_to_grid", _field.to_local(tile_world_position)))


func _movement_for(actor: Node) -> int:
	if actor == null:
		return DEFAULT_MOV
	var key := String(actor.get("digimon_key")).to_lower()
	return maxi(0, int(_mov_by_key.get(key, DEFAULT_MOV)))


func _load_movement_database() -> void:
	_mov_by_key.clear()
	if not FileAccess.file_exists(DATABASE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		return
	for entry in parsed:
		if not entry is Dictionary or not entry.has("name"):
			continue
		var key := String(entry["name"]).to_lower()
		# The current database does not need MOV yet. As soon as that attribute is
		# added, this controller starts using it; otherwise every Digimon gets 4.
		_mov_by_key[key] = int(entry.get("MOV", DEFAULT_MOV))


func _is_user_controlled(actor: Node) -> bool:
	return actor != null and (bool(actor.get("is_player_controlled")) or GlobalVariables.DebugMode)


func _sync_turn_highlight() -> void:
	if _controller == null:
		return
	for child in _controller.get_children():
		if child is CharacterBody2D and child.has_method("set_turn_active"):
			child.call("set_turn_active", child == current_actor)


func _focus_current_actor() -> void:
	if current_actor == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("focus_on"):
		camera.call("focus_on", current_actor.global_position)


func _pointer_world_position() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


func _refresh_hud() -> void:
	var hud := get_node_or_null("../BattleUI/Root")
	if hud != null and hud.has_method("refresh_from_controller"):
		hud.call("refresh_from_controller")
