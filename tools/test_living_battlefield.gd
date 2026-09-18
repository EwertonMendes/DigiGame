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

	_expect(
		environment.get_child_count() == 8,
		"Field must contain three tree blockers, one separate stump and four rock props"
	)

	var large_tree := environment.get_node_or_null("OakTreeLarge_04_12") as Sprite2D
	var small_tree_a := environment.get_node_or_null("OakTreeSmallA_10_10") as Sprite2D
	var small_tree_b := environment.get_node_or_null("OakTreeSmallB_04_16") as Sprite2D
	var stump := environment.get_node_or_null("OakStump_12_10") as Sprite2D
	var rock := environment.get_node_or_null("Rock_10_14") as Sprite2D

	_expect(large_tree != null, "A full-size Oak_Tree prop must be present")
	_expect(small_tree_a != null, "First Oak_Tree_Small tree must be cropped into its own prop")
	_expect(small_tree_b != null, "Second Oak_Tree_Small tree must be cropped into its own prop")
	_expect(stump != null, "Oak_Tree_Small stump must be cropped into its own tile prop")
	_expect(rock != null, "The retained rock prop must be present")

	_expect(
		field.get_static_tile_block_reason(Vector2i(12, 10)).is_empty(),
		"The split oak stump is decorative and must not silently become a blocker"
	)

	_assert_atlas_source(large_tree, "res://assets/terrain/Oak_Tree.png", "Large oak")
	_assert_atlas_source(small_tree_a, "res://assets/terrain/Oak_Tree_Small.png", "Small oak A")
	_assert_atlas_source(small_tree_b, "res://assets/terrain/Oak_Tree_Small.png", "Small oak B")
	_assert_atlas_source(stump, "res://assets/terrain/Oak_Tree_Small.png", "Oak stump")
	_assert_atlas_source(rock, "res://assets/world/hawkbirdtree/rock.png", "Rock")

	_assert_prop_foot_on_tile(field, large_tree, Vector2i(4, 12), Vector2(20.5, 62.0), "Large oak")
	_assert_prop_foot_on_tile(field, small_tree_a, Vector2i(10, 10), Vector2(10.5, 33.0), "Small oak A")
	_assert_prop_foot_on_tile(field, small_tree_b, Vector2i(4, 16), Vector2(10.5, 25.0), "Small oak B")
	_assert_prop_foot_on_tile(field, stump, Vector2i(12, 10), Vector2(3.5, 7.0), "Oak stump")
	_assert_prop_foot_on_tile(field, rock, Vector2i(10, 14), Vector2(13.5, 21.0), "Rock")

	if rock != null:
		_expect(
			rock.scale.x <= 0.90 and rock.scale.y <= 0.90,
			"Rock props must remain smaller than their previous oversized presentation"
		)


func _assert_atlas_source(prop: Sprite2D, expected_path: String, label: String) -> void:
	if prop == null or prop.texture == null:
		return
	var atlas_texture := prop.texture as AtlasTexture
	_expect(atlas_texture != null, "%s must render a cropped atlas region" % label)
	if atlas_texture == null or atlas_texture.atlas == null:
		return
	_expect(
		atlas_texture.atlas.resource_path == expected_path,
		"%s must use the expected source asset" % label
	)


func _assert_prop_foot_on_tile(
	field: Node,
	prop: Sprite2D,
	grid: Vector2i,
	foot_anchor: Vector2,
	label: String
) -> void:
	if prop == null or prop.texture == null:
		return
	var expected := Vector2(field.call("grid_to_world", grid))
	var texture_center := prop.texture.get_size() * 0.5
	var center_to_foot := (foot_anchor - texture_center) * prop.scale
	var visual_foot := prop.position + center_to_foot
	_expect(
		visual_foot.distance_to(expected) <= 0.01,
		"%s foot/pivot must land on the exact center of its owning tile" % label
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
