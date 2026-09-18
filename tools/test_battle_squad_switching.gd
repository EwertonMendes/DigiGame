extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const SessionScript = preload("res://src/battle/BattleSquadSession.gd")
const RewardCalculatorScript = preload("res://src/digimon/BattleRewardCalculator.gd")


class ActorStub:
	extends Node

	var digimon_instance: DigimonInstance
	var battle_state: BattleDigimon

	func _init(instance: DigimonInstance) -> void:
		digimon_instance = instance

	func adopt_battle_state(state: BattleDigimon) -> bool:
		if state == null or state.instance != digimon_instance:
			return false
		battle_state = state
		return true


func _ready() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	assert(database.load_default(), "Battle Squad regression requires the Digimon database")
	var factory: DigimonFactory = FactoryScript.new(database)

	var active: Array[DigimonInstance] = [
		factory.create_player_by_name("agumon", 8, 100),
		factory.create_player_by_name("gabumon", 8, 100),
		factory.create_player_by_name("veemon", 8, 100),
	]
	var reserve: Array[DigimonInstance] = [
		factory.create_player_by_name("agumon", 8, 100),
		factory.create_player_by_name("gabumon", 8, 100),
		factory.create_player_by_name("veemon", 8, 100),
	]
	var deployed: Array[String] = []
	for instance: DigimonInstance in active:
		assert(instance != null, "Active battle fixture must resolve")
		deployed.append(instance.id)
	for instance: DigimonInstance in reserve:
		assert(instance != null, "Reserve battle fixture must resolve")

	var session: BattleSquadSession = SessionScript.new() as BattleSquadSession
	session.configure(active, reserve, deployed)
	assert(session.get_squad_ids().size() == 6, "Battle session must know the complete six-member Squad")
	assert(session.get_fielded_ids().size() == 3, "Battle session must start with only the three Active members fielded")
	assert(session.get_available_bench_ids().size() == 3, "All healthy Reserve members must be available on the bench")

	var active_actor := ActorStub.new(active[0])
	add_child(active_actor)
	assert(session.attach_actor(active_actor), "Initial Active actor must attach to persistent battle state")
	var active_state := active_actor.battle_state
	assert(active_state != null, "Attached actor must receive BattleDigimon state")
	var initial_hp := active_state.current_hp
	var initial_sp := active_state.current_mp
	active_state.take_damage(7)
	assert(active_state.spend_sp(mini(2, active_state.current_mp)), "Fixture must be able to spend available SP")
	active_state.add_status("squad_test_status", 3, active[1].id, {"id": "squad_test_status"})
	active_state.set_initiative(88.0)
	var persisted_hp := active_state.current_hp
	var persisted_sp := active_state.current_mp

	session.bench(active[0].id)
	assert(not session.is_fielded(active[0].id), "Switched-out Digimon must leave the fielded set")
	assert(active_state.initiative == 0.0, "Bench members must not retain charged initiative")
	assert(active_state.current_hp == persisted_hp and active_state.current_mp == persisted_sp, "Switching out must preserve HP and SP")
	assert(active_state.has_status("squad_test_status"), "Switching out must preserve temporary status state")

	var incoming_id := reserve[0].id
	assert(session.is_available_on_bench(incoming_id), "Healthy Reserve member must be switchable")
	var reserve_state := session.prepare_deployment(incoming_id)
	assert(reserve_state != null and reserve_state.initiative == 0.0, "Incoming Reserve must start from neutral initiative")
	var reserve_actor := ActorStub.new(reserve[0])
	add_child(reserve_actor)
	assert(session.attach_actor(reserve_actor), "Incoming Reserve actor must attach to its persistent battle state")
	assert(session.was_participant(incoming_id), "A Reserve member must become a participant when first deployed")
	assert(not session.is_available_on_bench(incoming_id), "Fielded Reserve member must leave the available bench")

	session.bench(incoming_id)
	var returning_actor := ActorStub.new(active[0])
	add_child(returning_actor)
	session.prepare_deployment(active[0].id)
	assert(session.attach_actor(returning_actor), "Previously fielded Active must be able to return from the bench")
	assert(returning_actor.battle_state == active_state, "Returning Digimon must reuse the exact BattleDigimon state object")
	assert(returning_actor.battle_state.current_hp == persisted_hp, "Returning Digimon must keep battle HP")
	assert(returning_actor.battle_state.current_mp == persisted_sp, "Returning Digimon must keep battle SP")
	assert(returning_actor.battle_state.has_status("squad_test_status"), "Returning Digimon must keep statuses")

	session.commit_all_resources()
	assert(active[0].current_hp == persisted_hp and active[0].current_mp == persisted_sp, "Battle session commit must persist switched Digimon resources")

	# A Squad member that never entered combat receives the configured Reserve
	# XP multiplier (currently zero), while participants receive normal XP.
	var rewards: BattleRewardCalculator = RewardCalculatorScript.new(database)
	var player_snapshots: Array[Dictionary] = [
		{"instance_id": active[0].id, "level": active[0].level, "participated": true, "knocked_out": false},
		{"instance_id": reserve[1].id, "level": reserve[1].level, "participated": false, "knocked_out": false},
	]
	var enemy_snapshots: Array[Dictionary] = [{
		"species_seed": active[1].species_seed,
		"level": 8,
		"profile": "wild",
		"reward_modifier": 1.0,
	}]
	var calculated := rewards.calculate(player_snapshots, enemy_snapshots)
	assert(int(calculated.xp_by_instance.get(active[0].id, 0)) > 0, "Participant must receive battle XP")
	assert(int(calculated.xp_by_instance.get(reserve[1].id, -1)) == 0, "Unused Reserve must use the zero Reserve XP multiplier")

	assert(initial_hp >= persisted_hp and initial_sp >= persisted_sp, "Fixture resource mutations must be monotonic")
	active_actor.queue_free()
	reserve_actor.queue_free()
	returning_actor.queue_free()
	print("battle squad switching regression passed")
	get_tree().quit()
