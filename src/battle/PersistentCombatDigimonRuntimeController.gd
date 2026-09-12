extends "res://src/battle/CombatDigimonRuntimeController.gd"

var _transition_prepare_started := false
var _transition_prepare_done := false
var _transition_field: Node2D = null
var _transition_player_candidates: Array[Vector2i] = []
var _transition_enemy_candidates: Array[Vector2i] = []
var _transition_party: Array[DigimonInstance] = []
var _transition_player_index := 0
var _transition_enemy_index := 0


func begin_transition_preparation() -> void:
	if _transition_prepare_started or _transition_prepare_done or _runtime_prepared:
		return
	_transition_prepare_started = true
	_runtime_prepared = true
	_encounter_rng.randomize()
	_spawn_rng.randomize()

	if not _database.load_default():
		push_error("Could not initialize Digimon species database")
		_runtime_prepared = false
		_transition_prepare_started = false
		return
	_factory = FactoryScript.new(_database)

	_transition_field = get_node_or_null("../Blocks") as Node2D
	if _transition_field == null or not _transition_field.has_method("grid_to_world"):
		# Isolated controller tests keep the inherited synchronous fallback.
		_spawn_demo_rosters()
		_transition_prepare_done = true
		return

	_transition_player_candidates = _spawn_zone_candidates(_transition_field, true)
	_transition_enemy_candidates = _spawn_zone_candidates(_transition_field, false)
	_shuffle_grids(_transition_player_candidates)
	_shuffle_grids(_transition_enemy_candidates)
	_transition_party = OverworldState.get_active_instances()
	_transition_player_index = 0
	_transition_enemy_index = 0


func prepare_transition_chunk(max_actors: int = 1) -> bool:
	if _transition_prepare_done:
		return true
	begin_transition_preparation()
	if not _transition_prepare_started or not _runtime_prepared:
		return false
	if _transition_prepare_done:
		return true

	var budget := maxi(1, max_actors)
	var processed := 0
	while processed < budget and _transition_player_index < _transition_party.size():
		var instance: DigimonInstance = _transition_party[_transition_player_index]
		var actor := _spawn_instance_in_zone(instance, true, _transition_player_candidates, _transition_field)
		_prepare_actor_for_intro(actor, _transition_field)
		_transition_player_index += 1
		processed += 1

	while processed < budget and _transition_player_index >= _transition_party.size() and _transition_enemy_index < ENEMY_ENCOUNTER.size():
		var descriptor: Dictionary = ENEMY_ENCOUNTER[_transition_enemy_index]
		var species_name := String(descriptor.get("species", ""))
		var min_level := int(descriptor.get("level_min", 1))
		var max_level := maxi(min_level, int(descriptor.get("level_max", min_level)))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		var instance: DigimonInstance = _factory.create_enemy_by_name(species_name, level, profile)
		var actor := _spawn_instance_in_zone(instance, false, _transition_enemy_candidates, _transition_field)
		if actor != null:
			actor.set_meta("encounter_profile", profile.to_lower())
		_prepare_actor_for_intro(actor, _transition_field)
		_transition_enemy_index += 1
		processed += 1

	if _transition_player_index >= _transition_party.size() and _transition_enemy_index >= ENEMY_ENCOUNTER.size():
		orient_battle_actors_toward_opponents()
		_transition_prepare_done = true
		return true
	return false


func prepare_transition_offtree() -> void:
	begin_transition_preparation()
	while not prepare_transition_chunk(8):
		pass


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