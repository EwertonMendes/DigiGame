extends Node2D
class_name WorldInteractable

var action_id := ""
var prompt := "INTERACT"
var payload: Dictionary = {}
var interaction_radius := 78.0
var priority := 0
var enabled := true


func configure(
	next_action_id: String,
	next_prompt: String,
	next_payload: Dictionary = {},
	radius: float = 78.0,
	next_priority: int = 0
) -> void:
	action_id = next_action_id
	prompt = next_prompt
	payload = next_payload.duplicate(true)
	interaction_radius = maxf(16.0, radius)
	priority = next_priority


func _ready() -> void:
	add_to_group("world_interactable")


func can_interact(player: Node2D) -> bool:
	return enabled and player != null and global_position.distance_to(player.global_position) <= interaction_radius
