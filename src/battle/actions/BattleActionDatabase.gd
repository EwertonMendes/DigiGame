extends RefCounted
class_name BattleActionDatabase

const TECHNIQUES_PATH := "res://database/techniques.json"
const LEARNSETS_PATH := "res://database/digimon-learnsets.json"
const RECORDS_PATH := "res://database/technique-records.json"
const CURATION_PATH := "res://database/technique-curation.json"
const EXPERIENCED_POINTS := 8
const MASTERED_POINTS := 24

var _actions: Dictionary = {}
var _learnsets_by_seed: Dictionary = {}
var _legacy_learnsets_by_name: Dictionary = {}
var _records: Dictionary = {}
var _legacy_skill_aliases_by_seed: Dictionary = {}
var _legacy_skill_aliases_by_name: Dictionary = {}


func load_default() -> bool:
	_actions.clear()
	_learnsets_by_seed.clear()
	_legacy_learnsets_by_name.clear()
	_records.clear()
	_legacy_skill_aliases_by_seed.clear()
	_legacy_skill_aliases_by_name.clear()
	if not _load_actions():
		return false
	_load_learnsets()
	_load_records()
	_load_legacy_skill_aliases()
	return true


func get_action(action_id: String, mastery_points: int = 0) -> Dictionary:
	if not _actions.has(action_id):
		return {}
	var action := (_actions[action_id] as Dictionary).duplicate(true)
	_apply_localized_fallbacks(action)
	return _apply_mastery(action, mastery_points)


func get_all_actions(include_unavailable: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_id in _actions.keys():
		var action := get_action(String(raw_id))
		if include_unavailable or String(action.get("availability", "ready")) == "ready":
			result.append(action)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("name", "")) < String(b.get("name", "")))
	return result


func resolve_skill_id(species_seed_or_name: String, skill_id: String) -> String:
	var clean_id := skill_id.strip_edges()
	if clean_id.is_empty():
		return ""
	var species_key := species_seed_or_name.to_lower().strip_edges()
	var aliases = _legacy_skill_aliases_by_seed.get(
		species_key,
		_legacy_skill_aliases_by_name.get(species_key, {})
	)
	if aliases is Dictionary:
		var replacement := String((aliases as Dictionary).get(clean_id, clean_id)).strip_edges()
		if not replacement.is_empty():
			return replacement
	return clean_id


func get_known_actions(species_seed: String, level: int, learned_ids: Array[String] = [], mastery: Dictionary = {}) -> Array[Dictionary]:
	var ids: Array[String] = []
	for learned_id: String in learned_ids:
		var resolved_id := resolve_skill_id(species_seed, learned_id)
		if _actions.has(resolved_id) and not ids.has(resolved_id):
			ids.append(resolved_id)
	for entry: Dictionary in get_learnset_entries(species_seed):
		if int(entry.get("level", 1)) > level:
			continue
		var action_id := resolve_skill_id(species_seed, String(entry.get("skill", "")))
		if _actions.has(action_id) and not ids.has(action_id):
			ids.append(action_id)
	var result: Array[Dictionary] = []
	for action_id: String in ids:
		var mastery_points := int(mastery.get(action_id, 0))
		for raw_mastery_id in mastery.keys():
			if resolve_skill_id(species_seed, String(raw_mastery_id)) == action_id:
				mastery_points = maxi(mastery_points, int(mastery[raw_mastery_id]))
		var action := get_action(action_id, mastery_points)
		if String(action.get("availability", "ready")) == "ready":
			result.append(action)
	return result


func get_learnset_entries(species_seed: String) -> Array[Dictionary]:
	var key := species_seed.to_lower().strip_edges()
	var raw_entries = _learnsets_by_seed.get(key, _legacy_learnsets_by_name.get(key, []))
	var result: Array[Dictionary] = []
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if raw_entry is Dictionary:
				result.append((raw_entry as Dictionary).duplicate(true))
	return result


func get_signature_action_ids(species_seed: String) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in get_learnset_entries(species_seed):
		if String(entry.get("acquisition", "level")) != "signature":
			continue
		var skill_id := resolve_skill_id(species_seed, String(entry.get("skill", "")))
		if _actions.has(skill_id) and not result.has(skill_id):
			result.append(skill_id)
	return result


func get_default_action_for_species(species_seed: String, level: int) -> Dictionary:
	var actions := get_known_actions(species_seed, level)
	return actions[0] if not actions.is_empty() else {}


func get_record(skill_id: String) -> Dictionary:
	return (_records[skill_id] as Dictionary).duplicate(true) if _records.has(skill_id) else {}


func can_teach(skill_id: String, species: Dictionary) -> bool:
	var record := get_record(skill_id)
	if record.is_empty() or not bool(record.get("teachable", false)):
		return false
	var species_seed := String(species.get("seed", ""))
	var denied = record.get("denySpeciesSeeds", [])
	if denied is Array and (denied as Array).has(species_seed):
		return false
	var allowed = record.get("allowSpeciesSeeds", [])
	if allowed is Array and (allowed as Array).has(species_seed):
		return true
	var species_tags: Array[String] = []
	var raw_tags = species.get("techniqueTags", [])
	if raw_tags is Array:
		for raw_tag in raw_tags:
			species_tags.append(String(raw_tag))
	for fallback_tag in _fallback_species_tags(species):
		if not species_tags.has(fallback_tag):
			species_tags.append(fallback_tag)
	var all_of = record.get("allOf", [])
	if all_of is Array:
		for raw_tag in all_of:
			if not species_tags.has(String(raw_tag)):
				return false
	var any_of = record.get("anyOf", [])
	if any_of is Array and not (any_of as Array).is_empty():
		for raw_tag in any_of:
			if species_tags.has(String(raw_tag)):
				return true
		return false
	return true


func _load_actions() -> bool:
	if not FileAccess.file_exists(TECHNIQUES_PATH):
		push_error("Missing techniques database: %s" % TECHNIQUES_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TECHNIQUES_PATH))
	if not parsed is Array:
		push_error("Techniques database must be an array")
		return false
	for raw_action in parsed:
		if not raw_action is Dictionary:
			continue
		var action_id := String(raw_action.get("id", "")).strip_edges()
		if action_id.is_empty():
			continue
		_actions[action_id] = raw_action.duplicate(true)
	return not _actions.is_empty()


func _load_learnsets() -> void:
	if not FileAccess.file_exists(LEARNSETS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEARNSETS_PATH))
	if not parsed is Array:
		return
	for raw_learnset in parsed:
		if not raw_learnset is Dictionary:
			continue
		var skills = raw_learnset.get("skills", [])
		if not skills is Array:
			continue
		var seed := String(raw_learnset.get("speciesSeed", "")).to_lower().strip_edges()
		if not seed.is_empty():
			_learnsets_by_seed[seed] = skills.duplicate(true)
		var species_name := String(raw_learnset.get("species", "")).to_lower().strip_edges()
		if not species_name.is_empty():
			_legacy_learnsets_by_name[species_name] = skills.duplicate(true)


func _load_records() -> void:
	if not FileAccess.file_exists(RECORDS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	if not parsed is Array:
		return
	for raw_record in parsed:
		if not raw_record is Dictionary:
			continue
		var skill_id := String(raw_record.get("skill", "")).strip_edges()
		if not skill_id.is_empty() and _actions.has(skill_id):
			_records[skill_id] = raw_record.duplicate(true)


func _load_legacy_skill_aliases() -> void:
	if not FileAccess.file_exists(CURATION_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CURATION_PATH))
	if not parsed is Dictionary:
		return
	var curated_learnsets = (parsed as Dictionary).get("learnsets", [])
	if not curated_learnsets is Array:
		return
	for raw_learnset in curated_learnsets:
		if not raw_learnset is Dictionary:
			continue
		var raw_aliases = (raw_learnset as Dictionary).get("legacySkillAliases", {})
		if not raw_aliases is Dictionary:
			continue
		var aliases: Dictionary = {}
		for raw_legacy_id in (raw_aliases as Dictionary).keys():
			var legacy_id := String(raw_legacy_id).strip_edges()
			var replacement_id := String((raw_aliases as Dictionary)[raw_legacy_id]).strip_edges()
			if legacy_id.is_empty() or replacement_id.is_empty() or not _actions.has(replacement_id):
				continue
			aliases[legacy_id] = replacement_id
		if aliases.is_empty():
			continue
		var seed := String((raw_learnset as Dictionary).get("speciesSeed", "")).to_lower().strip_edges()
		if not seed.is_empty():
			_legacy_skill_aliases_by_seed[seed] = aliases.duplicate(true)
		var species_name := String((raw_learnset as Dictionary).get("species", "")).to_lower().strip_edges()
		if not species_name.is_empty():
			_legacy_skill_aliases_by_name[species_name] = aliases.duplicate(true)


func _apply_localized_fallbacks(action: Dictionary) -> void:
	var names = action.get("names", {})
	if names is Dictionary:
		action["name"] = String((names as Dictionary).get("en", action.get("name", action.get("id", "Technique"))))
		action["namePtBr"] = String((names as Dictionary).get("pt_BR", action.get("name", "")))
	var descriptions = action.get("descriptions", {})
	if descriptions is Dictionary:
		action["description"] = String((descriptions as Dictionary).get("en", action.get("description", "")))
		action["descriptionPtBr"] = String((descriptions as Dictionary).get("pt_BR", action.get("description", "")))


func _apply_mastery(action: Dictionary, points: int) -> Dictionary:
	var bounded_points := clampi(points, 0, MASTERED_POINTS)
	var grade := "mastered" if bounded_points >= MASTERED_POINTS else ("experienced" if bounded_points >= EXPERIENCED_POINTS else "learned")
	action["masteryPoints"] = bounded_points
	action["masteryGrade"] = grade
	if grade == "learned":
		return action
	var mastered := grade == "mastered"
	match String(action.get("masteryProfile", "swift")):
		"efficient":
			action["spCost"] = maxi(0, int(action.get("spCost", 0)) - (2 if mastered else 1))
		"precise":
			action["accuracy"] = minf(100.0, float(action.get("accuracy", 100.0)) + (10.0 if mastered else 5.0))
		"reliable_effect":
			var effects = action.get("effects", [])
			if effects is Array:
				for effect in effects:
					if effect is Dictionary and (effect as Dictionary).has("chance"):
						effect["chance"] = minf(100.0, float(effect.get("chance", 100.0)) + (10.0 if mastered else 5.0))
		"potent":
			var potent_multiplier := 1.10 if mastered else 1.05
			action["power"] = maxi(0, int(round(float(action.get("power", 0)) * potent_multiplier)))
			var effects = action.get("effects", [])
			if effects is Array:
				for effect in effects:
					if effect is Dictionary and String((effect as Dictionary).get("type", "")) == "heal" and effect.has("percentMaxHp"):
						effect["percentMaxHp"] = float(effect.get("percentMaxHp", 0.0)) * potent_multiplier
		_:
			action["recoveryCost"] = maxf(1.0, float(action.get("recoveryCost", 30.0)) - (10.0 if mastered else 5.0))
	return action


func _fallback_species_tags(species: Dictionary) -> Array[String]:
	var result: Array[String] = ["neutral", "melee"]
	var family := String(species.get("species", species.get("family", ""))).to_lower()
	var name := String(species.get("name", "")).to_lower()
	var movement := String(species.get("movementType", "ground")).to_lower()
	var element := String(species.get("element", "neutral")).to_lower()
	if not result.has(element):
		result.append(element)
	if movement == "flying":
		result.append("aerial")
	if family.contains("aqua") or family.contains("sea") or family.contains("fish"):
		result.append("aquatic")
	if family.contains("machine") or family.contains("steel"):
		result.append("machine")
		result.append("projectile")
	if family.contains("insect") or family.contains("plant"):
		result.append("plant")
	if family.contains("dragon") or family.contains("dinosaur"):
		result.append("breath")
		result.append("claw")
	if family.contains("beast") or family.contains("animal"):
		result.append("bite")
		result.append("claw")
	if family.contains("holy") or family.contains("dark") or int(species.get("int", 0)) >= int(species.get("atk", 0)):
		result.append("magic")
		result.append("healing")
	if family.contains("knight") or name.contains("mon") and (name.contains("sword") or name.contains("blade")):
		result.append("weapon")
	return result
