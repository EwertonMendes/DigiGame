extends Node

const ProgressionBalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const DigimonDatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const DigimonFactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const AscensionServiceScript = preload("res://src/digimon/DigimonAscensionService.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

var _failed := false


func _ready() -> void:
	_test_tier_math()
	_test_ascension_and_expansion()
	_test_footprint_geometry()
	if _failed:
		get_tree().quit(1)
		return
	print("tier and footprint regression passed")
	get_tree().quit(0)


func _test_tier_math() -> void:
	var balance := ProgressionBalanceScript.new()
	balance.load_default()
	var database := DigimonDatabaseScript.new()
	database.load_default()
	var factory := DigimonFactoryScript.new(database, balance)
	var calculator := StatCalculatorScript.new(balance)
	var instance = factory.create_player_by_name("War Greymon", 50, 100)
	var species := database.get_by_seed(instance.species_seed)

	var base_values := {}
	for stat_name in ["hp", "mp", "attack", "defense", "intelligence", "speed", "move"]:
		base_values[stat_name] = calculator.get_stat(instance, species, stat_name)

	var expected_primary := {
		"E": 1.00,
		"D": 1.05,
		"C": 1.10,
		"B": 1.16,
		"A": 1.23,
		"S": 1.31,
		"SS": 1.40,
		"SSS": 1.50,
	}
	var expected_secondary := {
		"E": 1.00,
		"D": 1.025,
		"C": 1.05,
		"B": 1.08,
		"A": 1.115,
		"S": 1.155,
		"SS": 1.20,
		"SSS": 1.25,
	}
	for tier_name in expected_primary.keys():
		instance.tier = tier_name
		_assert(
			calculator.get_stat(instance, species, "hp") == int(round(float(base_values["hp"]) * float(expected_primary[tier_name]))),
			"%s must apply exact primary HP multiplier" % tier_name
		)
		_assert(
			calculator.get_stat(instance, species, "attack") == int(round(float(base_values["attack"]) * float(expected_primary[tier_name]))),
			"%s must apply exact primary ATK multiplier" % tier_name
		)
		_assert(
			calculator.get_stat(instance, species, "defense") == int(round(float(base_values["defense"]) * float(expected_primary[tier_name]))),
			"%s must apply exact primary DEF multiplier" % tier_name
		)
		_assert(
			calculator.get_stat(instance, species, "intelligence") == int(round(float(base_values["intelligence"]) * float(expected_primary[tier_name]))),
			"%s must apply exact primary INT multiplier" % tier_name
		)
		_assert(
			calculator.get_stat(instance, species, "mp") == int(round(float(base_values["mp"]) * float(expected_secondary[tier_name]))),
			"%s must apply exact secondary SP multiplier" % tier_name
		)
		_assert(
			calculator.get_stat(instance, species, "speed") == int(round(float(base_values["speed"]) * float(expected_secondary[tier_name]))),
			"%s must apply exact secondary SPD multiplier" % tier_name
		)
		_assert(calculator.get_stat(instance, species, "move") == int(base_values["move"]), "%s must never modify MOV" % tier_name)


func _test_ascension_and_expansion() -> void:
	var balance := ProgressionBalanceScript.new()
	balance.load_default()
	var database := DigimonDatabaseScript.new()
	database.load_default()
	var factory := DigimonFactoryScript.new(database, balance)
	var calculator := StatCalculatorScript.new(balance)
	var ascension := AscensionServiceScript.new(balance)
	var collection := CollectionScript.new()
	collection.bits = 1_000_000

	var target = factory.create_player_by_name("War Greymon", 50, 100)
	target.nickname = "Ascension Target"
	target.learn_skill("shared_regression_skill")
	target.add_skill_mastery("shared_regression_skill", 7)
	collection.add_instance(target, "party", "War Greymon")

	var tier_sequence := ["D", "C", "B", "A", "S", "SS", "SSS"]
	var costs := [300, 1500, 5000, 15000, 50000, 125000, 300000]
	var duplicate_required := [false, true, true, true, true, false, true]
	var starting_bits := collection.bits
	var consumed_duplicates := 0
	for index in range(tier_sequence.size()):
		var donor_id := ""
		if duplicate_required[index]:
			var donor = factory.create_player_by_name("War Greymon", 50, 100)
			donor.learn_skill("shared_regression_skill")
			donor.add_skill_mastery("shared_regression_skill", 16)
			if index == 1:
				donor.learn_skill("donor_only_regression_skill")
			collection.add_instance(donor, "storage", "War Greymon")
			donor_id = donor.id
			consumed_duplicates += 1
		var before_bits := collection.bits
		var result := ascension.ascend(collection, database, target.id, donor_id)
		_assert(bool(result.get("success", false)), "Ascension to %s must succeed with valid requirements" % tier_sequence[index])
		_assert(target.tier == tier_sequence[index], "Ascension must set Tier %s" % tier_sequence[index])
		_assert(collection.bits == before_bits - costs[index], "Tier %s must consume exact Bits cost" % tier_sequence[index])
	_assert(collection.bits == starting_bits - 496800, "Full E->SSS ascension must consume exact cumulative Bits")
	_assert(collection.get_instances().size() == 1, "Exactly five duplicate donors must be consumed through SSS")
	_assert(consumed_duplicates == 5, "Ascension path must require exactly five duplicate fusions")
	_assert(target.learned_skills.has("donor_only_regression_skill") and target.archived_skills.has("donor_only_regression_skill"), "Donor-only technique must be learned and archived")
	_assert(target.get_skill_mastery_points("shared_regression_skill") == 16, "Shared mastery must keep the highest value without adding")
	_assert(target.nickname == "Ascension Target", "Fusion must preserve target identity state")

	var species := database.get_by_seed(target.species_seed)
	var locked_target := factory.create_player_by_name("War Greymon", 1, 100)
	locked_target.tier = "A"
	collection.add_instance(locked_target, "locked", "War Greymon")
	collection.add_item("expansion_core", 1)
	var locked_result := ascension.unlock_expansion(collection, database, locked_target.id)
	_assert(not bool(locked_result.get("success", false)) and collection.get_item_count("expansion_core") == 1, "Expansion must reject Tier A without consuming a Core")
	var unlock := ascension.unlock_expansion(collection, database, target.id)
	_assert(bool(unlock.get("success", false)) and target.expansion_unlocked and collection.get_item_count("expansion_core") == 0, "Tier S+ target must consume one Core and unlock permanently")
	var normal_hp_max := calculator.get_stat(target, species, "hp")
	var normal_sp_max := calculator.get_stat(target, species, "mp")
	target.current_hp = normal_hp_max / 2
	target.current_mp = normal_sp_max / 2
	var expand := ascension.set_expanded(database, target, true)
	var expanded_hp_max := calculator.get_stat(target, species, "hp")
	_assert(bool(expand.get("success", false)) and target.is_expanded(), "Unlocked target must switch to 2x2")
	_assert(expanded_hp_max == int(round(float(normal_hp_max) * 1.2)), "Expansion must add exactly 20 percent maximum HP")
	var hp_ratio := float(target.current_hp) / float(expanded_hp_max)
	var sp_ratio := float(target.current_mp) / float(normal_sp_max)
	_assert(absf(hp_ratio - 0.5) <= 0.01, "Expansion must preserve current HP proportion")
	_assert(absf(sp_ratio - 0.5) <= 0.01, "Expansion must preserve current SP proportion")
	_assert(bool(ascension.set_expanded(database, target, false).get("success", false)) and not target.is_expanded(), "Expansion toggle must freely return to 1x1")

	collection.bits = 50000
	collection.add_item("expansion_fragment", 5)
	var crafted := ascension.craft_expansion_core(collection)
	_assert(bool(crafted.get("success", false)) and collection.bits == 0 and collection.get_item_count("expansion_fragment") == 0 and collection.get_item_count("expansion_core") == 1, "Five fragments and 50,000 Bits must craft one Core")


func _test_footprint_geometry() -> void:
	var occupied := FootprintScript.occupied_grids(Vector2i(2, 3), "large_2x2")
	_assert(occupied == [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 4), Vector2i(3, 4)], "2x2 footprint must use explicit anchor offsets")
	var entered := FootprintScript.newly_entered_grids(Vector2i(2, 3), Vector2i(3, 3), "large_2x2")
	_assert(entered == [Vector2i(4, 3), Vector2i(4, 4)], "A cardinal 2x2 step must expose only its newly entered edge")
	var target := FootprintScript.occupied_grids(Vector2i(5, 3), "large_2x2")
	_assert(FootprintScript.minimum_distance(occupied, target) == 2, "Range must use the nearest footprint edges")
	_assert(FootprintScript.front_edge(occupied, Vector2i.RIGHT) == [Vector2i(3, 3), Vector2i(3, 4)], "A 2x2 unit must expose a two-cell front")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
