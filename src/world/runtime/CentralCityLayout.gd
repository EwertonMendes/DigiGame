extends RefCounted
class_name CentralCityLayout

const SECTION_SIZE := 14
const MODULE_PITCH := 7

# The current kit only contains a straight road module. The layout therefore
# authors one clean boulevard split around Central Plaza. Corner/T/intersection
# slots are already represented by CentralCityAssetCatalog and can be populated
# later without replacing this layout system.
const SIDEWALK_CENTERS: Array[Vector2i] = [
	Vector2i(3, 3),
	Vector2i(10, 3),
	Vector2i(3, 10),
	Vector2i(10, 10),
]

const SERVICE_THEMES := ["digilab", "hospital", "training", "market", "archive"]


static func ground_specs_for_section(section_coord: Vector2i, theme: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	# Four 7x7 modules tile each 14x14 authoring section on one deterministic
	# cadence. This removes the old single floating patch and the large gaps it
	# created between sections.
	for cell: Vector2i in SIDEWALK_CENTERS:
		specs.append(_ground("sidewalk", cell, -1178))

	# Greenery is an intentional inset over pavement, never a whole-section tint.
	if theme == "garden":
		specs.append(_ground("grass-ground", Vector2i(7, 7), -1174))

	# Only straight road pieces are used until dedicated corner/intersection art
	# exists. The boulevard ends cleanly at the plaza instead of faking junctions.
	if section_coord.y == 0 and section_coord.x != 0:
		specs.append(_ground("road", Vector2i(4, 7), -1166, true))
		specs.append(_ground("road", Vector2i(11, 7), -1166, true))

	if section_coord == Vector2i.ZERO:
		specs.append(_ground("plaza-floor", Vector2i(7, 7), -1168))
		specs.append(_ground("crosswalk", Vector2i(1, 7), -1158, true))
		specs.append(_ground("crosswalk", Vector2i(13, 7), -1158, true))

	return specs


static func prop_specs_for_section(section_coord: Vector2i, theme: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	match theme:
		"plaza":
			specs.append(_prop("medium-tree", Vector2i(2, 11), true, true))
			specs.append(_prop("medium-tree", Vector2i(11, 2), true, true))
			specs.append(_prop("public-bench", Vector2i(9, 11), true))
			specs.append(_prop("planter", Vector2i(3, 3), true))
		"garden":
			specs.append(_prop("medium-tree", Vector2i(3, 3), true, true))
			specs.append(_prop("small-tree", Vector2i(10, 10), true, true))
			specs.append(_prop("public-bench", Vector2i(7, 11), true))
			specs.append(_prop("planter", Vector2i(8, 3), true))
			specs.append(_prop("trash-bin", Vector2i(11, 6), true))
		"residential":
			# Keep future building lots visually calm and put furniture near their
			# edges so later building footprints do not require another redesign.
			specs.append(_prop("small-tree", Vector2i(3, 11), true, true))
			specs.append(_prop("public-bench", Vector2i(10, 11), true))
			specs.append(_prop("planter", Vector2i(10, 3), true))
		"gate":
			specs.append(_prop("planter", Vector2i(3, 3), true))
			specs.append(_prop("planter", Vector2i(10, 10), true))
		"canal":
			# The canal art is intentionally deferred with the rest of the bespoke
			# city kit. Until then this section remains connected urban pavement.
			specs.append(_prop("small-tree", Vector2i(3, 10), true, true))
			specs.append(_prop("public-bench", Vector2i(10, 10), true))
		_:
			if theme in SERVICE_THEMES:
				specs.append(_prop("small-tree", Vector2i(3, 11), true, true))
				specs.append(_prop("planter", Vector2i(9, 11), true))

	return specs


static func is_service_theme(theme: String) -> bool:
	return theme in SERVICE_THEMES


static func service_terminal_cell(_theme: String) -> Vector2i:
	return Vector2i(10, 3)


static func service_approach_cell(_theme: String) -> Vector2i:
	return Vector2i(9, 4)


static func service_definition(theme: String) -> Dictionary:
	match theme:
		"digilab":
			return {"service": "digilab", "title": "DIGILAB", "accent": Color(0.28, 0.88, 1.0)}
		"hospital":
			return {"service": "hospital", "title": "DIGI HOSPITAL", "accent": Color(0.66, 0.96, 1.0)}
		"training":
			return {"service": "training", "title": "TRAINING CENTER", "accent": Color(0.56, 0.95, 0.43)}
		"market":
			return {"service": "shop", "title": "DATA MARKET", "accent": Color(1.0, 0.78, 0.28)}
		"archive":
			return {"service": "archive", "title": "DIGITAL ARCHIVE", "accent": Color(0.72, 0.52, 1.0)}
		_:
			return {}


static func reserved_building_lot(theme: String) -> Rect2i:
	# These reservations are deliberately data-only for now. When custom
	# buildings arrive, they can claim these lots without touching road,
	# sidewalk or prop placement rules.
	match theme:
		"digilab", "hospital", "archive":
			return Rect2i(Vector2i(2, 2), Vector2i(7, 6))
		"training", "market":
			return Rect2i(Vector2i(2, 2), Vector2i(6, 7))
		"residential":
			return Rect2i(Vector2i(2, 2), Vector2i(9, 6))
		_:
			return Rect2i()


static func _ground(asset_name: String, cell: Vector2i, depth: int, flip_h: bool = false) -> Dictionary:
	return {
		"asset": asset_name,
		"cell": cell,
		"depth": depth,
		"flip_h": flip_h,
	}


static func _prop(
	asset_name: String,
	cell: Vector2i,
	blocking: bool,
	tree: bool = false,
	flip_h: bool = false
) -> Dictionary:
	return {
		"asset": asset_name,
		"cell": cell,
		"blocking": blocking,
		"tree": tree,
		"flip_h": flip_h,
	}
