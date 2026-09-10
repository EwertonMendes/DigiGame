extends "res://src/BattleController.gd"

# Domain-aware tactical bridge. The base controller still owns turn flow and
# path planning, while movement/stat data now comes from the actual Digimon
# instance bound to each battle actor.


func _load_movement_database() -> void:
	# Intentionally empty. Species metadata is loaded once by DigimonDatabase and
	# each actor exposes its own final MOV, including permanent training bonuses.
	_mov_by_key.clear()


func _movement_for(actor: Node) -> int:
	if actor == null:
		return DEFAULT_MOV
	if actor.has_method("get_final_mov"):
		return maxi(0, int(actor.call("get_final_mov")))
	return super._movement_for(actor)


func get_hud_state() -> Dictionary:
	var state: Dictionary = super.get_hud_state()
	if current_actor == null:
		return state
	if current_actor.has_method("get_display_name"):
		state["actor_name"] = String(current_actor.call("get_display_name"))
	if current_actor.has_method("get_level"):
		state["level"] = int(current_actor.call("get_level"))
	if current_actor.has_method("get_potential"):
		state["potential"] = int(current_actor.call("get_potential"))
	if current_actor.has_method("get_instance_id"):
		state["instance_id"] = String(current_actor.call("get_instance_id"))
	if current_actor.has_method("get_species_seed"):
		state["species_seed"] = String(current_actor.call("get_species_seed"))
	if current_actor.has_method("get_movement_type"):
		state["movement_type"] = String(current_actor.call("get_movement_type"))
	return state
