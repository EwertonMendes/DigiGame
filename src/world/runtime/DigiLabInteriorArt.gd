extends RefCounted
class_name DigiLabInteriorArt

# The original 1254x1254 AI-authored PNGs remain preserved as visual source
# art. Runtime rendering uses grid-native SVGs with explicit anchors/spans.
# Nothing is resized, mirrored, rotated or inferred from transparent margins.
const WALL_STRAIGHT_LEFT = preload("res://assets/world/tblack/digilab/wall/runtime/wall-straight-left.svg")
const WALL_STRAIGHT_RIGHT = preload("res://assets/world/tblack/digilab/wall/runtime/wall-straight-right.svg")
const CORNER_BACK_LEFT = preload("res://assets/world/tblack/digilab/wall/runtime/corner-back-left.svg")
const CORNER_BACK_RIGHT = preload("res://assets/world/tblack/digilab/wall/runtime/corner-back-right.svg")
const CORNER_FRONT_LEFT = preload("res://assets/world/tblack/digilab/wall/runtime/corner-front-left.svg")
const CORNER_FRONT_RIGHT = preload("res://assets/world/tblack/digilab/wall/runtime/corner-front-right.svg")
const JOINT_PILLAR = preload("res://assets/world/tblack/digilab/wall/runtime/joint-pillar.svg")
const DOOR_FRAME = preload("res://assets/world/tblack/digilab/wall/runtime/door-frame.svg")
const LOW_DIVIDER = preload("res://assets/world/tblack/digilab/wall/runtime/low-divider.svg")
const WALL_END_CAP = preload("res://assets/world/tblack/digilab/wall/runtime/wall-end-cap.svg")

const KIND_STRAIGHT_LEFT := "straight_left"
const KIND_STRAIGHT_RIGHT := "straight_right"
const KIND_CORNER_BACK_LEFT := "corner_back_left"
const KIND_CORNER_BACK_RIGHT := "corner_back_right"
const KIND_CORNER_FRONT_LEFT := "corner_front_left"
const KIND_CORNER_FRONT_RIGHT := "corner_front_right"
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
		"visual_height": WALL_HEIGHT,
	},
	KIND_STRAIGHT_LEFT: {
		"texture": WALL_STRAIGHT_LEFT,
		"anchor_px": Vector2(96.0, 104.0),
		"span": Vector2(0.0, 1.0),
		"priority": 0,
		"visual_height": WALL_HEIGHT,
	},
	KIND_CORNER_BACK_LEFT: {
		"texture": CORNER_BACK_LEFT,
		"anchor_px": Vector2(90.0, 140.0),
		"span": Vector2.ZERO,
		"priority": 30,
		"visual_height": WALL_HEIGHT,
	},
	KIND_CORNER_BACK_RIGHT: {
		"texture": CORNER_BACK_RIGHT,
		"anchor_px": Vector2(90.0, 140.0),
		"span": Vector2.ZERO,
		"priority": 30,
		"visual_height": WALL_HEIGHT,
	},
	KIND_CORNER_FRONT_LEFT: {
		"texture": CORNER_FRONT_LEFT,
		"anchor_px": Vector2(90.0, 140.0),
		"span": Vector2.ZERO,
		"priority": 30,
		"visual_height": WALL_HEIGHT,
	},
	KIND_CORNER_FRONT_RIGHT: {
		"texture": CORNER_FRONT_RIGHT,
		"anchor_px": Vector2(90.0, 140.0),
		"span": Vector2.ZERO,
		"priority": 30,
		"visual_height": WALL_HEIGHT,
	},
	KIND_JOINT_PILLAR: {
		"texture": JOINT_PILLAR,
		"anchor_px": Vector2(56.0, 124.0),
		"span": Vector2.ZERO,
		"priority": 15,
		"visual_height": WALL_HEIGHT,
	},
	KIND_DOOR_FRAME: {
		"texture": DOOR_FRAME,
		"anchor_px": Vector2(56.0, 144.0),
		"span": Vector2(4.0, 0.0),
		"priority": 35,
		"visual_height": WALL_HEIGHT,
	},
	KIND_LOW_DIVIDER: {
		"texture": LOW_DIVIDER,
		"anchor_px": Vector2(32.0, 72.0),
		"span": Vector2(1.0, 0.0),
		"priority": 0,
		"visual_height": 34.0,
	},
	KIND_WALL_END_CAP: {
		"texture": WALL_END_CAP,
		"anchor_px": Vector2(48.0, 112.0),
		"span": Vector2.ZERO,
		"priority": 15,
		"visual_height": WALL_HEIGHT,
	},
}


static func create_piece(
	kind: String,
	world_anchor: Vector2,
	grid_anchor: Vector2,
	depth_order: int
) -> Sprite2D:
	var spec := _spec(kind)
	var sprite := Sprite2D.new()
	sprite.name = "Wall_%s" % kind.to_pascal_case()
	sprite.texture = spec["texture"] as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = world_anchor - (spec["anchor_px"] as Vector2)
	sprite.z_index = clampi(depth_order + int(spec["priority"]), -4000, 4000)
	_apply_common_metadata(sprite, kind, grid_anchor, spec)
	return sprite


static func create_batch(
	kind: String,
	world_anchors: Array[Vector2],
	grid_anchors: Array[Vector2],
	depth_order: int
) -> MultiMeshInstance2D:
	assert(world_anchors.size() == grid_anchors.size())
	var spec := _spec(kind)
	var texture := spec["texture"] as Texture2D
	var anchor := spec["anchor_px"] as Vector2
	var size := texture.get_size()

	var vertices := PackedVector3Array([
		Vector3(-anchor.x, -anchor.y, 0.0),
		Vector3(size.x - anchor.x, -anchor.y, 0.0),
		Vector3(size.x - anchor.x, size.y - anchor.y, 0.0),
		Vector3(-anchor.x, size.y - anchor.y, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = mesh
	multimesh.instance_count = world_anchors.size()
	for index in range(world_anchors.size()):
		multimesh.set_instance_transform_2d(
			index,
			Transform2D(0.0, world_anchors[index])
		)

	var batch := MultiMeshInstance2D.new()
	batch.name = "WallBatch_%s" % kind.to_pascal_case()
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	batch.z_index = clampi(depth_order + int(spec["priority"]), -4000, 4000)
	batch.set_meta("digilab_wall_batch", kind)
	batch.set_meta("batch_count", world_anchors.size())
	batch.set_meta("grid_anchors", grid_anchors)
	batch.set_meta("grid_span", spec["span"])
	batch.set_meta("visual_height", float(spec.get("visual_height", WALL_HEIGHT)))
	batch.set_meta("normalization_contract", "grid-native-vector-batch")
	batch.set_meta("source_kind", "runtime_svg")
	return batch


static func connector_deltas(kind: String) -> Array[Vector2]:
	var spec := _spec(kind)
	var span := spec["span"] as Vector2
	if span.is_zero_approx():
		return []
	return [span]


static func piece_texture(kind: String) -> Texture2D:
	return _spec(kind)["texture"] as Texture2D


static func _spec(kind: String) -> Dictionary:
	var spec: Dictionary = SPECS.get(kind, {})
	if spec.is_empty():
		push_error("Unknown DigiLab wall piece: %s" % kind)
		return SPECS[KIND_STRAIGHT_RIGHT]
	return spec


static func _apply_common_metadata(
	sprite: Sprite2D,
	kind: String,
	grid_anchor: Vector2,
	spec: Dictionary
) -> void:
	sprite.set_meta("digilab_wall_piece", kind)
	sprite.set_meta("grid_anchor_cell", grid_anchor)
	sprite.set_meta("grid_span", spec["span"])
	sprite.set_meta("asset_anchor_px", spec["anchor_px"])
	sprite.set_meta("visual_height", float(spec.get("visual_height", WALL_HEIGHT)))
	sprite.set_meta("normalization_contract", "grid-native-vector")
	sprite.set_meta("source_kind", "runtime_svg")
