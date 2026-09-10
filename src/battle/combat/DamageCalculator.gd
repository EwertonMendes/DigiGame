extends RefCounted
class_name DamageCalculator

const TypeChartScript = preload("res://src/battle/combat/TypeChart.gd")

var _type_chart = TypeChartScript.new()
var _config = null


func _init(config = null) -> void:
	_config = config


func preview(source: Node, target: Node, action: Dictionary) -> Dictionary:
	if source == null or target == null or action.is_empty():
		return {}
	var damage_class := String(action.get("damageClass", "physical")).to_lower()
	var offense_key := "int" if damage_class == "special" else "atk"
	var defense_key := "int" if damage_class == "special" else "def"
	var offense := maxi(1, _stat(source, offense_key))
	var defense := maxi(1, _stat(target, defense_key))
	var power := maxi(0, int(action.get("power", 0)))
	var stat_factor := (2.0 * float(offense)) / maxf(1.0, float(offense + defense))
	var base_damage := float(power) * stat_factor

	var source_species := _species(source)
	var target_species := _species(target)
	var type_advantage := _cfg("typeChart", "advantage", 1.35)
	var type_disadvantage := _cfg("typeChart", "disadvantage", 0.75)
	var type_mod := _type_chart.type_modifier(
		String(source_species.get("type", source_species.get("attribute", "Free"))),
		String(target_species.get("type", target_species.get("attribute", "Free"))),
		type_advantage,
		type_disadvantage
	)
	var element_mod := _type_chart.element_modifier(
		String(action.get("element", "neutral")),
		String(target_species.get("element", "neutral")),
		_cfg("elementChart", "advantage", 1.25),
		_cfg("elementChart", "resisted", 0.8)
	)
	var guard_mod := _cfg("defend", "damageMultiplier", 0.65) if _is_guarding(target) else 1.0
	var minimum_damage := int(_cfg("damage", "minimumDamage", 1.0))
	var normal_damage := maxi(minimum_damage, int(round(base_damage * type_mod * element_mod * guard_mod))) if power > 0 else 0
	var crit_multiplier := _cfg("damage", "criticalMultiplier", 1.5)
	var crit_damage := maxi(normal_damage, int(round(float(normal_damage) * crit_multiplier)))
	var hit_chance := clampf(float(action.get("accuracy", 100)), 0.0, 100.0)
	var crit_chance := _cfg("damage", "criticalChance", 5.0) if bool(action.get("canCrit", false)) else 0.0

	return {
		"damage": normal_damage,
		"critical_damage": crit_damage,
		"hit_chance": hit_chance,
		"crit_chance": crit_chance,
		"power": power,
		"damage_class": damage_class,
		"offense": offense,
		"defense": defense,
		"type_modifier": type_mod,
		"element_modifier": element_mod,
		"guard_modifier": guard_mod,
		"element": String(action.get("element", "neutral")),
	}


func _stat(actor: Node, stat_key: String) -> int:
	if actor != null and actor.has_method("get_final_stat"):
		return maxi(0, int(actor.call("get_final_stat", stat_key)))
	return 0


func _species(actor: Node) -> Dictionary:
	if actor == null:
		return {}
	var raw = actor.get("species_data")
	return raw if raw is Dictionary else {}


func _is_guarding(actor: Node) -> bool:
	if actor == null:
		return false
	if bool(actor.get("is_defending")):
		return true
	var battle_state = actor.get("battle_state")
	if battle_state != null and battle_state.has_method("has_status"):
		return bool(battle_state.call("has_status", "guard"))
	return false


func _cfg(section: String, key: String, fallback: float) -> float:
	if _config != null and _config.has_method("number"):
		return float(_config.call("number", section, key, fallback))
	return fallback
