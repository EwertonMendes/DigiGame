extends Node2D
class_name BattlefieldEnvironment

# Presentation-only layer for authored battlefield props.
# Gameplay collision remains in the field through static blocked cells. Every
# prop has an explicit visual foot/pivot that is aligned to one logical tile
# center, so the player can always tell which cell owns the obstacle.

const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const OAK_SMALL_SOURCE = preload("res://assets/terrain/Oak_Tree_Small.png")
const ROCK_SOURCE = preload("res://assets/world/hawkbirdtree/rock.png")

const TREE_Z_INDEX := -22
const ROCK_Z_INDEX := -24
const ROCK_SCALE := 0.90
const ROCK_TINT := Color(0.94, 0.97, 0.94, 1.0)

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
			1.0
		)
		tree.z_index = TREE_Z_INDEX
		tree.set_meta("obstacle_kind", "tree")
		tree.set_meta("grid", grid)
		add_child(tree)


func _build_stump(grid: Vector2i) -> void:
	var stump_texture := _atlas_texture(OAK_SMALL_SOURCE, SMALL_STUMP_REGION)
	var stump := _create_anchored_prop(
		"OakStump_%02d_%02d" % [grid.x, grid.y],
		stump_texture,
		grid,
		SMALL_STUMP_FOOT,
		1.0
	)
	stump.z_index = TREE_Z_INDEX
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
			ROCK_SCALE
		)
		rock.z_index = ROCK_Z_INDEX
		rock.flip_h = index % 2 == 1
		rock.modulate = ROCK_TINT
		rock.set_meta("obstacle_kind", "rock")
		rock.set_meta("grid", grid)
		add_child(rock)


func _tree_descriptor(index: int) -> Dictionary:
	match index:
		0:
			return {
				"name": "OakTreeLarge",
				"texture": _atlas_texture(OAK_TREE_SOURCE, LARGE_OAK_REGION),
				"foot": LARGE_OAK_FOOT,
			}
		1:
			return {
				"name": "OakTreeSmallA",
				"texture": _atlas_texture(OAK_SMALL_SOURCE, SMALL_OAK_A_REGION),
				"foot": SMALL_OAK_A_FOOT,
			}
		_:
			return {
				"name": "OakTreeSmallB",
				"texture": _atlas_texture(OAK_SMALL_SOURCE, SMALL_OAK_B_REGION),
				"foot": SMALL_OAK_B_FOOT,
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
	scale_factor: float
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = prop_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = _position_for_foot_anchor(grid, texture, foot_anchor, scale_factor)
	return sprite


func _position_for_foot_anchor(
	grid: Vector2i,
	texture: Texture2D,
	foot_anchor: Vector2,
	scale_factor: float
) -> Vector2:
	if _field == null:
		return Vector2.ZERO
	var tile_center := Vector2(_field.call("grid_to_world", grid))
	var texture_center := texture.get_size() * 0.5
	var center_to_foot := (foot_anchor - texture_center) * scale_factor
	return tile_center - center_to_foot
