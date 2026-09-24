extends RefCounted
class_name DigiLabInteriorArt

# DigiLab wall sources are authored as 1254x1254 transparent PNGs.
# They are normalized as ONE coherent kit:
# - trim transparent padding deterministically
# - derive ONE canonical uniform scale from wall-straight-right
# - reuse that exact scale for every full-size/low wall asset
# - position pieces by explicit floor connectors, never by opaque-width guesses
# - never rotate/flip a source at runtime
#
# This keeps all pieces in the same visual scale and makes their grid placement
# a data contract instead of a heuristic.
const WALL_STRAIGHT_LEFT = preload("res://assets/world/tblack/digilab/wall/wall-straight-left.png")
const WALL_STRAIGHT_RIGHT = preload("res://assets/world/tblack/digilab/wall/wall-straight-right.png")
const INNER_CORNER = preload("res://assets/world/tblack/digilab/wall/inner-corner.png")
const OUTER_CORNER = preload("res://assets/world/tblack/digilab/wall/outer-corner.png")
const JOINT_PILLAR = preload("res://assets/world/tblack/digilab/wall/joint-pillar.png")
const DOOR_FRAME = preload("res://assets/world/tblack/digilab/wall/door-frame.png")
const LOW_DIVIDER = preload("res://assets/world/tblack/digilab/wall/low-divider.png")
const WALL_END_CAP = preload("res://assets/world/tblack/digilab/wall/wall-end-cap.png")

const KIND_STRAIGHT_LEFT := "straight_left"
const KIND_STRAIGHT_RIGHT := "straight_right"
const KIND_INNER_CORNER := "inner_corner"
const KIND_OUTER_CORNER := "outer_corner"
const KIND_JOINT_PILLAR := "joint_pillar"
const KIND_DOOR_FRAME := "door_frame"
const KIND_LOW_DIVIDER := "low_divider"
const KIND_WALL_END_CAP := "wall_end_cap"

const SOURCE_CANVAS_SIZE := Vector2i(1254, 1254)

# The right straight wall is the master scale reference. Its two authored base
# connectors are mapped to exactly 3.625 grid cells on the X axis. Every other
# asset reuses the resulting uniform scale unchanged.
const MASTER_GRID_SPAN := 3.625
const MASTER_ANCHOR_FRAC := Vector2(0.075, 0.455)
const MASTER_END_FRAC := Vector2(0.905, 0.900)

static var _canonical_scale_cache := -1.0
static var _normalized_cache: Dictionary = {}


static func create_piece(
	kind: String,
	world_anchor: Vector2,
	grid_anchor: Vector2,
	depth_order: int
) -> Sprite2D:
	var normalized := _normalized_piece(kind)
	var sprite := Sprite2D.new()
	sprite.name = "Wall_%s" % kind.to_pascal_case()
	sprite.texture = normalized.texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = world_anchor - normalized.anchor_px
	sprite.z_index = clampi(depth_order, -4000, 4000)

	sprite.set_meta("digilab_wall_piece", kind)
	sprite.set_meta("grid_anchor_cell", grid_anchor)
	sprite.set_meta("source_path", piece_texture(kind).resource_path)
	sprite.set_meta("source_canvas_size", SOURCE_CANVAS_SIZE)
	sprite.set_meta("trimmed_source_rect", normalized.source_rect)
	sprite.set_meta("canonical_scale", normalized.scale)
	sprite.set_meta("normalized_size", normalized.size)
	sprite.set_meta("anchor_px", normalized.anchor_px)
	sprite.set_meta("connector_deltas", connector_deltas(kind))
	sprite.set_meta("normalization_contract", "trim+single-master-scale+explicit-connectors")
	return sprite


static func piece_texture(kind: String) -> Texture2D:
	match kind:
		KIND_STRAIGHT_LEFT:
			return WALL_STRAIGHT_LEFT
		KIND_STRAIGHT_RIGHT:
			return WALL_STRAIGHT_RIGHT
		KIND_INNER_CORNER:
			return INNER_CORNER
		KIND_OUTER_CORNER:
			return OUTER_CORNER
		KIND_JOINT_PILLAR:
			return JOINT_PILLAR
		KIND_DOOR_FRAME:
			return DOOR_FRAME
		KIND_LOW_DIVIDER:
			return LOW_DIVIDER
		KIND_WALL_END_CAP:
			return WALL_END_CAP
		_:
			push_error("Unknown DigiLab wall piece: %s" % kind)
			return WALL_STRAIGHT_RIGHT


static func connector_deltas(kind: String) -> Array[Vector2]:
	match kind:
		KIND_STRAIGHT_RIGHT:
			return [Vector2(MASTER_GRID_SPAN, 0.0)]
		KIND_STRAIGHT_LEFT:
			return [Vector2(0.0, 3.5)]
		KIND_INNER_CORNER:
			return [Vector2(2.5, 0.0), Vector2(0.0, 2.5)]
		KIND_OUTER_CORNER:
			return [Vector2(-2.5, 0.0), Vector2(0.0, -2.5)]
		KIND_DOOR_FRAME:
			return [Vector2(3.0, 0.0)]
		KIND_LOW_DIVIDER:
			return [Vector2(3.75, 0.0)]
		KIND_WALL_END_CAP:
			return [Vector2(0.0, 3.5)]
		KIND_JOINT_PILLAR:
			return []
		_:
			return []


static func _normalized_piece(kind: String) -> Dictionary:
	if _normalized_cache.has(kind):
		return _normalized_cache[kind]

	var source := piece_texture(kind)
	var image := source.get_image()
	if image == null or image.is_empty():
		push_error("Unable to read DigiLab wall source: %s" % source.resource_path)
		return {
			"texture": source,
			"anchor_px": Vector2.ZERO,
			"source_rect": Rect2i(0, 0, source.get_width(), source.get_height()),
			"scale": 1.0,
			"size": Vector2(source.get_width(), source.get_height()),
		}

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		used_rect = Rect2i(Vector2i.ZERO, image.get_size())

	var cropped := image.get_region(used_rect)
	var canonical_scale := _canonical_scale()
	var target_size := Vector2i(
		maxi(1, int(round(float(cropped.get_width()) * canonical_scale))),
		maxi(1, int(round(float(cropped.get_height()) * canonical_scale)))
	)
	cropped.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(cropped)

	var anchor_frac := _anchor_fraction(kind)
	var anchor_px := Vector2(
		anchor_frac.x * float(target_size.x),
		anchor_frac.y * float(target_size.y)
	)

	var normalized := {
		"texture": texture,
		"anchor_px": anchor_px,
		"source_rect": used_rect,
		"scale": canonical_scale,
		"size": Vector2(target_size),
	}
	_normalized_cache[kind] = normalized
	return normalized


static func _canonical_scale() -> float:
	if _canonical_scale_cache > 0.0:
		return _canonical_scale_cache

	var image := WALL_STRAIGHT_RIGHT.get_image()
	if image == null or image.is_empty():
		_canonical_scale_cache = 0.125
		return _canonical_scale_cache

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		used_rect = Rect2i(Vector2i.ZERO, image.get_size())

	var source_size := Vector2(used_rect.size)
	var source_anchor := Vector2(
		MASTER_ANCHOR_FRAC.x * source_size.x,
		MASTER_ANCHOR_FRAC.y * source_size.y
	)
	var source_end := Vector2(
		MASTER_END_FRAC.x * source_size.x,
		MASTER_END_FRAC.y * source_size.y
	)
	var source_distance := maxf(source_anchor.distance_to(source_end), 1.0)

	# One X-grid cell advances (32, 16) pixels in the 64x32 isometric grid.
	var target_distance := Vector2(32.0 * MASTER_GRID_SPAN, 16.0 * MASTER_GRID_SPAN).length()
	_canonical_scale_cache = target_distance / source_distance
	return _canonical_scale_cache


static func _anchor_fraction(kind: String) -> Vector2:
	# Fractions are measured against each trimmed authored asset. They represent
	# the floor connector where the piece joins the grid, not its image center.
	match kind:
		KIND_STRAIGHT_RIGHT:
			return MASTER_ANCHOR_FRAC
		KIND_STRAIGHT_LEFT:
			return Vector2(0.915, 0.455)
		KIND_INNER_CORNER:
			return Vector2(0.500, 0.665)
		KIND_OUTER_CORNER:
			return Vector2(0.500, 0.855)
		KIND_JOINT_PILLAR:
			return Vector2(0.500, 0.900)
		KIND_DOOR_FRAME:
			return Vector2(0.245, 0.650)
		KIND_LOW_DIVIDER:
			return Vector2(0.120, 0.505)
		KIND_WALL_END_CAP:
			return Vector2(0.855, 0.500)
		_:
			return Vector2(0.5, 1.0)
