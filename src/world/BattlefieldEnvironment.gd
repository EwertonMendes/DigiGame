extends Node2D
class_name BattlefieldEnvironment

# Presentation-only layer for authored battlefield props.
# Gameplay collision remains in the field through static blocked cells, so
# visuals can change without changing pathfinding rules.

const OAK_TREE_TEXTURE = preload("res://assets/terrain/Oak_Tree.png")
const OAK_TREE_SMALL_TEXTURE = preload("res://assets/terrain/Oak_Tree_Small.png")
const ROCK_TEXTURE = preload("res://assets/world/hawkbirdtree/rock.png")

const TREE_Z_INDEX := -22
const ROCK_Z_INDEX := -24
const ROCK_SCALE := 1.30
const ROCK_TINT := Color(0.94, 0.97, 0.94, 1.0)

var _field: Node2D = null


func configure(
	field: Node2D,
	tree_cells: Array[Vector2i],
	rock_cells: Array[Vector2i]
) -> void:
	_field = field
	_build_trees(tree_cells)
	_build_rocks(rock_cells)


func _build_trees(cells: Array[Vector2i]) -> void:
	for index in range(cells.size()):
		var grid: Vector2i = cells[index]
		var use_small := index % 2 == 1
		var texture := OAK_TREE_SMALL_TEXTURE if use_small else OAK_TREE_TEXTURE
		var tree := Sprite2D.new()
		tree.name = "%s_%02d_%02d" % [
			"OakTreeSmall" if use_small else "OakTree",
			grid.x,
			grid.y,
		]
		tree.texture = texture
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.position = _foot_aligned_position(grid, texture, 1.0)
		tree.z_index = TREE_Z_INDEX
		tree.set_meta("obstacle_kind", "tree")
		tree.set_meta("grid", grid)
		add_child(tree)


func _build_rocks(cells: Array[Vector2i]) -> void:
	for index in range(cells.size()):
		var grid: Vector2i = cells[index]
		var rock := Sprite2D.new()
		rock.name = "Rock_%02d_%02d" % [grid.x, grid.y]
		rock.texture = ROCK_TEXTURE
		rock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rock.scale = Vector2.ONE * ROCK_SCALE
		rock.position = _foot_aligned_position(grid, ROCK_TEXTURE, ROCK_SCALE)
		rock.z_index = ROCK_Z_INDEX
		rock.flip_h = index % 2 == 1
		rock.modulate = ROCK_TINT
		rock.set_meta("obstacle_kind", "rock")
		rock.set_meta("grid", grid)
		add_child(rock)


func _foot_aligned_position(grid: Vector2i, texture: Texture2D, scale_factor: float) -> Vector2:
	if _field == null:
		return Vector2.ZERO
	var foot := Vector2(_field.call("grid_to_world", grid))
	var half_height := float(texture.get_height()) * scale_factor * 0.5
	return foot + Vector2(0.0, -half_height)
