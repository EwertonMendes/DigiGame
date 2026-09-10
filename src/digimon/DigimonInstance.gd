extends RefCounted
class_name DigimonInstance

const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "speed"]
const MAX_POTENTIAL := 100

var id: String = ""
var species_seed: String = ""
var nickname: String = ""
var level: int = 1
var exp: int = 0
var potential: int = 0
var aptitudes: Dictionary = {}
var training: Dictionary = {}
var current_hp: int = 1
var current_mp: int = 0
var learned_skills: Array[String] = []
var equipment: Array[String] = []
var evolution_history: Array[Dictionary] = []
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
		"currentMp": current_mp,
		"learnedSkills": learned_skills.duplicate(),
		"equipment": equipment.duplicate(),
		"evolutionHistory": evolution_history.duplicate(true),
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
	instance.current_mp = maxi(0, int(data.get("currentMp", 0)))

	instance.learned_skills.clear()
	var skills = data.get("learnedSkills", [])
	if skills is Array:
		for skill in skills:
			instance.learned_skills.append(String(skill))

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
