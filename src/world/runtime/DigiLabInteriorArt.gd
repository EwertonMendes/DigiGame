extends RefCounted
class_name DigiLabInteriorArt

# Runtime DigiLab walls are grid-native vector assets. The original AI-authored
# 1254x1254 PNGs remain preserved as source/reference art, but they are no
# longer used directly by the room renderer.
#
# Every runtime asset has an explicit local floor anchor and grid span. No
# trimming, scale guessing, mirroring or rotation happens in the game.
const WALL_STRAIGHT_LEFT = preload("res://assets/world/tblack/digilab/wall/runtime/wall-straight-left.svg")
const WALL_STRAIGHT_RIGHT = preload("res://assets/world/tblack/digilab/wall/runtime/wall-straight-right.svg")
const INNER_CORNER = preload("res://assets/world/tblack/digilab/wall/runtime/inner-corner.svg")
const OUTER_CORNER = preload("res://assets/world/tblack/digilab/wall/runtime/outer-corner.svg")
const JOINT_PILLAR = preload("res://assets/world/tblack/digilab/wall/runtime/joint-pillar.svg")
const DOOR_FRAME = preload("res://assets/world/tblack/digilab/wall/runtime/door-frame.svg")
const LOW_DIVIDER = preload("res://assets/world/tblack/digilab/wall/runtime/low-divider.svg")
const WALL_END_CAP = preload("res://assets/world/tblack/digilab/wall/runtime/wall-end-cap.svg")

const KIND_STRAIGHT_LEFT := "straight_left"
const KIND_STRAIGHT_RIGHT := "straight_right"
const KIND_INNER_CORNER := "inner_corner"
const KIND_OUTER_CORNER := "outer_corner"
const KIND_JOINT_PILLAR := "joint_pillar"
const KIND_DOOR_FRAME := "door_frame"
const KIND_LOW_DIVIDER := "low_divider"
const KIND_WALL_END_CAP := "wall_end_cap"

const GRID_SIZE := Vector2(64.0, 32.0)
const WALL_HEIGHT := 72.0

const SPECS := {
	KIND_STRAIGHT_RIGHT: {
		"texture": WALL_STRAIGHT_RIGHT,
		"anchor_px": Vector2(32.0, 104.0),
		"span": Vector2(1.0, 0.0),
		"priority": 0,
	},
	KIND_STRAIGHT_LEFT: {
		"texture": WALL_STRAIGHT_LEFT,
		"anchor_px": Vector2(96.0, 104.0),
		"span": Vector2(0.0, 1.0),
		"priority": 0,
	},
	KIND_INNER_CORNER: {
		"texture": INNER_CORNER,
		"anchor_px": Vector2(56.0, 124.0),
		"span": Vector2.ZERO,
		"priority": 20,
	},
	KIND_OUTER_CORNER: {
		"texture": OUTER_CORNER,
		"anchor_px": Vector2(56.0, 124.0),
		"span": Vector2.ZERO,
		"priority": 20,
	},
	KIND_JOINT_PILLAR: {
		"texture": JOINT_PILLAR,
		"anchor_px": Vector2(56.0, 124.0),
		"span": Vector2.ZERO,
		"priority": 15,
	},
	KIND_DOOR_FRAME: {
		"texture": DOOR_FRAME,
		"anchor_px": Vector2(36.0, 138.0),
		"span": Vector2(4.0, 0.0),
		"priority": 25,
	},
	KIND_LOW_DIVIDER: {
		"texture": LOW_DIVIDER,
		"anchor_px": Vector2(32.0, 72.0),
		"span": Vector2(1.0, 0.0),
		"priority": 0,
	},
	KIND_WALL_END_CAP: {
		"texture": WALL_END_CAP,
		"anchor_px": Vector2(48.0, 112.0),
		"span": Vector2.ZERO,
		"priority": 15,
	},
}


static func create_piece(
	kind: String,
	world_anchor: Vector2,
	grid_anchor: Vector2,
	depth_order: int
) -> Sprite2D:
	var spec: Dictionary = SPECS.get(kind, {})
	if spec.is_empty():
		push_error("Unknown DigiLab wall piece: %s" % kind)
		spec = SPECS[KIND_STRAIGHT_RIGHT]

	var sprite := Sprite2D.new()
	sprite.name = "Wall_%s" % kind.to_pascal_case()
	sprite.texture = spec["texture"] as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = world_anchor - (spec["anchor_px"] as Vector2)
	sprite.z_index = clampi(depth_order + int(spec["priority"]), -4000, 4000)

	sprite.set_meta("digilab_wall_piece", kind)
	sprite.set_meta("grid_anchor_cell", grid_anchor)
	sprite.set_meta("grid_span", spec["span"])
	sprite.set_meta("asset_anchor_px", spec["anchor_px"])
	sprite.set_meta("wall_height", WALL_HEIGHT)
	sprite.set_meta("normalization_contract", "grid-native-vector")
	sprite.set_meta("source_kind", "runtime_svg")
	return sprite


static func connector_deltas(kind: String) -> Array[Vector2]:
	var spec: Dictionary = SPECS.get(kind, {})
	if spec.is_empty():
		return []
	var span := spec["span"] as Vector2
	if span.is_zero_approx():
		return []
	return [span]


static func depth_priority(kind: String) -> int:
	var spec: Dictionary = SPECS.get(kind, {})
	return int(spec.get("priority", 0))


static func piece_texture(kind: String) -> Texture2D:
	var spec: Dictionary = SPECS.get(kind, {})
	if spec.is_empty():
		return WALL_STRAIGHT_RIGHT
	return spec["texture"] as Texture2D
