extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const CatalogScript = preload("res://src/digimon/FusionCatalog.gd")
const FusionProgressScript = preload("res://src/digimon/FusionProgressService.gd")
const FusionServiceScript = preload("res://src/digimon/FusionService.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const EvolutionScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const SaveMigrationScript = preload("res://src/save/SaveMigration.gd")
const QuestDefinitionScript = preload("res://src/quests/QuestDefinition.gd")
const QuestServiceScript = preload("res://src/quests/QuestService.gd")

var _database: DigimonDatabase
var _catalog: FusionCatalog
var _factory: DigimonFactory
var _fusion: FusionService
var _progress: FusionProgressService
var _stats: DigimonStatCalculator


func _ready() -> void:
	_database = DatabaseScript.new()
	assert(_database.load_default(), "Fusion tests require the Digimon database")
	_catalog = CatalogScript.new()
	assert(_catalog.load_default(_database), "Fusion catalogue must load and validate")
	_factory = FactoryScript.new(_database)
	_fusion = FusionServiceScript.new(_database, _catalog)
	_progress = FusionProgressScript.new()
	_stats = StatCalculatorScript.new()

	_test_catalog_contract()
	_test_fusion_data_caps_and_persists()
	_test_material_guards()
	_test_material_discovery_across_locations()
	_test_paildramon_fusion_and_degeneration()
	_test_repeated_species_materials()
	_test_nested_fusion_materials()
	_test_quest_fusion_data_contract()
	_test_v2_save_migration()

	print("fusion system regression passed")
	get_tree().quit()


func _test_catalog_contract() -> void:
	var definitions := _catalog.get_all()
	assert(definitions.size() >= 12, "Initial Fusion catalogue must include the curated launch recipes")
	for definition: Dictionary in definitions:
		var result := _database.get_by_seed(String(definition.get("resultSeed", "")))
		assert(not result.is_empty(), "Every Fusion result must exist in the species database")
		assert(String(result.get("rank", "")) == "Fusion", "Fusion result must use the Fusion rank")
		assert(not bool(result.get("reconstructable", true)), "Fusion result must not be reconstructable")
		assert(_database.get_evolution_routes(String(result.get("seed", ""))).is_empty(), "Fusion result must have no canonical forward evolution route")
		assert(_database.get_degeneration_routes(String(result.get("seed", ""))).is_empty(), "Fusion degeneration must be instance-derived")


func _test_fusion_data_caps_and_persists() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var first := _progress.add_data(collection, "omnimon", 90, _catalog, "test")
	assert(first.get("success", false) and int(first.get("after", 0)) == 90, "Fusion Data must accumulate below the unlock threshold")
	var unlock := _progress.add_data(collection, "omnimon", 20, _catalog, "test")
	assert(int(unlock.get("after", 0)) == 100 and int(unlock.get("gained", 0)) == 10, "Fusion Data must clamp to 100")
	assert(bool(unlock.get("newly_unlocked", false)), "Crossing 100 must report a new permanent unlock")
	var capped := _progress.add_data(collection, "omnimon", 50, _catalog, "test")
	assert(int(capped.get("after", 0)) == 100 and int(capped.get("gained", -1)) == 0, "Unlocked Fusion Data must never grow beyond 100")

	var restored := PlayerCollection.new()
	restored.load_dict(collection.to_dict())
	assert(restored.get_fusion_data("omnimon") == 100, "Fusion Data must survive collection serialization")


func _test_material_guards() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	collection.set_fusion_data("paildramon", 100)
	var ex := _factory.create_player_by_name("ExVeemon", 35, 100)
	var sting := _factory.create_player_by_name("Stingmon", 35, 100)
	collection.add_instance(ex, "guard_exveemon", "ExVeemon")
	collection.add_instance(sting, "guard_stingmon", "Stingmon")

	ex.current_hp = 0
	var fainted := _fusion.get_preview(collection, "paildramon")
	assert(not bool(fainted.get("can_fuse", false)), "Fainted material must be rejected")

	_refill(ex)
	ex.equipment.append("test_equipment")
	var equipped := _fusion.get_preview(collection, "paildramon")
	assert(not bool(equipped.get("can_fuse", false)), "Equipped material must be rejected instead of silently destroying equipment")
	ex.equipment.clear()

	var alternate_ex := _factory.create_player_by_name("ExVeemon", 36, 100)
	collection.add_instance(alternate_ex, "guard_exveemon_alternate", "ExVeemon")
	ex.current_hp = 0
	var explicit_ids: Array[String] = [ex.id, sting.id]
	var explicit_invalid := _fusion.get_preview(collection, "paildramon", explicit_ids)
	assert(not bool(explicit_invalid.get("can_fuse", false)), "An invalid explicit material must fail closed instead of silently consuming another eligible copy")
	assert(String((explicit_invalid.get("selected_ids", []) as Array)[0]).is_empty(), "Invalid explicit slot must remain unresolved")
	_refill(ex)

	assert(collection.set_squad_ids([ex.id], [], 0, 3, 3), "Hospital guard fixture must place the material in Active")
	assert(collection.admit_to_hospital(ex.id), "Hospital guard fixture must admit the material")
	var hospitalized_ids: Array[String] = [ex.id, sting.id]
	var hospitalized := _fusion.get_preview(collection, "paildramon", hospitalized_ids)
	assert(not bool(hospitalized.get("can_fuse", false)), "Explicitly selected hospitalized material must be rejected without substituting another copy")


func _test_material_discovery_across_locations() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	collection.set_fusion_data("paildramon", 100)

	var active_ex := _factory.create_player_by_name("ExVeemon", 35, 100)
	var reserve_ex := _factory.create_player_by_name("ExVeemon", 36, 100)
	var storage_sting := _factory.create_player_by_name("Stingmon", 37, 100)
	collection.add_instance(active_ex, "location_active_ex", "ExVeemon")
	collection.add_instance(reserve_ex, "location_reserve_ex", "ExVeemon")
	collection.add_instance(storage_sting, "location_storage_sting", "Stingmon")
	assert(collection.set_squad_ids([active_ex.id], [reserve_ex.id], 0, 3, 3), "Location fixture must assign Active and Reserve material copies")

	var ex_candidates := _fusion.get_eligible_instances(collection, "paildramon", 0)
	var sting_candidates := _fusion.get_eligible_instances(collection, "paildramon", 1)
	var ex_ids: Array[String] = []
	for candidate: DigimonInstance in ex_candidates:
		ex_ids.append(candidate.id)
	assert(ex_ids.has(active_ex.id), "Fusion material lookup must include Active Digimon")
	assert(ex_ids.has(reserve_ex.id), "Fusion material lookup must include Reserve Digimon")
	assert(sting_candidates.any(func(candidate: DigimonInstance) -> bool: return candidate.id == storage_sting.id), "Fusion material lookup must include Storage Digimon")

	var preview := _fusion.get_preview(collection, "paildramon")
	assert(bool(preview.get("can_fuse", false)), "Fusion preview must combine eligible materials across Active / Reserve / Storage")


func _test_paildramon_fusion_and_degeneration() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	collection.set_fusion_data("paildramon", 100)
	var ex := _factory.create_player_by_name("ExVeemon", 50, 100)
	var sting := _factory.create_player_by_name("Stingmon", 70, 100)
	ex.tier = "A"
	sting.tier = "S"
	for stat_key: String in DigimonInstance.STAT_KEYS:
		ex.aptitudes[stat_key] = 3
		sting.aptitudes[stat_key] = 1
	ex.learn_skill("fusion_test_shared", false)
	sting.learn_skill("fusion_test_shared", false)
	ex.skill_mastery["fusion_test_shared"] = 5
	sting.skill_mastery["fusion_test_shared"] = 17
	ex.training["atk"] = 12
	sting.training["int"] = 15

	var ex_species := _database.get_by_seed(ex.species_seed)
	var sting_species := _database.get_by_seed(sting.species_seed)
	var ex_max_hp := _stats.get_stat(ex, ex_species, "hp")
	var sting_max_hp := _stats.get_stat(sting, sting_species, "hp")
	ex.current_hp = maxi(1, int(round(float(ex_max_hp) * 0.5)))
	sting.current_hp = maxi(1, int(round(float(sting_max_hp) * 0.8)))

	collection.add_instance(ex, "fusion_exveemon", "ExVeemon")
	collection.add_instance(sting, "fusion_stingmon", "Stingmon")
	assert(collection.set_squad_ids([ex.id], [], 0, 3, 3), "Fusion fixture must preserve an Active destination")

	var preview := _fusion.get_preview(collection, "paildramon")
	assert(bool(preview.get("can_fuse", false)), "Unlocked Fusion with valid materials must be available")
	assert(int(preview.get("result_potential", -1)) == 61, "Levels 50 and 70 must produce Potential 61")
	assert(String(preview.get("result_tier", "")) == "S", "Fusion must preserve the highest material Tier")
	var selected_ids = preview.get("selected_ids", [])
	assert(selected_ids is Array and (selected_ids as Array).size() == 2, "Paildramon must resolve exactly two material instances")

	var ex_id := ex.id
	var sting_id := sting.id
	var fuse_result := _fusion.fuse(collection, "paildramon", [])
	assert(bool(fuse_result.get("success", false)), "Valid Fusion must commit")
	assert(not collection.has_instance(ex_id) and not collection.has_instance(sting_id), "Fusion must permanently consume both material UUIDs")
	assert(collection.get_instances().size() == 1, "Fusion must replace two materials with one new individual")

	var result_id := String(fuse_result.get("result_instance_id", ""))
	var result := collection.get_instance(result_id)
	assert(result != null and result.id != ex_id and result.id != sting_id, "Fusion result must own a new UUID")
	assert(result.level == 1 and result.exp == 0, "Fusion result must start at Level 1")
	assert(result.potential == 61 and result.tier == "S", "Fusion result must preserve previewed Potential and Tier")
	assert(String(_database.get_by_seed(result.species_seed).get("rank", "")) == "Fusion", "Created result must be a Fusion species")
	assert(String(result.fusion_origin.get("fusionId", "")) == "paildramon", "Fusion origin must persist its recipe identity")
	assert((result.fusion_origin.get("materialSeeds", []) as Array).size() == 2, "Fusion origin must record the actual component species")
	assert(result.get_skill_mastery_points("fusion_test_shared") == 17, "Fusion must keep the highest mastery for shared techniques")
	for stat_key: String in DigimonInstance.STAT_KEYS:
		assert(int(result.training.get(stat_key, -1)) == 0, "Fusion training must start at zero")
		assert(int(result.aptitudes.get(stat_key, 0)) == 2, "Fusion aptitudes must average material aptitudes")
	assert(int(result.training.get("mov", -1)) == 0, "Fusion mobility training must start at zero")
	assert(collection.get_active_party_ids() == [result.id], "Fusion must inherit the earliest consumed Active slot")
	assert(collection.location_invariant_error().is_empty(), "Fusion commit must preserve collection location invariants")

	var result_species := _database.get_by_seed(result.species_seed)
	var result_max_hp := _stats.get_stat(result, result_species, "hp")
	var expected_half_hp := maxi(1, int(round(float(result_max_hp) * 0.5)))
	assert(abs(result.current_hp - expected_half_hp) <= 1, "Fusion must preserve the lowest material HP ratio instead of healing")

	var serialized := collection.to_dict()
	var restored := PlayerCollection.new()
	restored.load_dict(serialized)
	var restored_result := restored.get_instance(result.id)
	assert(restored_result != null and String(restored_result.fusion_origin.get("fusionId", "")) == "paildramon", "Fusion origin must survive save/load")
	assert(restored.get_fusion_data("paildramon") == 100, "Unlocked Fusion Data must survive save/load")

	var evolution := EvolutionScript.new()
	var forward := evolution.get_available_evolutions(restored_result, _database, _stats)
	assert(forward.is_empty(), "Fusion forms must never expose normal forward evolutions")
	var degenerations := evolution.get_available_degenerations(restored_result, _database, _stats)
	assert(degenerations.size() == 2, "Fusion must expose only its actual material species as degeneration choices")
	var ex_seed := String(_database.get_by_name("ExVeemon").get("seed", ""))
	var sting_seed := String(_database.get_by_name("Stingmon").get("seed", ""))
	var targets: Array[String] = []
	for route: Dictionary in degenerations:
		targets.append(String(route.get("targetSeed", "")))
	assert(targets.has(ex_seed) and targets.has(sting_seed), "Fusion degeneration targets must match the consumed material species")

	var potential_before := restored_result.potential
	assert(evolution.degenerate(restored_result, ex_seed, _database, _stats), "Fusion must be able to degenerate to an actual material")
	assert(restored_result.species_seed == ex_seed and restored_result.level == 1, "Fusion degeneration must produce the chosen component at Level 1")
	assert(restored_result.potential == potential_before, "Fusion degeneration must not farm additional Potential")
	assert(restored_result.fusion_origin.is_empty(), "Fusion origin must clear after degeneration")
	assert(not evolution.can_digivolve(restored_result, String(result_species.get("seed", "")), _database, _stats), "Degenerated component must not evolve back to Fusion through the normal menu")


func _test_repeated_species_materials() -> void:
	var definition := _catalog.get_by_id("armageddemon")
	if definition.is_empty():
		return
	var collection: PlayerCollection = CollectionScript.new()
	collection.set_fusion_data("armageddemon", 100)
	for index in range(3):
		var kuramon := _factory.create_player_by_name("Kuramon", 40 + index, 100)
		assert(kuramon != null, "Armageddemon fixture requires Kuramon")
		collection.add_instance(kuramon, "kuramon_%d" % index, "Kuramon")
	var preview := _fusion.get_preview(collection, "armageddemon")
	assert(bool(preview.get("can_fuse", false)), "Repeated-species Fusion must resolve the requested amount")
	var selected = preview.get("selected_ids", [])
	assert(selected is Array and (selected as Array).size() == 3, "Kuramon x3 must expand into three material slots")
	var unique: Dictionary = {}
	for raw_id in selected:
		unique[String(raw_id)] = true
	assert(unique.size() == 3, "Repeated material slots must use distinct Digimon UUIDs")


func _test_nested_fusion_materials() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	for fusion_id: String in ["omnimon", "imperialdramon_fighter_mode", "imperialdramon_paladin_mode"]:
		collection.set_fusion_data(fusion_id, 100)

	var war := _factory.create_player_by_name("War Greymon", 70, 100)
	var metal := _factory.create_player_by_name("Metal Garurumon", 70, 100)
	var ex := _factory.create_player_by_name("ExVeemon", 70, 100)
	var sting := _factory.create_player_by_name("Stingmon", 70, 100)
	for entry in [
		[war, "nested_wargreymon", "War Greymon"],
		[metal, "nested_metalgarurumon", "Metal Garurumon"],
		[ex, "nested_exveemon", "ExVeemon"],
		[sting, "nested_stingmon", "Stingmon"],
	]:
		var instance := entry[0] as DigimonInstance
		collection.add_instance(instance, String(entry[1]), String(entry[2]))

	var omnimon_result := _fusion.fuse(collection, "omnimon")
	assert(bool(omnimon_result.get("success", false)), "Omnimon fixture Fusion must succeed")
	var fighter_result := _fusion.fuse(collection, "imperialdramon_fighter_mode")
	assert(bool(fighter_result.get("success", false)), "Fighter Mode fixture Fusion must succeed")

	var omnimon := collection.get_instance(String(omnimon_result.get("result_instance_id", "")))
	var fighter := collection.get_instance(String(fighter_result.get("result_instance_id", "")))
	assert(omnimon != null and fighter != null, "Nested Fusion materials must exist after their source Fusions")
	omnimon.level = 70
	fighter.level = 70

	var paladin_preview := _fusion.get_preview(collection, "imperialdramon_paladin_mode", [fighter.id, omnimon.id])
	assert(bool(paladin_preview.get("can_fuse", false)), "Fusion results must be valid materials for a later Fusion")
	var paladin_result := _fusion.fuse(collection, "imperialdramon_paladin_mode", [fighter.id, omnimon.id])
	assert(bool(paladin_result.get("success", false)), "Paladin Mode must support chained Fusion materials")
	assert(not collection.has_instance(omnimon.id) and not collection.has_instance(fighter.id), "Nested Fusion must consume the immediate Fusion material UUIDs")
	var paladin := collection.get_instance(String(paladin_result.get("result_instance_id", "")))
	assert(paladin != null, "Nested Fusion must create Paladin Mode")
	assert(String(_database.get_by_seed(paladin.species_seed).get("name", "")) == "Imperialdramon (Paladin Mode)", "Nested Fusion result must be Paladin Mode")
	var material_seeds = paladin.fusion_origin.get("materialSeeds", [])
	assert(material_seeds is Array and (material_seeds as Array).has(omnimon.species_seed) and (material_seeds as Array).has(fighter.species_seed), "Nested Fusion origin must record its immediate Fusion components")


func _test_quest_fusion_data_contract() -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var definition: QuestDefinition = QuestDefinitionScript.new()
	definition.quest_id = "fusion_data_regression"
	definition.initial_state = QuestService.STATE_LOCKED
	definition.objectives = [{"type": "battle_wins", "amount": 1}]
	var omnimon_definition := _catalog.get_by_id("omnimon")
	var omnimon_seed := String(omnimon_definition.get("resultSeed", ""))
	definition.rewards = {
		"fusion_data": {"omnimon": 65},
		"digi_data": {omnimon_seed: 99},
	}
	var service: QuestService = QuestServiceScript.new()
	assert(service.set_available(collection, definition), "Fusion Data quest fixture must become available")
	assert(service.start(collection, definition), "Fusion Data quest fixture must start")
	var result := service.record_battle_win(collection, definition, 1)
	assert(bool(result.get("completed", false)), "Fusion Data quest fixture must complete")
	assert(collection.get_fusion_data("omnimon") == 65, "Quest rewards must grant Fusion Data through the dedicated progression channel")
	assert(collection.get_digi_data(omnimon_seed) == 0, "Quest rewards must never create normal Digi Data for Fusion species")
	var rewards := result.get("rewards", {}) as Dictionary
	assert(int((rewards.get("fusion_data", {}) as Dictionary).get("omnimon", 0)) == 65, "Quest result must report applied Fusion Data")
	assert((rewards.get("digi_data", {}) as Dictionary).is_empty(), "Rejected Fusion Digi Data must not be reported as applied")


func _test_v2_save_migration() -> void:
	var migration = SaveMigrationScript.new()
	var migrated := migration.migrate({
		"save_version": 2,
		"save_format": "world-v2",
		"collection": {
			"instances": [],
			"activeSquadIds": [],
			"reserveSquadIds": [],
			"bits": 12,
			"digiData": {},
		},
		"world": {},
	})
	assert(int(migrated.get("save_version", 0)) == 3 and String(migrated.get("save_format", "")) == "fusion-v3", "world-v2 saves must migrate to Fusion v3")
	var collection := migrated.get("collection", {}) as Dictionary
	assert(collection.has("fusionData") and (collection.get("fusionData", {}) as Dictionary).is_empty(), "Migrated saves must initialize empty Fusion Data")


func _refill(instance: DigimonInstance) -> void:
	var species := _database.get_by_seed(instance.species_seed)
	instance.current_hp = _stats.get_stat(instance, species, "hp")
	instance.current_mp = _stats.get_stat(instance, species, "mp")
