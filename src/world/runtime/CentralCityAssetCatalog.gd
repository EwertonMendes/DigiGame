extends RefCounted
class_name CentralCityAssetCatalog

# Central City art uses the same logical isometric grid as the overworld.
# Ground assets are sized from logical footprints rather than arbitrary pixel widths.
const TILE_WIDTH := 64.0

const ROAD_STRAIGHT := "straight"
const ROAD_CORNER := "corner"
const ROAD_T_JUNCTION := "t_junction"
const ROAD_INTERSECTION := "intersection"

const ROAD_PIECE_ASSETS := {
	ROAD_STRAIGHT: "road",
	ROAD_CORNER: "",
	ROAD_T_JUNCTION: "",
	ROAD_INTERSECTION: "",
}

const ASSETS := {
	"road": {
		"kind": "ground",
		"footprint": Vector2i(7, 7),
		"anchor": Vector2(0.5, 0.5),
		"road_piece": ROAD_STRAIGHT,
		"connections": ["nw", "se"],
	},
	"sidewalk": {
		"kind": "ground",
		"footprint": Vector2i(7, 7),
		"anchor": Vector2(0.5, 0.5),
	},
	"plaza-floor": {
		"kind": "ground",
		"footprint": Vector2i(10, 10),
		"anchor": Vector2(0.5, 0.5),
	},
	"grass-ground": {
		"kind": "ground",
		"footprint": Vector2i(7, 7),
		"anchor": Vector2(0.5, 0.5),
	},
	"crosswalk": {
		"kind": "ground",
		"footprint": Vector2i(7, 7),
		"anchor": Vector2(0.5, 0.5),
		"connections": ["nw", "se"],
	},
	"digital-terminal": {
		"kind": "prop",
		"visual_width_cells": 1.25,
		"anchor": Vector2(0.5, 0.96),
		"collision": Vector2i(1, 1),
	},
	"public-bench": {
		"kind": "prop",
		"visual_width_cells": 2.25,
		"anchor": Vector2(0.5, 0.92),
		"collision": Vector2i(2, 1),
	},
	"trash-bin": {
		"kind": "prop",
		"visual_width_cells": 1.0,
		"anchor": Vector2(0.5, 0.95),
		"collision": Vector2i(1, 1),
	},
	"planter": {
		"kind": "prop",
		"visual_width_cells": 2.0,
		"anchor": Vector2(0.5, 0.92),
		"collision": Vector2i(2, 1),
	},
	"small-tree": {
		"kind": "prop",
		"visual_width_cells": 2.5,
		"anchor": Vector2(0.5, 0.96),
		"collision": Vector2i(1, 1),
	},
	"medium-tree": {
		"kind": "prop",
		"visual_width_cells": 3.0,
		"anchor": Vector2(0.5, 0.965),
		"collision": Vector2i(1, 1),
	},
}


static func has(asset_name: String) -> bool:
	return ASSETS.has(asset_name)


static func spec(asset_name: String) -> Dictionary:
	var raw = ASSETS.get(asset_name, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func kind(asset_name: String) -> String:
	return String(spec(asset_name).get("kind", ""))


static func footprint(asset_name: String) -> Vector2i:
	var value = spec(asset_name).get("footprint", Vector2i.ONE)
	return Vector2i(value)


static func anchor(asset_name: String) -> Vector2:
	var value = spec(asset_name).get("anchor", Vector2(0.5, 0.5))
	return Vector2(value)


static func collision_footprint(asset_name: String) -> Vector2i:
	var value = spec(asset_name).get("collision", Vector2i.ZERO)
	return Vector2i(value)


static func logical_visual_width(asset_name: String) -> float:
	var asset_spec := spec(asset_name)
	if String(asset_spec.get("kind", "")) == "ground":
		var ground_footprint := Vector2i(asset_spec.get("footprint", Vector2i.ONE))
		return maxf(1.0, float(ground_footprint.x) * TILE_WIDTH)
	return maxf(1.0, float(asset_spec.get("visual_width_cells", 1.0)) * TILE_WIDTH)


static func road_asset_for(piece: String) -> String:
	return String(ROAD_PIECE_ASSETS.get(piece, ""))


static func supports_road_piece(piece: String) -> bool:
	return not road_asset_for(piece).is_empty()
