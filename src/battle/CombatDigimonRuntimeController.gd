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


func get_digimon_under_pointer(world_position: Vector2) -> Node:
	# Tactical interaction belongs to the occupied grid tile, not to a sprite's
	# rectangular texture bounds. Large sprites (notably Greymon) can overlap the
	# visual area of neighboring units and must never steal hover/target input.
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("world_to_grid") or not field.has_method("grid_to_world"):
		return null

	var grid := Vector2i(field.call("world_to_grid", field.to_local(world_position)))
	var map_data: Dictionary = field.get("tile_map_data")
	if not map_data.has(grid):
		return null

	var tile_local_position := Vector2(field.call("grid_to_world", grid))
	var tile_world_position := field.to_global(tile_local_position)
	return get_digimon_at_tile(tile_world_position)
