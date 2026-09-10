extends "res://src/battle/SequencedBattleController.gd"

# Combat/timeline events must use the persistent Digimon instance id. Godot's
# Object instance id is process-local and is a poor identifier to pass between
# battle domain and presentation code, especially on Web builds.
func _instance_id(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	if actor.has_method("get_digimon_instance_id"):
		var stable_id: String = String(actor.call("get_digimon_instance_id")).strip_edges()
		if not stable_id.is_empty():
			return stable_id
	return str(actor.get_instance_id())


func focus_actor_by_instance_id(instance_id: String) -> void:
	if instance_id.is_empty():
		return
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if _instance_id(actor) != instance_id:
			continue
		var camera := get_viewport().get_camera_2d()
		if camera != null and camera.has_method("focus_on"):
			camera.call("focus_on", actor.global_position)
		return
