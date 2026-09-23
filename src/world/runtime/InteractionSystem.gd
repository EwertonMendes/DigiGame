extends Node
class_name InteractionSystem

signal candidate_changed(action_text: String)
signal interaction_requested(action_id: String, payload: Dictionary)

const REFRESH_DISTANCE_SQUARED := 16.0

var _player: Node2D = null
var _current: WorldInteractable = null
var _interactables: Array[WorldInteractable] = []
var _last_refresh_position := Vector2.ZERO
var _has_refresh_position := false


func configure(player: Node2D) -> void:
	_player = player
	_rebuild_registry()

	var tree := get_tree()
	if tree != null:
		if not tree.node_added.is_connected(_on_node_added):
			tree.node_added.connect(_on_node_added)
		if not tree.node_removed.is_connected(_on_node_removed):
			tree.node_removed.connect(_on_node_removed)

	if _player != null and _player.has_signal("world_position_changed"):
		var moved := Callable(self, "_on_player_moved")
		if not _player.is_connected("world_position_changed", moved):
			_player.connect("world_position_changed", moved)
	_refresh_candidate()


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		if tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)
		if tree.node_removed.is_connected(_on_node_removed):
			tree.node_removed.disconnect(_on_node_removed)
	if _player != null and _player.has_signal("world_position_changed"):
		var moved := Callable(self, "_on_player_moved")
		if _player.is_connected("world_position_changed", moved):
			_player.disconnect("world_position_changed", moved)


func has_candidate() -> bool:
	return _current != null and is_instance_valid(_current)


func current_action_text() -> String:
	return _current.prompt if has_candidate() else ""


func try_interact() -> bool:
	if not has_candidate() or not _current.can_interact(_player):
		_refresh_candidate()
		if not has_candidate() or not _current.can_interact(_player):
			return false
	interaction_requested.emit(_current.action_id, _current.payload.duplicate(true))
	return true


func refresh_now() -> void:
	_has_refresh_position = false
	_refresh_candidate()


func _on_player_moved(world_position: Vector2) -> void:
	if _has_refresh_position and world_position.distance_squared_to(_last_refresh_position) < REFRESH_DISTANCE_SQUARED:
		return
	_last_refresh_position = world_position
	_has_refresh_position = true
	_refresh_candidate()


func _on_node_added(node: Node) -> void:
	if not node is WorldInteractable:
		return
	var interactable := node as WorldInteractable
	if not _interactables.has(interactable):
		_interactables.append(interactable)
	_refresh_candidate()


func _on_node_removed(node: Node) -> void:
	if not node is WorldInteractable:
		return
	var interactable := node as WorldInteractable
	_interactables.erase(interactable)
	if interactable == _current:
		_current = null
		candidate_changed.emit("")
	_refresh_candidate()


func _rebuild_registry() -> void:
	_interactables.clear()
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("world_interactable"):
		if node is WorldInteractable:
			_interactables.append(node as WorldInteractable)


func _refresh_candidate() -> void:
	var best: WorldInteractable = null
	var best_priority := -2147483648
	var best_distance_squared := INF
	if _player != null:
		for candidate: WorldInteractable in _interactables:
			if candidate == null or not is_instance_valid(candidate) or not candidate.can_interact(_player):
				continue
			var distance_squared := _player.global_position.distance_squared_to(candidate.global_position)
			if candidate.priority > best_priority or (candidate.priority == best_priority and distance_squared < best_distance_squared):
				best = candidate
				best_priority = candidate.priority
				best_distance_squared = distance_squared
	if best == _current:
		return
	_current = best
	candidate_changed.emit(current_action_text())
