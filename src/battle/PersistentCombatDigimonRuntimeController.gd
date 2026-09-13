extends "res://src/battle/CombatDigimonRuntimeController.gd"

const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")

var encounter_definition: BattleEncounterDefinition = null


func configure_encounter(definition: BattleEncounterDefinition) -> void:
	encounter_definition = definition


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

	for descriptor: Dictionary in _enemy_descriptors():
		var species_name := String(descriptor.get("species", ""))
		var species_seed := String(descriptor.get("species_seed", ""))
		var min_level := int(descriptor.get("level_min", descriptor.get("level", 1)))
		var max_level := maxi(min_level, int(descriptor.get("level_max", descriptor.get("level", min_level))))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		var instance: DigimonInstance = null
		if not species_seed.is_empty():
			instance = _factory.create_enemy_by_seed(species_seed, level, profile)
		else:
			instance = _factory.create_enemy_by_name(species_name, level, profile)
		var actor := _spawn_instance_in_zone(instance, false, enemy_candidates, field)
		if actor != null:
			actor.set_meta("encounter_profile", profile.to_lower())
			actor.set_meta("reward_modifier", _encounter_reward_modifier())
		_prepare_actor_for_intro(actor, field)

	orient_battle_actors_toward_opponents()


func _enemy_descriptors() -> Array[Dictionary]:
	if encounter_definition != null and not encounter_definition.enemy_party.is_empty():
		return encounter_definition.enemy_party.duplicate(true)
	var fallback: Array[Dictionary] = []
	for raw_descriptor in ENEMY_ENCOUNTER:
		if raw_descriptor is Dictionary:
			fallback.append((raw_descriptor as Dictionary).duplicate(true))
	return fallback


func _encounter_reward_modifier() -> float:
	return maxf(0.0, encounter_definition.reward_modifier) if encounter_definition != null else 1.0
