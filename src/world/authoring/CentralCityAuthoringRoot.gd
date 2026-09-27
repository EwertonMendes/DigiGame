@tool
extends Node2D
class_name CentralCityAuthoringRoot

const AUTHORING_DATA = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const CITY_TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const CITY_LAYOUT = preload("res://src/world/runtime/CentralCityUrbanLayout.gd")
const WORLD_AREA_SCRIPT = preload("res://src/world/runtime/WorldAreaScene.gd")
const LIGHTING_SCRIPT = preload("res://src/world/runtime/WorldLightingSystem.gd")

const AUTHORING_CONTAINERS := [
	"Sections",
	"Levels",
	"Boundaries",
	"Roads",
	"Surfaces",
	"GroundOverrides",
	"Transitions",
	"Buildings",
	"Landscapes",
	"Props",
]
const SIGNATURE_POLL_SECONDS := 0.20
const DEFAULT_REBUILD_DELAY_SECONDS := 0.42

@export var area_id := "central_city"
@export var region_id := "central_city"
@export var display_name := "Central City"
@export var subtitle := "Recovery District · continuous overworld"
@export var section_size := 14
@export_category("Editor Preview")
@export var show_runtime_preview := true:
	set(value):
		show_runtime_preview = value
		if Engine.is_editor_hint() and is_inside_tree():
			if value:
				_mark_preview_dirty(true)
			else:
				_clear_runtime_preview()
@export var show_edit_overlays := false:
	set(value):
		show_edit_overlays = value
		if Engine.is_editor_hint() and is_inside_tree():
			_apply_overlay_visibility()
@export var auto_refresh_preview := true
@export_range(0.0, 23.75, 0.25) var preview_hour := 12.0:
	set(value):
		preview_hour = fposmod(value, 24.0)
		if Engine.is_editor_hint() and _preview_lighting != null and is_instance_valid(_preview_lighting):
			_preview_lighting.call("set_preview_time_hours", preview_hour)
@export_range(0.15, 2.0, 0.05) var rebuild_delay_seconds := DEFAULT_REBUILD_DELAY_SECONDS
@export var editor_notes := "The viewport renders the same Central City runtime builders used by the game. Enable Show Edit Overlays only while editing handles."

var _preview_root: Node2D = null
var _preview_area: Node2D = null
var _preview_lighting: Node2D = null
var _signature_elapsed := 0.0
var _dirty_elapsed := 0.0
var _last_signature := 0
var _preview_dirty := false
var _rebuild_in_progress := false
var _rebuild_again := false
var _pending_snapshot: Dictionary = {}


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Authoring nodes are editor data only. Runtime systems parse this scene
		# once into compact dictionaries, then this complete subtree disappears.
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return

	set_process(true)
	_apply_overlay_visibility()
	_pending_snapshot = AUTHORING_DATA.snapshot_from_root(self)
	_last_signature = hash(_pending_snapshot)
	_mark_preview_dirty(true)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not auto_refresh_preview:
		return

	_signature_elapsed += delta
	if _signature_elapsed >= SIGNATURE_POLL_SECONDS:
		_signature_elapsed = 0.0
		var snapshot := AUTHORING_DATA.snapshot_from_root(self)
		var signature := hash(snapshot)
		if signature != _last_signature:
			_last_signature = signature
			_pending_snapshot = snapshot
			_preview_dirty = true
			_dirty_elapsed = 0.0
		elif _preview_dirty:
			_dirty_elapsed += SIGNATURE_POLL_SECONDS

	if _preview_dirty and _dirty_elapsed >= rebuild_delay_seconds:
		_request_runtime_preview_rebuild()


func _mark_preview_dirty(immediate: bool = false) -> void:
	if not Engine.is_editor_hint():
		return
	_pending_snapshot = AUTHORING_DATA.snapshot_from_root(self)
	_last_signature = hash(_pending_snapshot)
	_preview_dirty = true
	_dirty_elapsed = rebuild_delay_seconds if immediate else 0.0
	if immediate:
		call_deferred("_request_runtime_preview_rebuild")


func _request_runtime_preview_rebuild() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not show_runtime_preview:
		_clear_runtime_preview()
		_preview_dirty = false
		return
	if _rebuild_in_progress:
		_rebuild_again = true
		return
	_rebuild_runtime_preview()


func _rebuild_runtime_preview() -> void:
	if _rebuild_in_progress or not Engine.is_editor_hint() or not is_inside_tree():
		return
	_rebuild_in_progress = true
	_preview_dirty = false
	_dirty_elapsed = 0.0

	var snapshot := (
		_pending_snapshot.duplicate(true)
		if not _pending_snapshot.is_empty()
		else AUTHORING_DATA.snapshot_from_root(self)
	)
	_clear_runtime_preview()

	# Feed the exact current, unsaved editor state into the same runtime builders.
	# The override exists only for this build and is cleared immediately after it.
	AUTHORING_DATA.set_preview_snapshot(snapshot)
	CITY_TOPOLOGY.clear_cache()
	CITY_LAYOUT.clear_cache()

	var preview_container := Node2D.new()
	preview_container.name = "__RuntimePreview"
	preview_container.set_meta("central_city_editor_preview", true)
	add_child(preview_container, false, Node.INTERNAL_MODE_BACK)
	_preview_root = preview_container

	var preview = WORLD_AREA_SCRIPT.new()
	preview.name = "Area"
	preview_container.add_child(preview)
	_preview_area = preview as Node2D

	var area_value = snapshot.get("area", {})
	var area_definition := (
		(area_value as Dictionary).duplicate(true)
		if area_value is Dictionary
		else {}
	)
	var configured := false
	if not area_definition.is_empty():
		configured = bool(await preview.configure(area_definition, null, null))

	if configured and is_instance_valid(preview):
		var lighting = LIGHTING_SCRIPT.new()
		lighting.name = "Lighting"
		preview_container.add_child(lighting)
		_preview_lighting = lighting as Node2D
		lighting.configure(null)
		lighting.set_preview_time_hours(preview_hour)
		# The preview is static until authoring data changes, so there is no
		# reason to run the lighting discovery/culling loop every editor frame.
		lighting.process_mode = Node.PROCESS_MODE_DISABLED

	AUTHORING_DATA.clear_preview_snapshot()
	CITY_TOPOLOGY.clear_cache()
	CITY_LAYOUT.clear_cache()

	if not configured and is_instance_valid(preview_container):
		preview_container.queue_free()
		_preview_root = null
		_preview_area = null
		_preview_lighting = null
	elif configured and is_instance_valid(preview):
		print("[CentralCityAuthoring] WYSIWYG preview ready sections=%d nodes=%d" % [
			int(preview.get_section_count()),
			int(preview.get_runtime_node_count()),
		])

	_apply_overlay_visibility()
	_rebuild_in_progress = false
	if _rebuild_again:
		_rebuild_again = false
		_mark_preview_dirty(true)


func _clear_runtime_preview() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.queue_free()
	_preview_root = null
	_preview_area = null
	_preview_lighting = null


func _apply_overlay_visibility() -> void:
	for container_name: String in AUTHORING_CONTAINERS:
		var container := get_node_or_null(container_name)
		if container is CanvasItem:
			(container as CanvasItem).visible = show_edit_overlays
