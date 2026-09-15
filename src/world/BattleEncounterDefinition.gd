extends Resource
class_name BattleEncounterDefinition

const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const VALID_TIERS: Array[String] = ["E", "D", "C", "B", "A", "S", "SS", "SSS"]

@export var encounter_id: String = ""
@export var enemy_party: Array[Dictionary] = []
@export var battle_map: String = ""
@export_range(0.0, 10.0, 0.05) var reward_modifier: float = 1.0
@export var repeatable: bool = true
@export var progression_flag: String = ""
@export var guaranteed_items: Dictionary = {}


func validate(database: DigimonDatabase = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if encounter_id.strip_edges().is_empty():
		errors.append("Encounter id is required.")
	if enemy_party.is_empty():
		errors.append("Encounter '%s' has no enemies." % encounter_id)
	if reward_modifier < 0.0:
		errors.append("Encounter '%s' has a negative reward modifier." % encounter_id)
	for raw_item_id in guaranteed_items.keys():
		var item_id := String(raw_item_id).strip_edges()
		if item_id.is_empty() or int(guaranteed_items[raw_item_id]) <= 0:
			errors.append("Encounter '%s' has an invalid guaranteed item reward." % encounter_id)
	for index in enemy_party.size():
		var descriptor := enemy_party[index]
		var species_token := String(descriptor.get("species_seed", descriptor.get("species", ""))).strip_edges()
		if species_token.is_empty():
			errors.append("Encounter '%s' enemy %d is missing a species." % [encounter_id, index])
			continue
		if database != null:
			var species := database.get_by_seed(species_token)
			if species.is_empty():
				species = database.get_by_name(species_token)
			if species.is_empty():
				errors.append("Encounter '%s' enemy %d references unknown species '%s'." % [encounter_id, index, species_token])
		var min_level := int(descriptor.get("level_min", descriptor.get("level", 1)))
		var max_level := int(descriptor.get("level_max", descriptor.get("level", min_level)))
		if min_level < 1 or max_level < min_level:
			errors.append("Encounter '%s' enemy %d has invalid level bounds %d..%d." % [encounter_id, index, min_level, max_level])
		var tier := String(descriptor.get("tier", "E")).to_upper().strip_edges()
		if not VALID_TIERS.has(tier):
			errors.append("Encounter '%s' enemy %d has invalid tier '%s'." % [encounter_id, index, tier])
		var footprint := String(descriptor.get("footprint", FootprintScript.SINGLE))
		if not FootprintScript.is_supported(footprint):
			errors.append("Encounter '%s' enemy %d has unsupported footprint '%s'." % [encounter_id, index, footprint])
	return errors


func to_dict() -> Dictionary:
	return {
		"encounter_id": encounter_id,
		"enemy_party": enemy_party.duplicate(true),
		"battle_map": battle_map,
		"reward_modifier": reward_modifier,
		"repeatable": repeatable,
		"progression_flag": progression_flag,
		"guaranteed_items": guaranteed_items.duplicate(true),
	}


static func from_dict(data: Dictionary) -> BattleEncounterDefinition:
	var definition := BattleEncounterDefinition.new()
	definition.encounter_id = String(data.get("encounter_id", data.get("id", "")))
	var enemies = data.get("enemy_party", data.get("enemies", []))
	if enemies is Array:
		for raw_enemy in enemies:
			if raw_enemy is Dictionary:
				definition.enemy_party.append((raw_enemy as Dictionary).duplicate(true))
	definition.battle_map = String(data.get("battle_map", data.get("map", "")))
	definition.reward_modifier = maxf(0.0, float(data.get("reward_modifier", 1.0)))
	definition.repeatable = bool(data.get("repeatable", true))
	definition.progression_flag = String(data.get("progression_flag", ""))
	var items = data.get("guaranteed_items", data.get("items", {}))
	if items is Dictionary:
		definition.guaranteed_items = (items as Dictionary).duplicate(true)
	return definition
