extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const AscensionScript = preload("res://src/digimon/DigimonAscensionService.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const CalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const MovementScript = preload("res://src/MovementSystem.gd")
const PatternScript = preload("res://src/battle/combat/TargetPatternResolver.gd")


class MockActor:
	extends Node

	var anchor := Vector2i.ZERO
	var footprint_id := "single"
	var is_player_controlled := true

	func _init(start_anchor: Vector2i, size_id: String, player_team: bool = true) -> void:
		anchor = start_anchor
		footprint_id = size_id
		is_player_controlled = player_team

	func get_grid_anchor() -> Vector2i:
		return anchor

	func get_battle_footprint_id() -> String:
		return footprint_id

	func get_occupied_grids(override_anchor = null) -> Array[Vector2i]:
		var effective_anchor := anchor if override_anchor == null else Vector2i(override_anchor)
		return FootprintScript.occupied_grids(effective_anchor, footprint_id)


class MockField:
	extends Node

	var blocked: Dictionary = {}
	var costs: Dictionary = {}
	var board_size := Vector2i(9, 9)

	func get_static_tile_block_reason(grid: Vector2i) -> String:
		if grid.x < 0 or grid.y < 0 or grid.x >= board_size.x or grid.y >= board_size.y:
			return "out_of_bounds"
		return "terrain_blocked" if blocked.has(grid) else ""

	func get_movement_cost(grid: Vector2i, _actor: Node = null) -> int:
		return int(costs.get(grid, 1))

	func grid_to_world(grid: Vector2i) -> Vector2:
		return Vector2(grid)


class MockController:
	extends Node

	var occupants: Dictionary = {}

	func get_digimon_at_grid(grid: Vector2i, ignored: Node = null) -> Node:
		var actor := occupants.get(grid) as Node
		return null if actor == ignored else actor


func _ready() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	_assert(database.load_default(), "Species database must load")
	var factory: DigimonFactory = FactoryScript.new(database)
	_test_balance_and_stats(database, factory)
	_test_ascension_and_expansion(database, factory)
	_test_footprint_geometry()
	_test_footprint_movement()
	_test_footprint_patterns()
	print("tier and tactical footprint regression passed")
	get_tree().quit()


func _test_balance_and_stats(database: DigimonDatabase, factory: DigimonFactory) -> void:
	var balance: ProgressionBalance = BalanceScript.new()
	var calculator: DigimonStatCalculator = CalculatorScript.new()
	var primary := {"E": 1.0, "D": 1.05, "C": 1.10, "B": 1.16, "A": 1.23, "S": 1.31, "SS": 1.40, "SSS": 1.50}
	var secondary := {"E": 1.0, "D": 1.025, "C": 1.05, "B": 1.08, "A": 1.115, "S": 1.155, "SS": 1.20, "SSS": 1.25}
	var costs := {"D": 300, "C": 1500, "B": 5000, "A": 15000, "S": 50000, "SS": 125000, "SSS": 300000}
	for tier: String in balance.tier_order():
		_assert(is_equal_approx(balance.tier_stat_multiplier(tier, "atk"), float(primary[tier])), "Primary Tier multiplier mismatch for %s" % tier)
		_assert(is_equal_approx(balance.tier_stat_multiplier(tier, "mp"), float(secondary[tier])), "SP Tier multiplier mismatch for %s" % tier)
		_assert(is_equal_approx(balance.tier_stat_multiplier(tier, "speed"), float(secondary[tier])), "SPD Tier multiplier mismatch for %s" % tier)
		if costs.has(tier):
			_assert(balance.tier_promotion_bits(tier) == int(costs[tier]), "Tier promotion cost mismatch for %s" % tier)

	var instance := factory.create_player_by_name("Agumon", 1, 100)
	var species := database.get_by_seed(instance.species_seed)
	for stat_key: String in DigimonInstance.STAT_KEYS:
		instance.aptitudes[stat_key] = 0
		instance.training[stat_key] = 0
	var base_mov := calculator.get_mov(instance, species)
	var base_hp := calculator.get_stat(instance, species, "hp")
	var base_sp := calculator.get_stat(instance, species, "mp")
	instance.tier = "SSS"
	_assert(calculator.get_stat(instance, species, "hp") == int(round(float(base_hp) * 1.5)), "Tier SSS must apply the final HP multiplier")
	_assert(calculator.get_stat(instance, species, "mp") == int(round(float(base_sp) * 1.25)), "Tier SSS must apply the reduced SP multiplier")
	_assert(calculator.get_mov(instance, species) == base_mov, "Tier must never modify MOV")
	_assert(not instance.is_expanded(), "Reconstructed Digimon must begin locked and 1x1")


func _test_ascension_and_expansion(database: DigimonDatabase, factory: DigimonFactory) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var ascension: DigimonAscensionService = AscensionScript.new()
	var calculator: DigimonStatCalculator = CalculatorScript.new()
	var target := factory.create_player_by_name("War Greymon", 30, 100)
	target.nickname = "Ascension Target"
	target.learn_skill("shared_regression_skill", false)
	target.skill_mastery["shared_regression_skill"] = 8
	collection.add_instance(target, "target", "War Greymon")
	var donor_ids: Array[String] = []
	for donor_index in range(5):
		var donor := factory.create_player_by_name("War Greymon", 1, 100)
		donor.nickname = "Donor %d" % (donor_index + 1)
		donor.learn_skill("shared_regression_skill", false)
		donor.skill_mastery["shared_regression_skill"] = 12 + donor_index
		if donor_index == 0:
			donor.learn_skill("donor_only_regression_skill", false)
		collection.add_instance(donor, "donor_%d" % donor_index, "War Greymon")
		donor_ids.append(donor.id)
	collection.bits = 0
	var bits_before := collection.bits
	var invalid := ascension.promote(collection, database, target.id, "missing")
	_assert(not bool(invalid.get("success", false)) and collection.bits == bits_before and collection.get_instances().size() == 6, "Invalid promotion must be atomic")
	collection.bits = 600000
	var tier_d := ascension.promote(collection, database, target.id)
	_assert(bool(tier_d.get("success", false)) and target.tier == "D", "Tier D must not require a donor")
	bits_before = collection.bits
	invalid = ascension.promote(collection, database, target.id, "missing")
	_assert(not bool(invalid.get("success", false)) and collection.bits == bits_before and collection.get_instances().size() == 6, "Invalid donor must be rejected before Bits or roster mutation")
	var expected_tiers := ["C", "B", "A", "S", "SS", "SSS"]
	var donor_cursor := 0
	for expected_tier: String in expected_tiers:
		var donor_id := ""
		if ["C", "B", "A", "S", "SSS"].has(expected_tier):
			donor_id = donor_ids[donor_cursor]
			donor_cursor += 1
		var result := ascension.promote(collection, database, target.id, donor_id)
		_assert(bool(result.get("success", false)) and target.tier == expected_tier, "Promotion to Tier %s must succeed" % expected_tier)
	_assert(collection.get_instances().size() == 1, "Exactly five duplicate donors must be consumed through SSS")
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
	_assert(absf(float(target.current_hp) / float(expanded_hp_max) - 0.5) <= 0.01, "Expansion must preserve current HP proportion")
	_assert(absf(float(target.current_mp) / float(normal_sp_max) - 0.5) <= 0.01, "Expansion must preserve current SP proportion")
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


func _test_footprint_movement() -> void:
	var field := MockField.new()
	var controller := MockController.new()
	var movement: MovementSystem = MovementScript.new()
	var actor := MockActor.new(Vector2i(1, 2), "large_2x2", true)
	field.costs[Vector2i(3, 2)] = 2
	field.costs[Vector2i(3, 3)] = 4
	var reachable := movement.get_reachable_tiles(field, controller, actor, actor.anchor, 3)
	_assert(not reachable.has(Vector2i(2, 2)), "A step must charge the highest newly occupied terrain cost")
	reachable = movement.get_reachable_tiles(field, controller, actor, actor.anchor, 4)
	_assert(int(reachable.get(Vector2i(2, 2), -1)) == 4, "A 2x2 step must use the expensive leading cell exactly once")

	field.costs.clear()
	field.blocked[Vector2i(3, 3)] = true
	_assert(movement.find_path(field, controller, actor, actor.anchor, Vector2i(2, 2), 1).is_empty(), "A single blocked support cell must stop the complete footprint")
	field.blocked.clear()
	var ally := MockActor.new(Vector2i(2, 2), "single", true)
	controller.occupants[Vector2i(2, 2)] = ally
	_assert(movement.find_path(field, controller, actor, actor.anchor, Vector2i(2, 2), 1).is_empty(), "Movement cannot end overlapping an ally")
	_assert(movement.find_path(field, controller, actor, actor.anchor, Vector2i(3, 2), 2).size() == 2, "Pathfinding must allow traversing an ally when the destination is clear")
	ally.is_player_controlled = false
	_assert(movement.find_path(field, controller, actor, actor.anchor, Vector2i(3, 2), 2).is_empty(), "Enemy footprints must block traversal")
	field.free()
	controller.free()
	actor.free()
	ally.free()


func _test_footprint_patterns() -> void:
	var field := MockField.new()
	var resolver: TargetPatternResolver = PatternScript.new()
	var source := FootprintScript.occupied_grids(Vector2i(2, 2), "large_2x2")
	var self_area := resolver.effect_grids_for_footprint(field, source, Vector2i(2, 2), {"area": {"shape": "self"}})
	_assert(self_area.size() == 4, "Self area must start from the complete tactical body")
	var line := resolver.effect_grids_for_footprint(field, source, Vector2i(5, 2), {"area": {"shape": "line", "length": 3}})
	_assert(line.size() == 6 and line.has(Vector2i(4, 2)) and line.has(Vector2i(4, 3)), "A 2x2 line must begin as a two-cell front")
	var adjacent_target := FootprintScript.occupied_grids(Vector2i(4, 2), "large_2x2")
	var melee := {"range": {"shape": "adjacent_8", "min": 1, "max": 1}}
	_assert(resolver.is_valid_target_footprint(field, source, adjacent_target, melee), "Footprint adjacency must use the nearest touching edges")
	field.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
