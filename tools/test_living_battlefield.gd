extends Node

const FieldScript = preload("res://src/world/DevilsWorkshopField.gd")
const MovementSystemScript = preload("res://src/MovementSystem.gd")

var _failed := false


func _ready() -> void:
	var field := FieldScript.new()
	add_child(field)
	await get_tree().process_frame

	_expect(
		field.tile_map_data.size() == field.GRID_SIZE_X * field.GRID_SIZE_Y,
		"Battlefield must still author every tactical cell"
	)

	# The underlying battlefield must remain the current master composition.
	_expect(_tile_type(field, Vector2i(7, 3)) == "data", "Master data-anchor tiles must remain unchanged")
	_expect(_tile_type(field, Vector2i(5, 3)) == "route", "Master deployment terrace tiles must remain unchanged")
	_expect(_tile_type(field, Vector2i(7, 12)) == "route", "Master center crossing must remain unchanged")
	_expect(_tile_type(field, Vector2i(4, 12)) == "grass", "Obstacle props must not replace the master grass tile")
	_expect(field.get_node_or_null("PerimeterWater") != null, "Master perimeter water must remain unchanged")
	_expect(not _contains_removed_terrain_types(field), "Old PR water/rough terrain types must not return")

	# Sparse props are gameplay blockers through the field's existing static
	# obstacle contract, which MovementSystem already consumes.
	_expect(
		field.get_static_tile_block_reason(Vector2i(4, 12)) == "terrain_blocked",
		"Oak trees must block traversal"
	)
	_expect(
		field.get_static_tile_block_reason(Vector2i(10, 14)) == "terrain_blocked",
		"Rock formations must block traversal"
	)
	_expect(
		String(field.tile_map_data[Vector2i(4, 12)].get("blocker_kind", "")) == "tree",
		"Tree cells must expose their blocker kind"
	)
	_expect(
		String(field.tile_map_data[Vector2i(10, 14)].get("blocker_kind", "")) == "rock",
		"Rock cells must expose their blocker kind"
	)
	for x in range(6, 9):
		_expect(
			field.get_static_tile_block_reason(Vector2i(x, 12)).is_empty(),
			"The three-cell center route must remain open for large footprints"
		)

	_validate_environment(field)
	_validate_pathfinding(field)

	if _failed:
		push_error("living battlefield regression failed")
		get_tree().quit(1)
		return
	print("living battlefield regression passed")
	get_tree().quit()


func _validate_environment(field: Node) -> void:
	var environment := field.get_node_or_null("BattlefieldEnvironment")
	_expect(environment != null, "Battlefield environment layer must exist")
	if environment == null:
		return

	_expect(environment.get_child_count() == 7, "Field must contain exactly three trees and four rock props")

	var large_tree := environment.get_node_or_null("OakTree_04_12") as Sprite2D
	var small_tree := environment.get_node_or_null("OakTreeSmall_10_10") as Sprite2D
	var rock := environment.get_node_or_null("Rock_10_14") as Sprite2D

	_expect(large_tree != null, "A full-size Oak_Tree prop must be present")
	_expect(small_tree != null, "An Oak_Tree_Small prop must be present")
	_expect(rock != null, "The retained rock prop must be present")

	if large_tree != null and large_tree.texture != null:
		_expect(
			large_tree.texture.resource_path == "res://assets/terrain/Oak_Tree.png",
			"Large battlefield trees must use Oak_Tree.png"
		)
	if small_tree != null and small_tree.texture != null:
		_expect(
			small_tree.texture.resource_path == "res://assets/terrain/Oak_Tree_Small.png",
			"Small battlefield trees must use Oak_Tree_Small.png"
		)
	if rock != null and rock.texture != null:
		_expect(
			rock.texture.resource_path == "res://assets/world/hawkbirdtree/rock.png",
			"Battlefield rocks must keep the approved rock asset"
		)


func _validate_pathfinding(field: Node) -> void:
	var movement = MovementSystemScript.new()
	var origin := Vector2i(4, 10)
	var destination := Vector2i(4, 14)

	var reachable: Dictionary = movement.get_reachable_tiles(field, null, null, origin, 20)
	_expect(
		not reachable.has(Vector2i(4, 12)),
		"Movement search must never expose a tree blocker as reachable"
	)
	_expect(
		not reachable.has(Vector2i(10, 14)),
		"Movement search must never expose a rock blocker as reachable"
	)

	var path: Array[Vector2i] = movement.find_path(field, null, null, origin, destination, 20)
	_expect(not path.is_empty(), "Movement must still find a route around sparse props")
	_expect(path.size() > 4, "The tree must force a real detour instead of straight traversal")
	for grid: Vector2i in path:
		_expect(
			field.get_static_tile_block_reason(grid).is_empty(),
			"Computed movement paths must never enter an authored prop blocker"
		)


func _tile_type(field: Node, grid: Vector2i) -> String:
	var raw = field.tile_map_data.get(grid, {})
	return String((raw as Dictionary).get("type", "")) if raw is Dictionary else ""


func _contains_removed_terrain_types(field: Node) -> bool:
	for raw in field.tile_map_data.values():
		if not raw is Dictionary:
			continue
		var terrain_type := String((raw as Dictionary).get("type", ""))
		if terrain_type in ["shallow_water", "deep_water", "rough_grass"]:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
