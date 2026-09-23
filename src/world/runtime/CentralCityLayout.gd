extends RefCounted
class_name CentralCityLayout

const SECTION_SIZE := 14
const MODULE_PITCH := 7

# The current kit only contains a straight road module. The layout therefore
# authors one clean boulevard split around Central Plaza. Corner/T/intersection
# slots are already represented by CentralCityAssetCatalog and can be populated
# later without replacing this layout system.
const SERVICE_THEMES := ["digilab", "hospital", "training", "market", "archive"]
const SIDEWALK_PLATFORM_THEMES := [
	"residential",
	"training",
	"market",
	"archive",
	"gate",
	"canal",
]


static func ground_specs_for_section(section_coord: Vector2i, theme: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []

	# sidewalk.png is a finished raised urban platform, not a seamless pavement
	# texture. Use one deliberate platform as the visual lot for selected
	# non-boulevard districts; the city-wide connective surface stays in the
	# batched pavement foundation.
	if section_coord.y != 0 and theme in SIDEWALK_PLATFORM_THEMES:
		specs.append(_ground("sidewalk", Vector2i(7, 7), -1175))

	# Garden art is also an authored destination module, never a section-sized
	# tint. Keeping one inset per garden district gives parks a readable footprint
	# while the surrounding pavement still connects every section.
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
			# Keep garden furniture on the authored park footprint rather than
			# scattering it over the connective pavement.
			specs.append(_prop("medium-tree", Vector2i(5, 6), true, true))
			specs.append(_prop("small-tree", Vector2i(9, 8), true, true))
			specs.append(_prop("public-bench", Vector2i(7, 10), true))
			specs.append(_prop("planter", Vector2i(5, 9), true))
			specs.append(_prop("trash-bin", Vector2i(10, 7), true))
		"residential":
			# These props sit on the single authored sidewalk platform. The rest
			# of the section stays open for the future custom building footprint.
			specs.append(_prop("small-tree", Vector2i(5, 6), true, true))
			specs.append(_prop("public-bench", Vector2i(9, 9), true))
			specs.append(_prop("planter", Vector2i(6, 9), true))
		"gate":
			specs.append(_prop("planter", Vector2i(5, 5), true))
			specs.append(_prop("planter", Vector2i(9, 9), true))
		"canal":
			# The canal itself is deferred until its bespoke art exists. The
			# temporary district uses one urban platform, keeping its furniture
			# visually grounded instead of floating on empty foundation.
			specs.append(_prop("small-tree", Vector2i(5, 7), true, true))
			specs.append(_prop("public-bench", Vector2i(9, 9), true))
		_:
			if theme in SERVICE_THEMES:
				specs.append(_prop("small-tree", Vector2i(5, 9), true, true))
				specs.append(_prop("planter", Vector2i(9, 9), true))

	return specs


static func is_service_theme(theme: String) -> bool:
	return theme in SERVICE_THEMES


static func service_terminal_cell(section_coord: Vector2i, _theme: String) -> Vector2i:
	# DigiLab/Hospital currently sit on the straight boulevard, so keep their
	# temporary terminals safely above the road. Other service terminals sit on
	# their authored sidewalk platform.
	if section_coord.y == 0:
		return Vector2i(10, 2)
	return Vector2i(9, 5)


static func service_approach_cell(section_coord: Vector2i, _theme: String) -> Vector2i:
	if section_coord.y == 0:
		return Vector2i(9, 3)
	return Vector2i(8, 6)


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
