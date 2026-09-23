extends "res://src/world/HubPartyFollowers.gd"
class_name WorldPartyFollowers

var _configured_world: Node = null
var _configured_player: Node2D = null


func configure(world_controller: Node, player: Node2D) -> void:
	_configured_world = world_controller
	_configured_player = player


func _bind_to_hub() -> void:
	if _bound:
		return
	if _configured_world == null or _configured_player == null:
		super._bind_to_hub()
		return
	_hub = _configured_world
	_player = _configured_player
	_bound = true
	var moved := Callable(self, "_on_player_world_position_changed")
	if _player.has_signal("world_position_changed") and not _player.is_connected("world_position_changed", moved):
		_player.connect("world_position_changed", moved)
	_trail.clear()
	_trail.append(_player.global_position)
	_sync_party()
