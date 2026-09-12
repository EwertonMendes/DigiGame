extends "res://src/ui/EvolutionConstellationCanvas.gd"
class_name EvolutionChartCanvas

# Progressive exploration: the current form and all direct Digivolution /
# Degeneration routes are visible immediately. Selecting a connected form then
# advances the trail and reveals only that form's next choices.


func set_graph(graph: Dictionary, current_seed: String, history_edges: Dictionary, goal_seed: String = "", goal_edges: Dictionary = {}) -> void:
	super.set_graph(graph, current_seed, history_edges, goal_seed, goal_edges)
	_branch_open = true
	_rebuild_visible_nodes(current_seed)
	call_deferred("center_on", current_seed)


func _create_node_button(node: Dictionary) -> Button:
	var button := super._create_node_button(node)
	var status := _find_status_label(button)
	if status != null:
		status.visible = false
		status.custom_minimum_size = Vector2.ZERO
	return button
