extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const SessionScript = preload("res://src/battle/BattleSquadSession.gd")
const RewardCalculatorScript = preload("res://src/digimon/BattleRewardCalculator.gd")
const BattleActorScene = preload("res://scenes/player.tscn")


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

	# A Reserve member can enter a later battle already knocked out. Reward
	# snapshots must still detect the persistent zero-HP state even though that
	# Digimon never had a BattleDigimon state or actor in this encounter.
	reserve[2].current_hp = 0
	assert(session.is_knocked_out(reserve[2].id), "Previously fainted Reserve must be recognized as KO without deployment")
	var initial_reward_snapshots := session.reward_snapshots()
	var prior_ko_snapshot: Dictionary = {}
	for snapshot: Dictionary in initial_reward_snapshots:
		if String(snapshot.get("instance_id", "")) == reserve[2].id:
			prior_ko_snapshot = snapshot
			break
	assert(not prior_ko_snapshot.is_empty() and bool(prior_ko_snapshot.get("knocked_out", false)), "Reward snapshot must carry prior KO state for Reserve")

	var active_actor := ActorStub.new(active[0])
	add_child(active_actor)
	assert(session.attach_actor(active_actor), "Initial Active actor must attach to persistent battle state")
	var active_state := active_actor.battle_state
	assert(active_state != null, "Attached actor must receive BattleDigimon state")

	# Initial battle actors are prepared for the roster-intro animation before the
	# Squad session attaches its persistent BattleDigimon state. State adoption
	# must not repaint that presentation state or desktop can render a tiny actor
	# before its materialization animation begins.
	var intro_actor := BattleActorScene.instantiate() as CharacterBody2D
	assert(intro_actor != null, "Battle intro actor fixture must instantiate")
	var intro_species: Dictionary = database.get_by_seed(active[1].species_seed)
	intro_actor.call("bind_digimon_instance", active[1], intro_species, true)
	add_child(intro_actor)
	var intro_sprite := intro_actor.get_node("Sprite2D") as Sprite2D
	assert(intro_sprite != null, "Battle intro actor must expose its sprite")
	var intro_base_scale := intro_sprite.scale
	intro_actor.call("prepare_battle_spawn")
	var prepared_scale := intro_sprite.scale
	assert(is_zero_approx(intro_actor.modulate.a), "Prepared intro actor must remain fully transparent")
	assert(prepared_scale.length() < intro_base_scale.length(), "Prepared intro actor must begin at reduced scale")
	assert(session.attach_actor(intro_actor), "Prepared intro actor must attach to persistent Squad state")
	assert(is_zero_approx(intro_actor.modulate.a), "Squad state adoption must not reveal a staged intro actor")
	assert(intro_sprite.scale.is_equal_approx(prepared_scale), "Squad state adoption must preserve staged intro scale")

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

	# Healthy Reserve shares the battle XP pool even without deployment, while
	# every KO member is excluded regardless of whether it fought this battle or
	# entered the encounter already fainted.
	var rewards: BattleRewardCalculator = RewardCalculatorScript.new(database)
	var player_snapshots: Array[Dictionary] = [
		{"instance_id": active[0].id, "level": active[0].level, "participated": true, "knocked_out": false},
		{"instance_id": reserve[1].id, "level": reserve[1].level, "participated": false, "knocked_out": false},
		{"instance_id": active[2].id, "level": active[2].level, "participated": true, "knocked_out": true},
		{"instance_id": reserve[2].id, "level": reserve[2].level, "participated": false, "knocked_out": true},
	]
	var enemy_snapshots: Array[Dictionary] = [{
		"species_seed": active[1].species_seed,
		"level": 8,
		"profile": "wild",
		"reward_modifier": 1.0,
	}]
	var calculated := rewards.calculate(player_snapshots, enemy_snapshots)
	assert(int(calculated.xp_by_instance.get(active[0].id, 0)) > 0, "Healthy participant must receive battle XP")
	assert(int(calculated.xp_by_instance.get(reserve[1].id, 0)) > 0, "Healthy unused Reserve must receive battle XP")
	assert(int(calculated.xp_by_instance.get(active[2].id, 0)) == 0, "Digimon knocked out during battle must receive no XP")
	assert(int(calculated.xp_by_instance.get(reserve[2].id, 0)) == 0, "Reserve already knocked out before battle must receive no XP")

	assert(initial_hp >= persisted_hp and initial_sp >= persisted_sp, "Fixture resource mutations must be monotonic")
	active_actor.queue_free()
	reserve_actor.queue_free()
	returning_actor.queue_free()
	intro_actor.queue_free()
	print("battle squad switching regression passed")
	get_tree().quit()
