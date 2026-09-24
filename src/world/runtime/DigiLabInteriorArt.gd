extends RefCounted
class_name DigiLabInteriorArt

# Authored 1254x1254 source pieces supplied for the DigiLab interior.
# Runtime normalization trims transparent padding, finds the actual floor
# contact band and anchors that contact point directly to the 64x32 world grid.
# The source PNGs remain untouched, preserving their full authored detail.
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

const ALPHA_THRESHOLD := 0.08
const CONTACT_BAND_RATIO := 0.18
const MIN_SCALE := 0.035
const MAX_SCALE := 0.32

static var _metrics_cache: Dictionary = {}


static func create_piece(
	kind: String,
	anchor: Vector2,
	depth_order: int,
	flip_h: bool = false
) -> Sprite2D:
	var texture := piece_texture(kind)
	var metrics := _texture_metrics(texture)
	var used_rect: Rect2i = metrics.get("used_rect", Rect2i())
	var contact_center_x := float(metrics.get("contact_center_x", used_rect.position.x + used_rect.size.x * 0.5))
	var contact_y := float(metrics.get("contact_y", used_rect.end.y - 1))
	var contact_width := maxf(float(metrics.get("contact_width", used_rect.size.x)), 1.0)
	var target_contact_width := _target_contact_width(kind)
	var normalized_scale := clampf(target_contact_width / contact_width, MIN_SCALE, MAX_SCALE)

	var sprite := Sprite2D.new()
	sprite.name = _piece_node_name(kind)
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(used_rect)
	sprite.centered = false
	sprite.flip_h = flip_h
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(normalized_scale, normalized_scale)

	var local_contact_x := contact_center_x - float(used_rect.position.x)
	if flip_h:
		local_contact_x = float(used_rect.size.x) - local_contact_x
	var local_contact_y := contact_y - float(used_rect.position.y)
	sprite.position = anchor - Vector2(
		local_contact_x * normalized_scale,
		local_contact_y * normalized_scale
	)
	sprite.z_index = clampi(depth_order, -4000, 4000)

	# Metadata is deliberately kept on the runtime node so regression tests can
	# verify the normalization contract without depending on source canvas
	# margins or hard-coded editor positions.
	sprite.set_meta("digilab_wall_piece", kind)
	sprite.set_meta("grid_anchor", anchor)
	sprite.set_meta("source_used_rect", used_rect)
	sprite.set_meta("source_contact_width", contact_width)
	sprite.set_meta("target_contact_width", target_contact_width)
	sprite.set_meta("normalized_contact_width", contact_width * normalized_scale)
	sprite.set_meta("normalized_scale", normalized_scale)
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


static func _target_contact_width(kind: String) -> float:
	match kind:
		KIND_STRAIGHT_LEFT, KIND_STRAIGHT_RIGHT:
			return 40.0
		KIND_INNER_CORNER, KIND_OUTER_CORNER:
			return 62.0
		KIND_JOINT_PILLAR:
			return 28.0
		KIND_DOOR_FRAME:
			return 116.0
		KIND_LOW_DIVIDER:
			# The generated divider has a narrower opaque contact band than its
			# visible rail. A slightly wider target lets adjacent 64x32 modules
			# meet cleanly instead of reading as detached fence posts.
			return 56.0
		KIND_WALL_END_CAP:
			return 34.0
		_:
			return 40.0


static func _piece_node_name(kind: String) -> String:
	return "Wall_%s" % kind.to_pascal_case()


static func _texture_metrics(texture: Texture2D) -> Dictionary:
	var path := texture.resource_path
	if _metrics_cache.has(path):
		return _metrics_cache[path]

	var image := texture.get_image()
	if image == null or image.is_empty():
		var fallback := {
			"used_rect": Rect2i(0, 0, texture.get_width(), texture.get_height()),
			"contact_center_x": float(texture.get_width()) * 0.5,
			"contact_y": float(texture.get_height() - 1),
			"contact_width": float(texture.get_width()),
		}
		_metrics_cache[path] = fallback
		return fallback

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		used_rect = Rect2i(0, 0, image.get_width(), image.get_height())

	var band_height := maxi(8, int(round(float(used_rect.size.y) * CONTACT_BAND_RATIO)))
	var scan_start_y := maxi(used_rect.position.y, used_rect.end.y - band_height)
	var min_x := used_rect.end.x
	var max_x := used_rect.position.x
	var max_y := used_rect.position.y
	var found := false

	for y in range(scan_start_y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			if image.get_pixel(x, y).a < ALPHA_THRESHOLD:
				continue
			found = true
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if not found:
		min_x = used_rect.position.x
		max_x = used_rect.end.x - 1
		max_y = used_rect.end.y - 1

	var metrics := {
		"used_rect": used_rect,
		"contact_center_x": (float(min_x) + float(max_x)) * 0.5,
		"contact_y": float(max_y),
		"contact_width": float(maxi(max_x - min_x + 1, 1)),
	}
	_metrics_cache[path] = metrics
	return metrics
