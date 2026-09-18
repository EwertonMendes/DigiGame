extends Node2D
class_name BattlefieldEnvironment

const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

# Presentation-only layer for authored battlefield props.
# Gameplay collision remains in the field through static blocked cells. Every
# prop has an explicit visual foot/pivot that is aligned to one logical tile
# center, so the player can always tell which cell owns the obstacle.

const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const OAK_SMALL_SOURCE = preload("res://assets/terrain/Oak_Tree_Small.png")
const ROCK_SOURCE = preload("res://assets/world/hawkbirdtree/rock.png")

const ROCK_SCALE := 0.90
const ROCK_TINT := Color(0.94, 0.97, 0.94, 1.0)

const LARGE_TREE_OCCLUDED_ALPHA := 0.42
const OCCLUSION_FADE_SPEED := 7.5

# Upright blockers read better when their ground contact sits slightly toward
# the near edge of the isometric diamond instead of its mathematical center.
# Express the bias as a fraction of the tile's center-to-near-edge depth so it
# automatically follows the field geometry rather than using sprite-specific
# pixel offsets.
const BLOCKER_VISUAL_DEPTH_RATIO := 0.35
# Tall upright props need a stronger visual-depth correction because their
# canopy shifts the perceived center upward. Scale the extra bias from rendered
# height versus the actual isometric tile depth, so short trees and rocks stay
# where they already read correctly while tall props naturally sit deeper.
const TALL_PROP_EXTRA_DEPTH_RATIO := 0.50
const MAX_BLOCKER_VISUAL_DEPTH_RATIO := 0.90

# Visible alpha bounds inside the user-supplied source PNGs. Oak_Tree_Small.png
# is a compact atlas containing a stump and two separate trees, not one prop.
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)

const SMALL_STUMP_REGION := Rect2(13.0, 26.0, 7.0, 8.0)
const SMALL_STUMP_FOOT := Vector2(3.5, 7.0)

const SMALL_OAK_A_REGION := Rect2(37.0, 3.0, 23.0, 34.0)
const SMALL_OAK_A_FOOT := Vector2(10.5, 33.0)

const SMALL_OAK_B_REGION := Rect2(69.0, 3.0, 23.0, 26.0)
const SMALL_OAK_B_FOOT := Vector2(10.5, 25.0)

const ROCK_REGION := Rect2(1.0, 10.0, 30.0, 22.0)
const ROCK_FOOT := Vector2(13.5, 21.0)

var _field: Node2D = null
var _large_tree_occluders: Array[Sprite2D] = []


func _process(delta: float) -> void:
	_update_large_tree_occlusion(delta)


func configure(
	field: Node2D,
	tree_cells: Array[Vector2i],
	rock_cells: Array[Vector2i],
	stump_cell: Vector2i
) -> void:
	_field = field
	_build_trees(tree_cells)
	_build_stump(stump_cell)
	_build_rocks(rock_cells)


func _build_trees(cells: Array[Vector2i]) -> void:
	for index in range(cells.size()):
		var grid: Vector2i = cells[index]
		var descriptor := _tree_descriptor(index)
		var tree := _create_anchored_prop(
			String(descriptor["name"]) + "_%02d_%02d" % [grid.x, grid.y],
			descriptor["texture"] as Texture2D,
			grid,
			descriptor["foot"] as Vector2,
			1.0,
			true
		)
		tree.set_meta("obstacle_kind", "tree")
		tree.set_meta("grid", grid)
		add_child(tree)
		if bool(descriptor.get("large_canopy_occluder", false)):
			tree.set_meta("large_canopy_occluder", true)
			_large_tree_occluders.append(tree)


func _build_stump(grid: Vector2i) -> void:
	var stump_texture := _atlas_texture(OAK_SMALL_SOURCE, SMALL_STUMP_REGION)
	var stump := _create_anchored_prop(
		"OakStump_%02d_%02d" % [grid.x, grid.y],
		stump_texture,
		grid,
		SMALL_STUMP_FOOT,
		1.0,
		false
	)
	stump.set_meta("obstacle_kind", "decoration")
	stump.set_meta("grid", grid)
	add_child(stump)


func _build_rocks(cells: Array[Vector2i]) -> void:
	var rock_texture := _atlas_texture(ROCK_SOURCE, ROCK_REGION)
	for index in range(cells.size()):
		var grid: Vector2i = cells[index]
		var rock := _create_anchored_prop(
			"Rock_%02d_%02d" % [grid.x, grid.y],
			rock_texture,
			grid,
			ROCK_FOOT,
			ROCK_SCALE,
			true
		)
		rock.flip_h = index % 2 == 1
		rock.modulate = ROCK_TINT
		rock.set_meta("obstacle_kind", "rock")
		rock.set_meta("grid", grid)
		add_child(rock)


func _tree_descriptor(index: int) -> Dictionary:
	# Keep a restrained, repeatable visual rhythm: two large canopy trees for
	# every six authored tree cells, with the two small-oak cuts filling the
	# remaining positions. Large-canopy behavior comes from the descriptor,
	# not from a hard-coded battlefield coordinate.
	match index % 6:
		0, 4:
			return {
				"name": "OakTreeLarge",
				"texture": _atlas_texture(OAK_TREE_SOURCE, LARGE_OAK_REGION),
				"foot": LARGE_OAK_FOOT,
				"large_canopy_occluder": true,
			}
		1, 3:
			return {
				"name": "OakTreeSmallA",
				"texture": _atlas_texture(OAK_SMALL_SOURCE, SMALL_OAK_A_REGION),
				"foot": SMALL_OAK_A_FOOT,
				"large_canopy_occluder": false,
			}
		_:
			return {
				"name": "OakTreeSmallB",
				"texture": _atlas_texture(OAK_SMALL_SOURCE, SMALL_OAK_B_REGION),
				"foot": SMALL_OAK_B_FOOT,
				"large_canopy_occluder": false,
			}


func _atlas_texture(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	return texture


func _create_anchored_prop(
	prop_name: String,
	texture: Texture2D,
	grid: Vector2i,
	foot_anchor: Vector2,
	scale_factor: float,
	use_blocker_visual_anchor: bool
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = prop_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = _position_for_foot_anchor(
		grid,
		texture,
		foot_anchor,
		scale_factor,
		use_blocker_visual_anchor
	)
	var depth_grids: Array[Vector2i] = [grid]
	sprite.z_index = FootprintScript.isometric_front_depth(depth_grids)
	return sprite


func _position_for_foot_anchor(
	grid: Vector2i,
	texture: Texture2D,
	foot_anchor: Vector2,
	scale_factor: float,
	use_blocker_visual_anchor: bool
) -> Vector2:
	if _field == null:
		return Vector2.ZERO
	var ground_anchor := _visual_ground_anchor(
		grid,
		texture,
		scale_factor,
		use_blocker_visual_anchor
	)
	var texture_center := texture.get_size() * 0.5
	var center_to_foot := (foot_anchor - texture_center) * scale_factor
	return ground_anchor - center_to_foot


func _visual_ground_anchor(
	grid: Vector2i,
	texture: Texture2D,
	scale_factor: float,
	use_blocker_visual_anchor: bool
) -> Vector2:
	var tile_center := Vector2(_field.call("grid_to_world", grid))
	if not use_blocker_visual_anchor:
		return tile_center

	# One cardinal grid step moves half a tile-height downward on this 2:1
	# isometric projection. Using that measured depth keeps this policy valid if
	# the grid dimensions change later.
	var next_row_center := Vector2(_field.call("grid_to_world", grid + Vector2i(1, 0)))
	var center_to_near_edge := absf(next_row_center.y - tile_center.y)
	var tile_depth := maxf(1.0, center_to_near_edge * 2.0)
	var rendered_height := texture.get_height() * scale_factor
	var extra_height_tiles := maxf(0.0, (rendered_height - tile_depth) / tile_depth)
	var visual_depth_ratio := clampf(
		BLOCKER_VISUAL_DEPTH_RATIO + extra_height_tiles * TALL_PROP_EXTRA_DEPTH_RATIO,
		BLOCKER_VISUAL_DEPTH_RATIO,
		MAX_BLOCKER_VISUAL_DEPTH_RATIO
	)
	return tile_center + Vector2(0.0, center_to_near_edge * visual_depth_ratio)


func _update_large_tree_occlusion(delta: float) -> void:
	if _large_tree_occluders.is_empty():
		return
	var actor_container := _battle_actor_container()
	for tree: Sprite2D in _large_tree_occluders:
		if tree == null or not is_instance_valid(tree):
			continue
		var target_alpha := 1.0
		if actor_container != null:
			for actor in actor_container.get_children():
				if _should_fade_for_actor(tree, actor):
					target_alpha = LARGE_TREE_OCCLUDED_ALPHA
					break
		var next_modulate := tree.modulate
		next_modulate.a = move_toward(
			next_modulate.a,
			target_alpha,
			OCCLUSION_FADE_SPEED * delta
		)
		tree.modulate = next_modulate


func _battle_actor_container() -> Node:
	if _field == null or _field.get_parent() == null:
		return null
	return _field.get_parent().get_node_or_null("DigimonController")


func _should_fade_for_actor(tree: Sprite2D, actor: Node) -> bool:
	if tree == null or actor == null or not actor is Node2D:
		return false
	if not (actor as Node2D).visible:
		return false
	if not actor.has_method("get_occupied_grids"):
		return false

	var raw_grids = actor.call("get_occupied_grids")
	if not raw_grids is Array:
		return false
	var actor_grids: Array[Vector2i] = []
	for raw_grid in raw_grids:
		if raw_grid is Vector2i:
			actor_grids.append(Vector2i(raw_grid))
	if actor_grids.is_empty():
		return false

	var tree_grid_variant = tree.get_meta("grid", null)
	if not tree_grid_variant is Vector2i:
		return false
	var tree_grid := Vector2i(tree_grid_variant)
	var actor_depth := FootprintScript.isometric_front_depth(actor_grids)
	var tree_grids: Array[Vector2i] = [tree_grid]
	var tree_depth := FootprintScript.isometric_front_depth(tree_grids)
	if actor_depth >= tree_depth:
		return false

	var actor_sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
	if actor_sprite == null or actor_sprite.texture == null:
		return false
	return _sprite_global_rect(tree).intersects(_sprite_global_rect(actor_sprite), true)


func _sprite_global_rect(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var transform := sprite.get_global_transform()
	var corners := [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var result := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		result = result.expand(corner)
	return result
