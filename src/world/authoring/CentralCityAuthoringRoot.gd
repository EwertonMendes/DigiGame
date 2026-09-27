@tool
extends Node2D
class_name CentralCityAuthoringRoot

@export var area_id := "central_city"
@export var region_id := "central_city"
@export var display_name := "Central City"
@export var subtitle := "Recovery District · continuous overworld"
@export var section_size := 14
@export var editor_notes := "Edit children in this scene. Runtime data is derived from these nodes and remains batched/optimized."


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Authoring nodes are editor data only. Runtime systems parse this scene
		# once into compact dictionaries, then the visual authoring subtree is
		# removed so it costs zero ongoing nodes/draw calls on mobile.
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
