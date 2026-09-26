extends RefCounted
class_name FusionService

const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _database: DigimonDatabase
var _catalog: FusionCatalog
var _factory: DigimonFactory
var _stats = StatCalculatorScript.new()
var _balance = BalanceScript.new()


func _init(database: DigimonDatabase, catalog: FusionCatalog) -> void:
	_database = database
	_catalog = catalog
	_factory = FactoryScript.new(database) if database != null else null


func get_eligible_instances(collection: PlayerCollection, fusion_id: String, slot_index: int) -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	if collection == null or _catalog == null:
		return result
	var definition := _catalog.get_by_id(fusion_id)
	var slots := _expanded_digimon_requirements(definition)
	if slot_index < 0 or slot_index >= slots.size():
		return result
	var requirement := slots[slot_index]
	var seed := String(requirement.get("speciesSeed", ""))
	var min_level := int(requirement.get("minLevel", 1))
	for instance: DigimonInstance in collection.get_instances():
		if instance.species_seed != seed or instance.level < min_level:
			continue
		if collection.is_hospitalized(instance.id) or instance.is_fainted() or not instance.equipment.is_empty():
			continue
		result.append(instance)
	result.sort_custom(func(a: DigimonInstance, b: DigimonInstance) -> bool:
		if a.level == b.level:
			return a.id < b.id
		return a.level < b.level
	)
	return result


func get_preview(collection: PlayerCollection, fusion_id: String, selected_ids: Array[String] = []) -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	var preview := {
		"success": false,
		"reason": "invalid",
		"fusion_id": clean_id,
		"unlocked": false,
		"data": 0,
		"definition": {},
		"selected_ids": [],
		"material_slots": [],
		"item_requirements": [],
		"result_seed": "",
		"result_name": "",
		"result_potential": 0,
		"result_tier": DigimonInstance.DEFAULT_TIER,
		"can_fuse": false,
	}
	if collection == null or _database == null or _catalog == null:
		return preview
	var definition := _catalog.get_by_id(clean_id)
	if definition.is_empty():
		preview["reason"] = "unknown_fusion"
		return preview
	preview["definition"] = definition
	var result_seed := String(definition.get("resultSeed", ""))
	var result_species := _database.get_by_seed(result_seed)
	if result_species.is_empty():
		preview["reason"] = "unknown_result"
		return preview
	preview["result_seed"] = result_seed
	preview["result_name"] = String(result_species.get("name", "Unknown"))
	var data := collection.get_fusion_data(clean_id)
	preview["data"] = data
	preview["unlocked"] = data >= 100
	if data < 100:
		preview["reason"] = "locked"
		return preview

	var slots := _expanded_digimon_requirements(definition)
	var resolved: Array[String] = []
	var used: Dictionary = {}
	var slot_rows: Array[Dictionary] = []
	for index in range(slots.size()):
		var req := slots[index]
		var chosen := String(selected_ids[index]).strip_edges() if index < selected_ids.size() else ""
		var instance := collection.get_instance(chosen) if not chosen.is_empty() else null
		if instance == null or used.has(instance.id) or not _instance_matches(collection, instance, req):
			instance = null
			for candidate: DigimonInstance in get_eligible_instances(collection, clean_id, index):
				if used.has(candidate.id):
					continue
				instance = candidate
				break
		if instance != null:
			used[instance.id] = true
			resolved.append(instance.id)
		else:
			resolved.append("")
		slot_rows.append({
			"index": index,
			"speciesSeed": String(req.get("speciesSeed", "")),
			"minLevel": int(req.get("minLevel", 1)),
			"instanceId": instance.id if instance != null else "",
			"level": instance.level if instance != null else 0,
			"valid": instance != null,
		})
	preview["selected_ids"] = resolved
	preview["material_slots"] = slot_rows

	var item_rows: Array[Dictionary] = []
	var item_costs: Dictionary = {}
	for material: Dictionary in definition.get("materials", []):
		if String(material.get("type", "")) != "item":
			continue
		var item_id := String(material.get("itemId", ""))
		var amount := maxi(1, int(material.get("amount", 1)))
		var consume := bool(material.get("consume", true))
		var owned := collection.get_item_count(item_id)
		item_rows.append({"itemId": item_id, "amount": amount, "owned": owned, "consume": consume, "valid": owned >= amount})
		if consume:
			item_costs[item_id] = int(item_costs.get(item_id, 0)) + amount
	preview["item_requirements"] = item_rows

	var material_instances: Array[DigimonInstance] = []
	for instance_id: String in resolved:
		if instance_id.is_empty():
			preview["reason"] = "missing_material"
			return preview
		var instance := collection.get_instance(instance_id)
		if instance == null:
			preview["reason"] = "missing_material"
			return preview
		material_instances.append(instance)
	for row: Dictionary in item_rows:
		if not bool(row.get("valid", false)):
			preview["reason"] = "missing_item"
			return preview

	preview["result_potential"] = _result_potential(material_instances)
	preview["result_tier"] = _result_tier(material_instances)
	preview["item_costs"] = item_costs
	preview["destination"] = _destination(collection, material_instances)
	preview["can_fuse"] = true
	preview["success"] = true
	preview["reason"] = ""
	return preview


func fuse(collection: PlayerCollection, fusion_id: String, selected_ids: Array[String] = []) -> Dictionary:
	var preview := get_preview(collection, fusion_id, selected_ids)
	if not bool(preview.get("can_fuse", false)):
		return preview
	var result_seed := String(preview.get("result_seed", ""))
	var result_species := _database.get_by_seed(result_seed)
	var result := _factory.create_player_by_seed(result_seed, 1, 100)
	if result == null:
		preview["success"] = false
		preview["can_fuse"] = false
		preview["reason"] = "result_creation_failed"
		return preview

	var material_instances: Array[DigimonInstance] = []
	for instance_id: String in preview.get("selected_ids", []):
		var material := collection.get_instance(instance_id)
		if material == null:
			preview["success"] = false
			preview["reason"] = "material_changed"
			return preview
		material_instances.append(material)

	result.origin = "fusion"
	result.potential = int(preview.get("result_potential", 0))
	result.tier = String(preview.get("result_tier", DigimonInstance.DEFAULT_TIER))
	_apply_average_aptitudes(result, material_instances)
	for stat_key: String in DigimonInstance.STAT_KEYS:
		result.training[stat_key] = 0
	result.training["mov"] = 0
	_merge_technique_knowledge(result, material_instances)
	var material_seeds: Array[String] = []
	var material_levels: Array[int] = []
	for material: DigimonInstance in material_instances:
		material_seeds.append(material.species_seed)
		material_levels.append(material.level)
	result.fusion_origin = {
		"fusionId": String(preview.get("fusion_id", "")),
		"materialSeeds": material_seeds,
		"materialLevels": material_levels,
	}
	_preserve_lowest_resource_ratio(result, result_species, material_instances)

	var destination := preview.get("destination", {}) as Dictionary
	var committed := collection.commit_fusion(
		preview.get("selected_ids", []),
		result,
		preview.get("item_costs", {}),
		String(destination.get("role", "")),
		int(destination.get("index", -1)),
		String(result_species.get("name", "fusion")).to_lower().replace(" ", "_"),
		String(result_species.get("name", "Fusion"))
	)
	if not committed:
		preview["success"] = false
		preview["can_fuse"] = false
		preview["reason"] = "transaction_failed"
		return preview
	preview["success"] = true
	preview["reason"] = ""
	preview["result_instance_id"] = result.id
	return preview


func _expanded_digimon_requirements(definition: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for material: Dictionary in definition.get("materials", []):
		if String(material.get("type", "")) != "digimon":
			continue
		for _copy in range(maxi(1, int(material.get("amount", 1)))):
			result.append(material.duplicate(true))
	return result


func _instance_matches(collection: PlayerCollection, instance: DigimonInstance, requirement: Dictionary) -> bool:
	return (
		instance != null
		and instance.species_seed == String(requirement.get("speciesSeed", ""))
		and instance.level >= int(requirement.get("minLevel", 1))
		and not collection.is_hospitalized(instance.id)
		and not instance.is_fainted()
		and instance.equipment.is_empty()
	)


func _result_potential(materials: Array[DigimonInstance]) -> int:
	if materials.is_empty():
		return 0
	var total := 0
	for instance: DigimonInstance in materials:
		total += instance.level
	var average := float(total) / float(materials.size())
	var max_level := maxi(1, _balance.fusion_int("potentialMaxMaterialLevel", 99))
	return clampi(int(round(average * float(DigimonInstance.MAX_POTENTIAL) / float(max_level))), 0, DigimonInstance.MAX_POTENTIAL)


func _result_tier(materials: Array[DigimonInstance]) -> String:
	var best := DigimonInstance.DEFAULT_TIER
	for instance: DigimonInstance in materials:
		if _balance.tier_index(instance.tier) > _balance.tier_index(best):
			best = _balance.normalize_tier(instance.tier)
	return best


func _apply_average_aptitudes(result: DigimonInstance, materials: Array[DigimonInstance]) -> void:
	for stat_key: String in DigimonInstance.STAT_KEYS:
		var total := 0
		for instance: DigimonInstance in materials:
			total += int(instance.aptitudes.get(stat_key, 0))
		result.aptitudes[stat_key] = clampi(int(round(float(total) / float(maxi(1, materials.size())))), -3, 3)


func _merge_technique_knowledge(result: DigimonInstance, materials: Array[DigimonInstance]) -> void:
	var signature_favorites := result.favorite_skills.duplicate()
	for material: DigimonInstance in materials:
		for skill_id: String in material.learned_skills:
			if not result.learned_skills.has(skill_id):
				result.learned_skills.append(skill_id)
			result.skill_mastery[skill_id] = maxi(result.get_skill_mastery_points(skill_id), material.get_skill_mastery_points(skill_id))
			if not signature_favorites.has(skill_id) and not result.archived_skills.has(skill_id):
				result.archived_skills.append(skill_id)
	result.favorite_skills = signature_favorites


func _preserve_lowest_resource_ratio(result: DigimonInstance, result_species: Dictionary, materials: Array[DigimonInstance]) -> void:
	var hp_ratio := 1.0
	var sp_ratio := 1.0
	for material: DigimonInstance in materials:
		var species := _database.get_by_seed(material.species_seed)
		var max_hp := maxi(1, _stats.get_stat(material, species, "hp"))
		var max_sp := maxi(0, _stats.get_stat(material, species, "mp"))
		hp_ratio = minf(hp_ratio, float(material.current_hp) / float(max_hp))
		if max_sp > 0:
			sp_ratio = minf(sp_ratio, float(material.current_mp) / float(max_sp))
	var result_hp := maxi(1, _stats.get_stat(result, result_species, "hp"))
	var result_sp := maxi(0, _stats.get_stat(result, result_species, "mp"))
	result.current_hp = clampi(int(round(hp_ratio * float(result_hp))), 1, result_hp)
	result.current_mp = clampi(int(round(sp_ratio * float(result_sp))), 0, result_sp)


func _destination(collection: PlayerCollection, materials: Array[DigimonInstance]) -> Dictionary:
	var active := collection.get_active_party_ids()
	var reserve := collection.get_reserve_party_ids()
	var best_active := 999
	var best_reserve := 999
	for material: DigimonInstance in materials:
		var index := active.find(material.id)
		if index >= 0:
			best_active = mini(best_active, index)
		index = reserve.find(material.id)
		if index >= 0:
			best_reserve = mini(best_reserve, index)
	if best_active != 999:
		return {"role": PlayerCollection.SQUAD_ROLE_ACTIVE, "index": best_active}
	if best_reserve != 999:
		return {"role": PlayerCollection.SQUAD_ROLE_RESERVE, "index": best_reserve}
	return {"role": "", "index": -1}
