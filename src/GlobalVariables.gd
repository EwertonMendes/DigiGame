extends Node

var SelectedTileCoords := Vector2i.ZERO
var DebugMode := false

func _process(_delta: float) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var blocks := main.get_node_or_null("Blocks")
	if blocks != null:
		SelectedTileCoords = blocks.selectedTile
