extends "res://src/battle/CombatDigimonRuntimeController.gd"

const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")

var encounter_definition: BattleEncounterDefinition = null
var _invalid_battle_abort_pending := false


func configure_encounter(definition: BattleEncounterDefinition) -> void:
	encounter_definition = definition


func _spawn_demo_rosters() -> void:
	_apply_pending_encounter_override()
	var party_error := OverworldState.battle_party_validation_error()
	if not party_error.is_empty():
		_abort_invalid_battle(party_error)
		return
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("grid_to_world"):
		# The full battle scene always has a field. Keep the inherited fallback for
		# isolated controller tests where persistent deployment is irrelevant.
		super._spawn_demo_rosters()
		return

	var player_entries: Array[Dictionary] = []
	var persistent_party: Array[DigimonInstance] = OverworldState.get_battle_ready_active_instances()
	if persistent_party.is_empty():
		_abort_invalid_battle("You need at least one available Digimon in your party to start a battle.")
		return
	for instance: DigimonInstance in persistent_party:
		player_entries.append({"instance": instance, "profile": ""})

	var enemy_entries: Array[Dictionary] = []
	for descriptor: Dictionary in _enemy_descriptors():
		var species_name := String(descriptor.get("species", ""))
		var species_seed := String(descriptor.get("species_seed", ""))
		var min_level := int(descriptor.get("level_min", descriptor.get("level", 1)))
		var max_level := maxi(min_level, int(descriptor.get("level_max", descriptor.get("level", min_level))))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		var tier := String(descriptor.get("tier", "E"))
		var footprint := String(descriptor.get("footprint", "single"))
		var instance: DigimonInstance = null
		if not species_seed.is_empty():
			instance = _factory.create_enemy_by_seed(species_seed, level, profile, tier, footprint)
		else:
			instance = _factory.create_enemy_by_name(species_name, level, profile, tier, footprint)
		enemy_entries.append({
			"instance": instance,
			"profile": profile.to_lower(),
			"reward_modifier": _encounter_reward_modifier(),
		})

	var player_candidates := _spawn_zone_candidates(field, true)
	var enemy_candidates := _spawn_zone_candidates(field, false)
	var initially_occupied := _current_occupied_grids()
	var player_plan := _plan_team_deployment(player_entries, player_candidates, initially_occupied)
	if not bool(player_plan.get("ok", false)):
		_report_deployment_failure("player", player_plan)
		_abort_invalid_battle("The player party could not be deployed safely.")
		return

	var player_anchors: Array = player_plan.get("anchors", [])
	var enemy_blocked := initially_occupied.duplicate()
	enemy_blocked.append_array(_planned_occupied_grids(player_entries, player_anchors))
	var enemy_plan := _plan_team_deployment(enemy_entries, enemy_candidates, enemy_blocked)
	if not bool(enemy_plan.get("ok", false)):
		_report_deployment_failure("enemy", enemy_plan)
		_abort_invalid_battle("The enemy party could not be deployed safely.")
		return

	_spawn_team_from_plan(player_entries, true, player_anchors, field)
	_spawn_team_from_plan(enemy_entries, false, enemy_plan.get("anchors", []), field)
	refresh_occupancy_index()

	orient_battle_actors_toward_opponents()


func _abort_invalid_battle(reason: String) -> void:
	if _invalid_battle_abort_pending:
		return
	_invalid_battle_abort_pending = true
	push_error("Battle runtime aborted safely: %s" % reason)
	if DigitalSceneTransition.is_transitioning():
		DigitalSceneTransition.transition_finished.connect(_on_transition_finished_after_invalid_battle, CONNECT_ONE_SHOT)
		return
	_return_to_hub_after_invalid_battle()


func _on_transition_finished_after_invalid_battle(_scene_path: String, _context: String) -> void:
	_return_to_hub_after_invalid_battle()


func _return_to_hub_after_invalid_battle() -> void:
	if not DigitalSceneTransition.return_to_hub():
		push_error("Battle runtime could not return to Hub after invalid combat data.")


func _apply_pending_encounter_override() -> void:
	var config := BattleEncounterSession.consume_pending_encounter()
	var source := "Battle Operator"
	if config.is_empty():
		config = _consume_pending_debug_encounter()
		source = "DebugToolkit"
	if config.is_empty():
		return
	var definition := EncounterDefinitionScript.from_dict(config) as BattleEncounterDefinition
	var errors := definition.validate(OverworldState.get_database())
	if not errors.is_empty():
		push_warning("%s battle encounter rejected: %s" % [source, "; ".join(errors)])
		return
	encounter_definition = definition
	var encounter_seed := int(config.get("seed", 0))
	if encounter_seed != 0:
		_encounter_rng.seed = encounter_seed
	print("[%s] Battle encounter loaded · %d enemies · %s" % [source, definition.enemy_party.size(), definition.encounter_id])


func _consume_pending_debug_encounter() -> Dictionary:
	if not Engine.has_singleton("DeveloperToolkit") and get_node_or_null("/root/DeveloperToolkit") == null:
		return {}
	var toolkit := get_node_or_null("/root/DeveloperToolkit")
	if toolkit == null or not toolkit.has_method("consume_pending_battle_config"):
		return {}
	var raw_config = toolkit.call("consume_pending_battle_config")
	if not raw_config is Dictionary:
		return {}
	return (raw_config as Dictionary).duplicate(true)


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
