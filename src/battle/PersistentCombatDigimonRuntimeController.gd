extends "res://src/battle/CombatDigimonRuntimeController.gd"

const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")
const BattleSquadSessionScript = preload("res://src/battle/BattleSquadSession.gd")
const SquadFootprintScript = preload("res://src/combat/BattleFootprint.gd")

var encounter_definition: BattleEncounterDefinition = null
var _squad_session: BattleSquadSession = null
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
	var active_squad: Array[DigimonInstance] = OverworldState.get_active_instances()
	var persistent_party: Array[DigimonInstance] = OverworldState.get_battle_ready_active_instances()
	if persistent_party.is_empty():
		_abort_invalid_battle("You need at least one available Active Digimon to start a battle.")
		return

	var deployed_ids: Array[String] = []
	for instance: DigimonInstance in persistent_party:
		player_entries.append({"instance": instance, "profile": ""})
		deployed_ids.append(instance.id)
	_squad_session = BattleSquadSessionScript.new() as BattleSquadSession
	_squad_session.configure(active_squad, OverworldState.get_reserve_party_instances(), deployed_ids)

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
	_attach_spawned_player_actors_to_squad()
	refresh_occupancy_index()

	orient_battle_actors_toward_opponents()


func get_battle_squad_session() -> BattleSquadSession:
	return _squad_session


func _attach_spawned_player_actors_to_squad() -> void:
	if _squad_session == null:
		return
	for actor: Node in get_battle_digimons():
		if actor == null or not bool(actor.get("is_player_controlled")):
			continue
		_squad_session.attach_actor(actor)


func get_bench_deployment_options(outgoing_actor: Node, allow_fallback: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _squad_session == null:
		return result
	var preferred_anchor := _actor_anchor(outgoing_actor)
	for instance: DigimonInstance in _squad_session.get_available_bench_instances():
		var placement := find_player_deployment_anchor(
			instance.id,
			preferred_anchor,
			outgoing_actor,
			allow_fallback
		)
		var species := _database.get_by_seed(instance.species_seed)
		var state := _squad_session.get_state(instance.id)
		result.append({
			"id": instance.id,
			"title": instance.get_display_name(String(species.get("name", "Digimon"))),
			"subtitle": "HP %d · SP %d · Tier %s · %s"
				% [
					state.current_hp if state != null else instance.current_hp,
					state.current_mp if state != null else instance.current_mp,
					instance.tier,
					SquadFootprintScript.display_label(instance.battle_footprint_id),
				],
			"species": String(species.get("name", "")),
			"can_deploy": bool(placement.get("ok", false)),
			"reason": String(placement.get("reason", "")),
			"anchor": placement.get("anchor", preferred_anchor),
		})
	return result


func find_player_deployment_anchor(
	instance_id: String,
	preferred_anchor: Vector2i,
	outgoing_actor: Node = null,
	allow_fallback: bool = false
) -> Dictionary:
	if _squad_session == null:
		return {"ok": false, "reason": "Battle Squad is unavailable."}
	var instance := _squad_session.get_instance(instance_id)
	if instance == null or not _squad_session.is_available_on_bench(instance_id):
		return {"ok": false, "reason": "This Digimon is not available in Reserve."}
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null:
		return {"ok": false, "reason": "Battlefield is unavailable."}

	var candidates: Array[Vector2i] = [preferred_anchor]
	if allow_fallback:
		for candidate: Vector2i in _spawn_zone_candidates(field, true):
			if not candidates.has(candidate):
				candidates.append(candidate)

	for anchor: Vector2i in candidates:
		if _can_place_instance_at_anchor(instance, anchor, outgoing_actor, field):
			return {"ok": true, "anchor": anchor, "reason": ""}
	return {
		"ok": false,
		"anchor": preferred_anchor,
		"reason": "No valid %s deployment space is available." % SquadFootprintScript.display_label(instance.battle_footprint_id),
	}


func _can_place_instance_at_anchor(
	instance: DigimonInstance,
	anchor: Vector2i,
	outgoing_actor: Node,
	field: Node2D
) -> bool:
	if instance == null:
		return false
	var raw_map = field.get("tile_map_data")
	if not raw_map is Dictionary:
		return false
	var map_data := raw_map as Dictionary
	for grid: Vector2i in SquadFootprintScript.occupied_grids(anchor, instance.battle_footprint_id):
		if not map_data.has(grid):
			return false
		if field.has_method("get_static_tile_block_reason") and not String(field.call("get_static_tile_block_reason", grid)).is_empty():
			return false
		var occupant := get_digimon_at_grid(grid, outgoing_actor)
		if occupant != null:
			return false
	return true


func perform_player_switch(outgoing_actor: Node, incoming_id: String, anchor: Vector2i) -> Node:
	if (
		_squad_session == null
		or outgoing_actor == null
		or not is_instance_valid(outgoing_actor)
		or not bool(outgoing_actor.get("is_player_controlled"))
	):
		return null
	var placement := find_player_deployment_anchor(incoming_id, anchor, outgoing_actor, false)
	if not bool(placement.get("ok", false)):
		return null
	var instance := _squad_session.get_instance(incoming_id)
	var field := get_node_or_null("../Blocks") as Node2D
	if instance == null or field == null:
		return null

	_squad_session.prepare_deployment(incoming_id)
	var incoming := _spawn_instance_at_anchor(instance, true, anchor, field)
	if incoming == null:
		return null
	if not _squad_session.attach_actor(incoming):
		remove_child(incoming)
		incoming.queue_free()
		return null

	var outgoing_id := String(outgoing_actor.call("get_digimon_instance_id")) if outgoing_actor.has_method("get_digimon_instance_id") else ""
	_squad_session.bench(outgoing_id)
	outgoing_actor.set("is_defending", false)
	outgoing_actor.visible = false
	if outgoing_actor.get_parent() == self:
		remove_child(outgoing_actor)
	outgoing_actor.queue_free()

	refresh_occupancy_index()
	face_actor_toward_nearest_opponent(incoming)
	return incoming


func perform_knockout_replacement(outgoing_actor: Node, incoming_id: String, anchor: Vector2i) -> Node:
	if _squad_session == null or outgoing_actor == null:
		return null
	var placement := find_player_deployment_anchor(incoming_id, anchor, outgoing_actor, true)
	if not bool(placement.get("ok", false)):
		return null
	return perform_player_switch(outgoing_actor, incoming_id, Vector2i(placement.get("anchor", anchor)))


func commit_squad_resources() -> void:
	if _squad_session != null:
		_squad_session.commit_all_resources()


func _actor_anchor(actor: Node) -> Vector2i:
	var field := get_node_or_null("../Blocks") as Node2D
	if actor == null or field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var world := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(field.call("world_to_grid", field.to_local(world)))


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
