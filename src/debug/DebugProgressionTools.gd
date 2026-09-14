extends RefCounted
class_name DebugProgressionTools

const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const AscensionScript = preload("res://src/digimon/DigimonAscensionService.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const MAX_DEBUG_TRAINING_POINTS := 5000

var database: DigimonDatabase
var progression: DigimonProgressionService
var curve: DigimonProgression = ProgressionScript.new()
var calculator: DigimonStatCalculator = StatCalculatorScript.new()
var evolution: DigimonEvolutionService = EvolutionServiceScript.new()
var balance: ProgressionBalance = BalanceScript.new()
var ascension: DigimonAscensionService = AscensionScript.new()
var contexts: Dictionary = {}

func _init() -> void:
	database = OverworldState.get_database() as DigimonDatabase
	progression = ProgressionServiceScript.new(database) as DigimonProgressionService

func instance(instance_id: String) -> DigimonInstance:
	return OverworldState.get_instance_by_id(instance_id)

func display_name(value: DigimonInstance) -> String:
	if value == null:
		return "Unknown"
	var species := database.get_by_seed(value.species_seed)
	return value.get_display_name(String(species.get("name", value.species_seed)))

func tier_options() -> Array[String]:
	return balance.tier_order()

func set_level(instance_id: String, level: int) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.level = clampi(level, 1, curve.max_level())
	value.exp = 0
	_refill(value)
	OverworldState.notify_collection_changed()
	return true

func set_exp(instance_id: String, amount: int) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.exp = 0 if value.level >= curve.max_level() else maxi(0, amount)
	OverworldState.notify_collection_changed()
	return true

func add_xp(instance_id: String, amount: int) -> Dictionary:
	var value := instance(instance_id)
	if value == null:
		return {}
	var result := progression.apply_experience(value, maxi(0, amount))
	_refill(value)
	OverworldState.notify_collection_changed()
	return result

func set_potential(instance_id: String, amount: int) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.potential = clampi(amount, 0, DigimonInstance.MAX_POTENTIAL)
	OverworldState.notify_collection_changed()
	return true

func set_link(instance_id: String, amount: int) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.link = clampi(amount, 0, DigimonInstance.MAX_LINK)
	OverworldState.notify_collection_changed()
	return true

func set_tier_and_expansion(instance_id: String, tier: String, expansion_unlocked: bool, expanded: bool) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	var species := database.get_by_seed(value.species_seed)
	if species.is_empty():
		return false
	var old_hp_max := maxi(1, calculator.get_stat(value, species, "hp"))
	var old_sp_max := maxi(0, calculator.get_stat(value, species, "mp"))
	var hp_ratio := float(value.current_hp) / float(old_hp_max)
	var sp_ratio := float(value.current_mp) / float(maxi(1, old_sp_max)) if old_sp_max > 0 else 0.0
	value.tier = balance.normalize_tier(tier)
	value.expansion_unlocked = expansion_unlocked or expanded
	if not value.set_battle_footprint(FootprintScript.LARGE_2X2 if expanded else FootprintScript.SINGLE):
		return false
	var new_hp_max := maxi(1, calculator.get_stat(value, species, "hp"))
	var new_sp_max := maxi(0, calculator.get_stat(value, species, "mp"))
	value.current_hp = clampi(int(round(hp_ratio * float(new_hp_max))), 0, new_hp_max)
	value.current_mp = clampi(int(round(sp_ratio * float(new_sp_max))), 0, new_sp_max)
	OverworldState.notify_collection_changed()
	return true

func get_item_count(item_id: String) -> int:
	var collection := _collection()
	return collection.get_item_count(item_id) if collection != null else 0

func grant_item(item_id: String, amount: int = 1) -> int:
	var collection := _collection()
	if collection == null or item_id.strip_edges().is_empty() or amount <= 0:
		return get_item_count(item_id)
	var count := collection.add_item(item_id, amount)
	OverworldState.notify_collection_changed()
	return count

func grant_expansion_core(amount: int = 1) -> int:
	return grant_item(balance.expansion_string("coreItemId", "expansion_core"), amount)

func grant_expansion_fragments(amount: int = 1) -> int:
	return grant_item(balance.expansion_string("fragmentItemId", "expansion_fragment"), amount)

func craft_expansion_core() -> Dictionary:
	var collection := _collection()
	if collection == null:
		return {"success": false, "reason": "collection_unavailable"}
	var result := ascension.craft_expansion_core(collection)
	if bool(result.get("success", false)):
		OverworldState.notify_collection_changed()
	return result

func set_resources(instance_id: String, hp: int, sp: int) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	var species := database.get_by_seed(value.species_seed)
	value.current_hp = hp
	value.current_mp = sp
	calculator.clamp_resources(value, species)
	OverworldState.notify_collection_changed()
	return true

func set_training(instance_id: String, values: Dictionary) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	for stat_key: String in DigimonInstance.STAT_KEYS:
		if values.has(stat_key):
			value.training[stat_key] = clampi(int(values.get(stat_key, 0)), 0, MAX_DEBUG_TRAINING_POINTS)
	if values.has("mov"):
		value.training["mov"] = clampi(int(values.get("mov", 0)), 0, 2)
	calculator.clamp_resources(value, database.get_by_seed(value.species_seed))
	OverworldState.notify_collection_changed()
	return true

func set_aptitudes(instance_id: String, values: Dictionary) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	for stat_key: String in DigimonInstance.STAT_KEYS:
		if values.has(stat_key):
			value.aptitudes[stat_key] = clampi(int(values.get(stat_key, 0)), -3, 3)
	calculator.clamp_resources(value, database.get_by_seed(value.species_seed))
	OverworldState.notify_collection_changed()
	return true

func heal(instance_id: String) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	_refill(value)
	OverworldState.notify_collection_changed()
	return true

func set_critical(instance_id: String) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.current_hp = 1
	value.current_mp = 0
	OverworldState.notify_collection_changed()
	return true

func set_knocked_out(instance_id: String) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	value.current_hp = 0
	value.current_mp = 0
	OverworldState.notify_collection_changed()
	return true

func final_stats(instance_id: String) -> Dictionary:
	var value := instance(instance_id)
	return progression.get_final_stats(value) if value != null else {}

func routes(instance_id: String, degenerating: bool = false) -> Array[Dictionary]:
	var value := instance(instance_id)
	if value == null:
		return []
	var context := _context(value.id)
	return evolution.get_available_degenerations(value, database, calculator, context) if degenerating else evolution.get_available_evolutions(value, database, calculator, context)

func meet_requirements(instance_id: String, target_seed: String, degenerating: bool = false) -> Dictionary:
	var value := instance(instance_id)
	if value == null:
		return {"success": false, "reason": "Digimon not found"}
	var route := _find_route(value, target_seed, degenerating)
	if route.is_empty():
		return {"success": false, "reason": "Route not found"}
	var species := database.get_by_seed(value.species_seed)
	var context := _context(value.id)
	var unsupported: Array[String] = []
	var raw_requirements = route.get("requirements", [])
	if raw_requirements is Array:
		for raw_requirement in raw_requirements:
			if raw_requirement is Dictionary and not _meet_requirement(value, species, raw_requirement as Dictionary, context):
				unsupported.append(String((raw_requirement as Dictionary).get("type", "unknown")))
	contexts[value.id] = context
	_refill(value)
	OverworldState.notify_collection_changed()
	var refreshed := _route_from(routes(value.id, degenerating), target_seed)
	return {
		"success": bool(refreshed.get("unlocked", false)),
		"route": refreshed,
		"unsupported": unsupported,
		"reason": "" if bool(refreshed.get("unlocked", false)) else "Some requirements could not be prepared automatically",
	}

func transition(instance_id: String, target_seed: String, degenerating: bool = false, bypass_requirements: bool = false) -> bool:
	var value := instance(instance_id)
	if value == null:
		return false
	var ok := false
	if bypass_requirements:
		ok = evolution.force_degenerate_for_debug(value, target_seed, database, calculator) if degenerating else evolution.force_digivolve_for_debug(value, target_seed, database, calculator)
	else:
		var context := _context(value.id)
		ok = evolution.degenerate(value, target_seed, database, calculator, context) if degenerating else evolution.digivolve(value, target_seed, database, calculator, context)
	if ok:
		contexts.erase(value.id)
		OverworldState.notify_collection_changed()
	return ok

func _meet_requirement(value: DigimonInstance, species: Dictionary, requirement: Dictionary, context: Dictionary) -> bool:
	var kind := String(requirement.get("type", "")).to_lower().strip_edges()
	var required = requirement.get("value", 0)
	match kind:
		"", "none":
			return true
		"level":
			value.level = clampi(maxi(value.level, int(required)), 1, curve.max_level())
			value.exp = 0
			return value.level >= int(required)
		"potential", "abi":
			value.potential = clampi(maxi(value.potential, int(required)), 0, DigimonInstance.MAX_POTENTIAL)
			return value.potential >= int(required)
		"link":
			value.link = clampi(maxi(value.link, int(required)), 0, DigimonInstance.MAX_LINK)
			context["link"] = value.link
			return value.link >= int(required)
		"stat", "hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed":
			return _meet_stat(value, species, requirement, kind)
		"item":
			var key := String(requirement.get("id", requirement.get("item", ""))).strip_edges()
			if key.is_empty():
				return false
			var inventory := _as_dict(context.get("inventory", {}))
			inventory[key] = maxi(int(inventory.get(key, 0)), int(requirement.get("amount", required if int(required) > 0 else 1)))
			context["inventory"] = inventory
			return true
		"battles_won":
			context["battles_won"] = maxi(int(context.get("battles_won", 0)), int(required))
			return true
		"species_defeated":
			var key := String(requirement.get("species_id", requirement.get("id", ""))).strip_edges()
			if key.is_empty():
				return false
			var defeated := _as_dict(context.get("species_defeated", {}))
			defeated[key] = maxi(int(defeated.get(key, 0)), int(required))
			context["species_defeated"] = defeated
			return true
		"quest":
			var key := String(requirement.get("id", "")).strip_edges()
			if key.is_empty():
				return false
			var quests := _as_dict(context.get("quests", {}))
			quests[key] = String(requirement.get("state", "completed"))
			context["quests"] = quests
			return true
		"flag":
			var key := String(requirement.get("id", "")).strip_edges()
			if key.is_empty():
				return false
			var flags := _as_dict(context.get("flags", {}))
			flags[key] = bool(requirement.get("value", true))
			context["flags"] = flags
			return true
		"time":
			context["time"] = maxi(int(context.get("time", 0)), int(required))
			return true
		"party_condition":
			var key := String(requirement.get("id", requirement.get("condition", ""))).strip_edges()
			if key.is_empty():
				return false
			var conditions := _as_dict(context.get("party_conditions", {}))
			conditions[key] = true
			context["party_conditions"] = conditions
			return true
	return false

func _meet_stat(value: DigimonInstance, species: Dictionary, requirement: Dictionary, kind: String) -> bool:
	var stat := String(requirement.get("stat", kind)).to_lower().strip_edges() if kind == "stat" else kind
	stat = {"attack": "atk", "defense": "def", "sp": "mp"}.get(stat, stat)
	if not DigimonInstance.STAT_KEYS.has(stat):
		return false
	var required := int(requirement.get("value", 0))
	var points := maxi(0, int(value.training.get(stat, 0)))
	while calculator.get_stat(value, species, stat) < required and points < MAX_DEBUG_TRAINING_POINTS:
		points += 1
		value.training[stat] = points
	return calculator.get_stat(value, species, stat) >= required

func _find_route(value: DigimonInstance, target_seed: String, degenerating: bool) -> Dictionary:
	var candidates := database.get_degeneration_routes(value.species_seed) if degenerating else database.get_evolution_routes(value.species_seed)
	return _route_from(candidates, target_seed)

func _route_from(candidates: Array[Dictionary], target_seed: String) -> Dictionary:
	for route: Dictionary in candidates:
		if String(route.get("targetSeed", "")) == target_seed:
			return route.duplicate(true)
	return {}

func _context(instance_id: String) -> Dictionary:
	var raw = contexts.get(instance_id, {})
	var result := _as_dict(raw)
	if not result.has("flags"):
		var collection = OverworldState.get("_collection")
		if collection != null:
			result["flags"] = _as_dict(collection.get("progression_flags"))
	return result

func _collection() -> PlayerCollection:
	var raw = OverworldState.get("_collection")
	return raw as PlayerCollection if raw is PlayerCollection else null

func _refill(value: DigimonInstance) -> void:
	calculator.refill_instance(value, database.get_by_seed(value.species_seed))

func _as_dict(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
