extends "res://src/battle/CombatDigimonRuntimeController.gd"


func _spawn_demo_rosters() -> void:
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("grid_to_world"):
		# The full battle scene always has a field. Keep the inherited fallback for
		# isolated controller tests where persistent deployment is irrelevant.
		super._spawn_demo_rosters()
		return

	var player_candidates := _spawn_zone_candidates(field, true)
	var enemy_candidates := _spawn_zone_candidates(field, false)
	_shuffle_grids(player_candidates)
	_shuffle_grids(enemy_candidates)

	var persistent_party: Array[DigimonInstance] = OverworldState.get_active_instances()
	for instance: DigimonInstance in persistent_party:
		var actor := _spawn_instance_in_zone(instance, true, player_candidates, field)
		_prepare_actor_for_intro(actor, field)

	for descriptor in ENEMY_ENCOUNTER:
		var species_name := String(descriptor.get("species", ""))
		var min_level := int(descriptor.get("level_min", 1))
		var max_level := maxi(min_level, int(descriptor.get("level_max", min_level)))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		var instance: DigimonInstance = _factory.create_enemy_by_name(species_name, level, profile)
		var actor := _spawn_instance_in_zone(instance, false, enemy_candidates, field)
		if actor != null:
			actor.set_meta("encounter_profile", profile.to_lower())
		_prepare_actor_for_intro(actor, field)

	orient_battle_actors_toward_opponents()
