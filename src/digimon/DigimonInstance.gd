extends RefCounted
class_name DigimonInstance

const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "int", "speed"]
const MAX_POTENTIAL := 100
const MAX_EQUIPPED_SKILLS := 4

var id: String = ""
var species_seed: String = ""
var nickname: String = ""
var level: int = 1
var exp: int = 0
var potential: int = 0
var aptitudes: Dictionary = {}
var training: Dictionary = {}
var current_hp: int = 1
# Internally kept as current_mp for save compatibility. UI/gameplay calls it SP.
var current_mp: int = 0
var learned_skills: Array[String] = []
var equipped_skills: Array[String] = []
var equipment: Array[String] = []
var evolution_history: Array[Dictionary] = []
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


func learn_skill(skill_id: String, equip_if_possible: bool = true) -> bool:
	var clean_id := skill_id.strip_edges()
	if clean_id.is_empty():
		return false
	var changed := false
	if not learned_skills.has(clean_id):
		learned_skills.append(clean_id)
		changed = true
	if equip_if_possible and equipped_skills.size() < MAX_EQUIPPED_SKILLS and not equipped_skills.has(clean_id):
		equipped_skills.append(clean_id)
		changed = true
	return changed


func equip_skill(skill_id: String) -> bool:
	if not learned_skills.has(skill_id) or equipped_skills.has(skill_id):
		return false
	if equipped_skills.size() >= MAX_EQUIPPED_SKILLS:
		return false
	equipped_skills.append(skill_id)
	return true


func unequip_skill(skill_id: String) -> bool:
	var index := equipped_skills.find(skill_id)
	if index < 0:
		return false
	equipped_skills.remove_at(index)
	return true


func to_dict() -> Dictionary:
	return {
		"id": id,
		"speciesSeed": species_seed,
		"nickname": nickname,
		"level": level,
		"exp": exp,
		"potential": potential,
		"aptitudes": aptitudes.duplicate(true),
		"training": training.duplicate(true),
		"currentHp": current_hp,
		"currentSp": current_mp,
		"currentMp": current_mp,
		"learnedSkills": learned_skills.duplicate(),
		"equippedSkills": equipped_skills.duplicate(),
		"equipment": equipment.duplicate(),
		"evolutionHistory": evolution_history.duplicate(true),
		"evolutionGoalSeed": evolution_goal_seed,
		"origin": origin,
	}


static func from_dict(data: Dictionary) -> DigimonInstance:
	var instance := DigimonInstance.new()
	instance.id = String(data.get("id", generate_uuid()))
	instance.species_seed = String(data.get("speciesSeed", ""))
	instance.nickname = String(data.get("nickname", ""))
	instance.level = clampi(int(data.get("level", 1)), 1, 99)
	instance.exp = maxi(0, int(data.get("exp", 0)))
	instance.potential = clampi(int(data.get("potential", 0)), 0, MAX_POTENTIAL)

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

	instance.equipped_skills.clear()
	var equipped_skills_data = data.get("equippedSkills", [])
	if equipped_skills_data is Array:
		for skill in equipped_skills_data:
			var skill_id := String(skill)
			if instance.learned_skills.has(skill_id) and not instance.equipped_skills.has(skill_id) and instance.equipped_skills.size() < MAX_EQUIPPED_SKILLS:
				instance.equipped_skills.append(skill_id)
	if instance.equipped_skills.is_empty():
		for skill_id: String in instance.learned_skills:
			if instance.equipped_skills.size() >= MAX_EQUIPPED_SKILLS:
				break
			instance.equipped_skills.append(skill_id)

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
