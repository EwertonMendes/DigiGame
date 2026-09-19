extends RefCounted
class_name DigimonAscensionService

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const ExpansionQuestCatalogScript = preload("res://src/quests/ExpansionQuestCatalog.gd")

const RANK_POWER := {
	"Fresh": 0,
	"In-Training": 1,
	"Rookie": 2,
	"Champion": 3,
	"Armor": 3,
	"Ultimate": 4,
	"Hybrid": 4,
	"Mega": 5,
	"Ultra": 6,
}

var _balance = BalanceScript.new()
var _calculator = StatCalculatorScript.new()


func promotion_preview(collection: PlayerCollection, database: DigimonDatabase, target_id: String, donor_id: String = "") -> Dictionary:
	var result := {
		"success": false,
		"reason": "invalid",
		"target_id": target_id,
		"donor_id": donor_id,
		"current_tier": "E",
		"target_tier": "",
		"bits_cost": 0,
		"minimum_rank": "Fresh",
		"fusion_required": false,
	}
	if collection == null or database == null:
		return result
	var target := collection.get_instance(target_id)
	if target == null:
		result["reason"] = "target_not_found"
		return result
	var current_tier := _balance.normalize_tier(target.tier)
	var next_tier := _balance.next_tier(current_tier)
	result["current_tier"] = current_tier
	result["target_tier"] = next_tier
	if next_tier.is_empty():
		result["reason"] = "maximum_tier"
		return result
	var species := database.get_by_seed(target.species_seed)
	if species.is_empty():
		result["reason"] = "unknown_species"
		return result
	var minimum_rank := _balance.tier_minimum_rank(next_tier)
	var bits_cost := _balance.tier_promotion_bits(next_tier)
	var fusion_required := _balance.tier_fusion_required(next_tier)
	result["bits_cost"] = bits_cost
	result["minimum_rank"] = minimum_rank
	result["fusion_required"] = fusion_required
	result["current_rank"] = String(species.get("rank", "Fresh"))
	if not _rank_meets(String(species.get("rank", "Fresh")), minimum_rank):
		result["reason"] = "rank_too_low"
		return result
	if collection.bits < bits_cost:
		result["reason"] = "insufficient_bits"
		return result
	if fusion_required:
		var donor := collection.get_instance(donor_id)
		if donor == null or donor == target:
			result["reason"] = "donor_required"
			return result
		if collection.get_location(donor.id) != PlayerCollection.LOCATION_STORAGE:
			result["reason"] = "donor_not_in_storage"
			return result
		if donor.species_seed != target.species_seed:
			result["reason"] = "donor_species_mismatch"
			return result
		if not donor.equipment.is_empty():
			result["reason"] = "donor_has_equipment"
			return result
	result["success"] = true
	result["reason"] = ""
	return result


func promote(collection: PlayerCollection, database: DigimonDatabase, target_id: String, donor_id: String = "") -> Dictionary:
	var preview := promotion_preview(collection, database, target_id, donor_id)
	if not bool(preview.get("success", false)):
		return preview
	var target := collection.get_instance(target_id)
	var donor := collection.get_instance(donor_id) if bool(preview.get("fusion_required", false)) else null
	var species := database.get_by_seed(target.species_seed)
	var old_hp_max := _calculator.get_stat(target, species, "hp")
	var old_sp_max := _calculator.get_stat(target, species, "mp")
	if donor != null:
		if not collection.remove_storage_instance(donor.id):
			preview["success"] = false
			preview["reason"] = "donor_removal_failed"
			return preview
		_merge_technique_knowledge(target, donor)
	collection.bits -= int(preview.get("bits_cost", 0))
	target.tier = String(preview.get("target_tier", "E"))
	_preserve_resource_ratios(target, species, old_hp_max, old_sp_max)
	preview["new_tier"] = target.tier
	preview["techniques_merged"] = donor != null
	var expansion_tier := _balance.expansion_string("requiredTier", "S")
	if _balance.tier_index(target.tier) >= _balance.tier_index(expansion_tier):
		preview["expansion_quest_active"] = ExpansionQuestCatalogScript.unlock_for_tier_s(collection)
	return preview


func eligible_donors(collection: PlayerCollection, target_id: String) -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	if collection == null:
		return result
	var target := collection.get_instance(target_id)
	if target == null:
		return result
	for candidate: DigimonInstance in collection.get_storage_instances():
		if candidate.id == target.id or candidate.species_seed != target.species_seed:
			continue
		if not candidate.equipment.is_empty():
			continue
		result.append(candidate)
	return result


func craft_expansion_core(collection: PlayerCollection) -> Dictionary:
	var fragment_id := _balance.expansion_string("fragmentItemId", "expansion_fragment")
	var core_id := _balance.expansion_string("coreItemId", "expansion_core")
	var fragment_cost := maxi(1, _balance.expansion_int("fragmentCraftCost", 5))
	var bits_cost := maxi(0, _balance.expansion_int("craftBitsCost", 50000))
	var result := {"success": false, "reason": "invalid", "fragment_cost": fragment_cost, "bits_cost": bits_cost}
	if collection == null:
		return result
	if collection.get_item_count(fragment_id) < fragment_cost:
		result["reason"] = "insufficient_fragments"
		return result
	if collection.bits < bits_cost:
		result["reason"] = "insufficient_bits"
		return result
	if not collection.consume_item(fragment_id, fragment_cost):
		result["reason"] = "fragment_consumption_failed"
		return result
	collection.bits -= bits_cost
	collection.add_item(core_id, 1)
	result["success"] = true
	result["reason"] = ""
	result["core_count"] = collection.get_item_count(core_id)
	return result


func unlock_expansion(collection: PlayerCollection, database: DigimonDatabase, target_id: String) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "target_id": target_id}
	if collection == null or database == null:
		return result
	var target := collection.get_instance(target_id)
	if target == null:
		result["reason"] = "target_not_found"
		return result
	if target.expansion_unlocked:
		result["reason"] = "already_unlocked"
		return result
	var required_tier := _balance.expansion_string("requiredTier", "S")
	if _balance.tier_index(target.tier) < _balance.tier_index(required_tier):
		result["reason"] = "tier_too_low"
		return result
	var core_id := _balance.expansion_string("coreItemId", "expansion_core")
	if collection.get_item_count(core_id) < 1:
		result["reason"] = "core_required"
		return result
	if not collection.consume_item(core_id, 1):
		result["reason"] = "core_consumption_failed"
		return result
	target.expansion_unlocked = true
	result["success"] = true
	result["reason"] = ""
	return result


func set_expanded(database: DigimonDatabase, target: DigimonInstance, expanded: bool) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "expanded": false}
	if database == null or target == null:
		return result
	if expanded and not target.expansion_unlocked:
		result["reason"] = "expansion_locked"
		return result
	var species := database.get_by_seed(target.species_seed)
	if species.is_empty():
		result["reason"] = "unknown_species"
		return result
	var old_hp_max := _calculator.get_stat(target, species, "hp")
	var old_sp_max := _calculator.get_stat(target, species, "mp")
	if not target.set_battle_footprint(FootprintScript.LARGE_2X2 if expanded else FootprintScript.SINGLE):
		result["reason"] = "expansion_locked"
		return result
	_preserve_resource_ratios(target, species, old_hp_max, old_sp_max)
	result["success"] = true
	result["reason"] = ""
	result["expanded"] = target.is_expanded()
	return result


func _rank_meets(current_rank: String, required_rank: String) -> bool:
	return int(RANK_POWER.get(current_rank, -1)) >= int(RANK_POWER.get(required_rank, 0))


func _merge_technique_knowledge(target: DigimonInstance, donor: DigimonInstance) -> void:
	for skill_id: String in donor.learned_skills:
		var was_known := target.learned_skills.has(skill_id)
		if not was_known:
			target.learned_skills.append(skill_id)
			if not target.archived_skills.has(skill_id):
				target.archived_skills.append(skill_id)
		var best_mastery := maxi(target.get_skill_mastery_points(skill_id), donor.get_skill_mastery_points(skill_id))
		target.skill_mastery[skill_id] = best_mastery


func _preserve_resource_ratios(target: DigimonInstance, species: Dictionary, old_hp_max: int, old_sp_max: int) -> void:
	var hp_ratio := float(target.current_hp) / float(maxi(1, old_hp_max))
	var sp_ratio := float(target.current_mp) / float(maxi(1, old_sp_max)) if old_sp_max > 0 else 0.0
	var new_hp_max := _calculator.get_stat(target, species, "hp")
	var new_sp_max := _calculator.get_stat(target, species, "mp")
	target.current_hp = clampi(int(round(hp_ratio * float(new_hp_max))), 0, new_hp_max)
	target.current_mp = clampi(int(round(sp_ratio * float(new_sp_max))), 0, new_sp_max)
