extends RefCounted
class_name DigimonInstance

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "int", "speed"]
const MAX_POTENTIAL := 100
const MAX_LINK := 100
const MAX_FAVORITE_SKILLS := 6
const MAX_SKILL_MASTERY_POINTS := 24
const EXPERIENCED_SKILL_MASTERY_POINTS := 8

var id: String = ""
var species_seed: String = ""
var nickname: String = ""
var level: int = 1
var exp: int = 0
var potential: int = 0
# Persistent affinity/synergy progression owned by this individual. This is not
# an in-battle transformation resource; tactical Link mechanics may read it as
# progression context without coupling evolution to battle runtime state.
var link: int = 0
var aptitudes: Dictionary = {}
var training: Dictionary = {}
var current_hp: int = 1
# Internally kept as current_mp for save compatibility. UI/gameplay calls it SP.
var current_mp: int = 0
var learned_skills: Array[String] = []
var favorite_skills: Array[String] = []
var archived_skills: Array[String] = []
var skill_mastery: Dictionary = {}
var equipment: Array[String] = []
var evolution_history: Array[Dictionary] = []
var species_history: Array[String] = []
var evolution_goal_seed: String = ""
var origin: String = "generated"


func _init() -> void:
	id = generate_uuid()
	_reset_build_values()


func _reset_build_values() -> void:
	aptitudes.clear()
	training.clear()
	for stat_key: String in STAT_KEYS:
		aptitudes[stat_key] = 0
		training[stat_key] = 0
	training["mov"] = 0


func get_display_name(fallback_species_name: String) -> String:
	return nickname if not nickname.strip_edges().is_empty() else fallback_species_name


func get_current_sp() -> int:
	return current_mp


func set_current_sp(value: int) -> void:
	current_mp = maxi(0, value)


func learn_skill(skill_id: String, favorite_if_possible: bool = true) -> bool:
	var clean_id := skill_id.strip_edges()
	if clean_id.is_empty():
		return false
	var changed := false
	if not learned_skills.has(clean_id):
		learned_skills.append(clean_id)
		skill_mastery[clean_id] = 0
		changed = true
	if favorite_if_possible and favorite_skills.size() < MAX_FAVORITE_SKILLS and not favorite_skills.has(clean_id):
		favorite_skills.append(clean_id)
		changed = true
	return changed


func favorite_skill(skill_id: String) -> bool:
	if not learned_skills.has(skill_id) or favorite_skills.has(skill_id):
		return false
	if favorite_skills.size() >= MAX_FAVORITE_SKILLS:
		return false
	archived_skills.erase(skill_id)
	favorite_skills.append(skill_id)
	return true


func unfavorite_skill(skill_id: String) -> bool:
	var index := favorite_skills.find(skill_id)
	if index < 0:
		return false
	favorite_skills.remove_at(index)
	return true


func move_favorite(skill_id: String, new_index: int) -> bool:
	var old_index := favorite_skills.find(skill_id)
	if old_index < 0:
		return false
	var bounded_index := clampi(new_index, 0, favorite_skills.size() - 1)
	if old_index == bounded_index:
		return true
	favorite_skills.remove_at(old_index)
	favorite_skills.insert(bounded_index, skill_id)
	return true


func archive_skill(skill_id: String) -> bool:
	if not learned_skills.has(skill_id) or archived_skills.has(skill_id):
		return false
	favorite_skills.erase(skill_id)
	archived_skills.append(skill_id)
	return true


func restore_skill(skill_id: String) -> bool:
	var index := archived_skills.find(skill_id)
	if index < 0:
		return false
	archived_skills.remove_at(index)
	return true


func record_effective_skill_uses(skill_id: String, amount: int = 1) -> int:
	if not learned_skills.has(skill_id) or amount <= 0:
		return get_skill_mastery_points(skill_id)
	var points := clampi(get_skill_mastery_points(skill_id) + amount, 0, MAX_SKILL_MASTERY_POINTS)
	skill_mastery[skill_id] = points
	return points


func get_skill_mastery_points(skill_id: String) -> int:
	return clampi(int(skill_mastery.get(skill_id, 0)), 0, MAX_SKILL_MASTERY_POINTS)


func get_skill_mastery_grade(skill_id: String) -> String:
	var points := get_skill_mastery_points(skill_id)
	if points >= MAX_SKILL_MASTERY_POINTS:
		return "mastered"
	if points >= EXPERIENCED_SKILL_MASTERY_POINTS:
		return "experienced"
	return "learned"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"speciesSeed": species_seed,
		"nickname": nickname,
		"level": level,
		"exp": exp,
		"potential": potential,
		"link": link,
		"aptitudes": aptitudes.duplicate(true),
		"training": training.duplicate(true),
		"currentHp": current_hp,
		"currentSp": current_mp,
		"currentMp": current_mp,
		"learnedSkills": learned_skills.duplicate(),
		"favoriteSkills": favorite_skills.duplicate(),
		"archivedSkills": archived_skills.duplicate(),
		"skillMastery": skill_mastery.duplicate(true),
		"equipment": equipment.duplicate(),
		"evolutionHistory": evolution_history.duplicate(true),
		"speciesHistory": species_history.duplicate(),
		"evolutionGoalSeed": evolution_goal_seed,
		"origin": origin,
	}


static func from_dict(data: Dictionary) -> DigimonInstance:
	var instance := DigimonInstance.new()
	instance.id = String(data.get("id", generate_uuid()))
	instance.species_seed = String(data.get("speciesSeed", ""))
	instance.nickname = String(data.get("nickname", ""))
	var balance = BalanceScript.new()
	instance.level = clampi(int(data.get("level", 1)), 1, balance.max_level())
	instance.exp = maxi(0, int(data.get("exp", 0)))
	instance.potential = clampi(int(data.get("potential", 0)), 0, MAX_POTENTIAL)
	instance.link = clampi(int(data.get("link", 0)), 0, MAX_LINK)

	var loaded_aptitudes = data.get("aptitudes", {})
	if loaded_aptitudes is Dictionary:
		for stat_key: String in STAT_KEYS:
			instance.aptitudes[stat_key] = clampi(int(loaded_aptitudes.get(stat_key, 0)), -3, 3)

	var loaded_training = data.get("training", {})
	if loaded_training is Dictionary:
		for stat_key: String in STAT_KEYS:
			instance.training[stat_key] = maxi(0, int(loaded_training.get(stat_key, 0)))
		instance.training["mov"] = clampi(int(loaded_training.get("mov", 0)), 0, 2)

	instance.current_hp = maxi(0, int(data.get("currentHp", 1)))
	instance.current_mp = maxi(0, int(data.get("currentSp", data.get("currentMp", 0))))

	instance.learned_skills.clear()
	var skills = data.get("learnedSkills", [])
	if skills is Array:
		for skill in skills:
			var skill_id := String(skill)
			if not skill_id.is_empty() and not instance.learned_skills.has(skill_id):
				instance.learned_skills.append(skill_id)

	instance.favorite_skills.clear()
	var favorite_skills_data = data.get("favoriteSkills", data.get("equippedSkills", []))
	if favorite_skills_data is Array:
		for skill in favorite_skills_data:
			var skill_id := String(skill)
			if instance.learned_skills.has(skill_id) and not instance.favorite_skills.has(skill_id) and instance.favorite_skills.size() < MAX_FAVORITE_SKILLS:
				instance.favorite_skills.append(skill_id)

	instance.archived_skills.clear()
	var archived_skills_data = data.get("archivedSkills", [])
	if archived_skills_data is Array:
		for skill in archived_skills_data:
			var skill_id := String(skill)
			if instance.learned_skills.has(skill_id) and not instance.archived_skills.has(skill_id):
				instance.archived_skills.append(skill_id)
				instance.favorite_skills.erase(skill_id)

	instance.skill_mastery.clear()
	var mastery_data = data.get("skillMastery", {})
	for skill_id: String in instance.learned_skills:
		var points := int((mastery_data as Dictionary).get(skill_id, 0)) if mastery_data is Dictionary else 0
		instance.skill_mastery[skill_id] = clampi(points, 0, MAX_SKILL_MASTERY_POINTS)

	instance.equipment.clear()
	var equipped = data.get("equipment", [])
	if equipped is Array:
		for item in equipped:
			instance.equipment.append(String(item))

	instance.evolution_history.clear()
	var history = data.get("evolutionHistory", [])
	if history is Array:
		for record in history:
			if record is Dictionary:
				instance.evolution_history.append(record.duplicate(true))

	instance.species_history.clear()
	var species_history_data = data.get("speciesHistory", [])
	if species_history_data is Array:
		for raw_seed in species_history_data:
			var seed := String(raw_seed).strip_edges()
			if not seed.is_empty():
				instance.species_history.append(seed)
	if instance.species_history.is_empty():
		for record: Dictionary in instance.evolution_history:
			var from_seed := String(record.get("fromSeed", "")).strip_edges()
			var to_seed := String(record.get("toSeed", "")).strip_edges()
			if instance.species_history.is_empty() and not from_seed.is_empty():
				instance.species_history.append(from_seed)
			if not to_seed.is_empty():
				instance.species_history.append(to_seed)
	if instance.species_history.is_empty() and not instance.species_seed.is_empty():
		instance.species_history.append(instance.species_seed)

	instance.evolution_goal_seed = String(data.get("evolutionGoalSeed", ""))
	instance.origin = String(data.get("origin", "generated"))
	return instance


static func generate_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return "%d-%d" % [Time.get_unix_time_from_system(), randi()]
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := ""
	for byte_value in bytes:
		hex += "%02x" % int(byte_value)
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
