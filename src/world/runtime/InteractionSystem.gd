extends Node
class_name InteractionSystem

signal candidate_changed(action_text: String)
signal interaction_requested(action_id: String, payload: Dictionary)

var _player: Node2D = null
var _current: WorldInteractable = null


func configure(player: Node2D) -> void:
	_player = player


func _process(_delta: float) -> void:
	_refresh_candidate()


func has_candidate() -> bool:
	return _current != null and is_instance_valid(_current)


func current_action_text() -> String:
	return _current.prompt if has_candidate() else ""


func try_interact() -> bool:
	if not has_candidate() or not _current.can_interact(_player):
		return false
	interaction_requested.emit(_current.action_id, _current.payload.duplicate(true))
	return true


func _refresh_candidate() -> void:
	var best: WorldInteractable = null
	var best_priority := -2147483648
	var best_distance := INF
	if _player != null:
		for node in get_tree().get_nodes_in_group("world_interactable"):
			if not node is WorldInteractable:
				continue
			var candidate := node as WorldInteractable
			if not candidate.can_interact(_player):
				continue
			var distance := _player.global_position.distance_to(candidate.global_position)
			if candidate.priority > best_priority or (candidate.priority == best_priority and distance < best_distance):
				best = candidate
				best_priority = candidate.priority
				best_distance = distance
	if best == _current:
		return
	_current = best
	candidate_changed.emit(current_action_text())
