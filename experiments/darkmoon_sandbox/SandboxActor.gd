extends "res://src/world/runtime/OverworldActor.gd"

# Keep the existing eight-direction input, animation, acceleration and sliding.
# Subdivision also protects thin obstacles if a frame or test requests a long step.
func _try_move(offset: Vector2) -> void:
	var steps := maxi(1, ceili(offset.length() / 4.0))
	for index in range(steps):
		super._try_move(offset / float(steps))


func _update_depth() -> void:
	if _world_controller != null and _world_controller.has_method("resolve_actor_depth"):
		z_index = int(_world_controller.call("resolve_actor_depth",self))
