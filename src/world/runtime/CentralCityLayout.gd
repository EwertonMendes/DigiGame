extends RefCounted
class_name CentralCityLayout

const SECTION_SIZE := 14
const MODULE_PITCH := 7

# The current kit only contains a straight road module. The layout therefore
# authors one clean boulevard split around Central Plaza. Corner/T/intersection
# slots are already represented by CentralCityAssetCatalog and can be populated
# later without replacing this layout system.
const SERVICE_THEMES := ["digilab", "hospital", "training", "market", "archive"]


static func ground_specs_for_section(section_coord: Vector2i, theme: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	# IMPORTANT: sidewalk.png is a finished sidewalk/platform module with its own
	# curb and tactile details. It is not a seamless pavement texture. Repeating
	# it across the map creates the large yellow checkerboard seen in the old
	# preview, so the common city floor is rendered by the batched pavement
	# foundation instead. Tblack ground modules are reserved for authored places.
	if theme == "garden" and section_coord.y != 0:
		specs.append(_ground("grass-ground", Vector2i(7, 7), -1174))

	# Straight-road modules follow one exact 7-cell cadence so adjacent pieces
	# meet edge-to-edge. The dedicated crosswalk tile replaces the road module at
	# each plaza approach instead of being layered on top of another road image.
	if section_coord.y == 0:
		match section_coord.x:
			-2:
				specs.append(_ground("road", Vector2i(4, 7), -1166, true))
				specs.append(_ground("road", Vector2i(11, 7), -1166, true))
			-1:
				specs.append(_ground("road", Vector2i(4, 7), -1166, true))
				specs.append(_ground("crosswalk", Vector2i(11, 7), -1165, true))
			1:
				specs.append(_ground("crosswalk", Vector2i(4, 7), -1165, true))
				specs.append(_ground("road", Vector2i(11, 7), -1166, true))
			2:
				specs.append(_ground("road", Vector2i(4, 7), -1166, true))
				specs.append(_ground("road", Vector2i(11, 7), -1166, true))

	if section_coord == Vector2i.ZERO:
		specs.append(_ground("plaza-floor", Vector2i(7, 7), -1164))

	return specs


static func prop_specs_for_section(section_coord: Vector2i, theme: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	# Keep the straight boulevard visually clean. Its module already includes the
	# roadway, curb and narrow pedestrian edge, so adding large furniture next to
	# it makes props appear to sit on top of the road. Service terminals are added
	# separately at a known safe access cell.
	if section_coord.y == 0 and section_coord != Vector2i.ZERO:
		return specs

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
