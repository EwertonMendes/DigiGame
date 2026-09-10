extends "res://src/DigimonRuntimeController.gd"


func get_digimon_at_tile(tile_world_position: Vector2, ignored_digimon: Node = null) -> Node:
	for child in get_children():
		if child == ignored_digimon or not child is CharacterBody2D:
			continue
		if child.has_method("is_available_for_turn") and not bool(child.call("is_available_for_turn")):
			continue
		if not child.has_method("get_tile_world_position"):
			continue
		var occupied_position := Vector2(child.call("get_tile_world_position"))
		if occupied_position.distance_squared_to(tile_world_position) < 0.25:
			return child
	return null


func is_tile_occupied(tile_world_position: Vector2, ignored_digimon: Node = null) -> bool:
	return get_digimon_at_tile(tile_world_position, ignored_digimon) != null
