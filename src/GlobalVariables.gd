extends Node

var SelectedTileCoords := Vector2i.ZERO
var DebugMode := false
var TouchInputActive := false

var _active_touches: Dictionary = {}

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touches[touch.index] = true
		else:
			_active_touches.erase(touch.index)
		TouchInputActive = not _active_touches.is_empty()

func _process(_delta: float) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var blocks := main.get_node_or_null("Blocks")
	if blocks != null:
		SelectedTileCoords = blocks.selectedTile
