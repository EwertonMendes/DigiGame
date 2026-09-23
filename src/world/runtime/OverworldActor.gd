extends "res://src/world/HubActor.gd"
class_name OverworldActor


func _try_move(offset: Vector2) -> void:
	if offset.length_squared() <= 0.000001:
		return
	var candidate := global_position + offset
	if _world_controller != null and _world_controller.has_method("can_actor_move_to"):
		if not bool(_world_controller.call("can_actor_move_to", candidate, self)):
			var horizontal := global_position + Vector2(offset.x, 0.0)
			var vertical := global_position + Vector2(0.0, offset.y)
			if absf(offset.x) > 0.001 and bool(_world_controller.call("can_actor_move_to", horizontal, self)):
				offset = Vector2(offset.x, 0.0)
			elif absf(offset.y) > 0.001 and bool(_world_controller.call("can_actor_move_to", vertical, self)):
				offset = Vector2(0.0, offset.y)
			else:
				velocity = Vector2.ZERO
				world_position_changed.emit(global_position)
				return

	var collision := move_and_collide(offset)
	if collision != null:
		var slide := collision.get_remainder().slide(collision.get_normal())
		if slide.length_squared() > 0.0001:
			move_and_collide(slide)
	world_position_changed.emit(global_position)
