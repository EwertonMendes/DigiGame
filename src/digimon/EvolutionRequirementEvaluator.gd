extends RefCounted
class_name EvolutionRequirementEvaluator

const STAT_ALIASES := {
	"attack": "atk",
	"defense": "def",
	"sp": "mp",
}
const DIRECT_STATS: Array[String] = ["hp", "mp", "sp", "atk", "attack", "def", "defense", "int", "speed"]


func evaluate_all(instance: DigimonInstance, species: Dictionary, raw_requirements, calculator: DigimonStatCalculator, context: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_requirements is Array:
		return result
	for raw_requirement in raw_requirements:
		if not raw_requirement is Dictionary:
			continue
		result.append(evaluate(instance, species, raw_requirement as Dictionary, calculator, context))
	return result


func all_met(instance: DigimonInstance, species: Dictionary, raw_requirements, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	for evaluation: Dictionary in evaluate_all(instance, species, raw_requirements, calculator, context):
		if not bool(evaluation.get("is_met", false)):
			return false
	return true


func evaluate(instance: DigimonInstance, species: Dictionary, requirement: Dictionary, calculator: DigimonStatCalculator, context: Dictionary = {}) -> Dictionary:
	var kind := String(requirement.get("type", "")).to_lower().strip_edges()
	var required: Variant = requirement.get("value", 0)
	var current: Variant = 0
	var supported := true
	var met := false
	var subject := kind

	if instance == null:
		return _result(kind, subject, current, required, false, false, requirement)

	match kind:
		"", "none":
			current = 1
			required = 1
			met = true
		"level":
			current = instance.level
			met = int(current) >= int(required)
		"potential", "abi":
			current = instance.potential
			met = int(current) >= int(required)
		"stat":
			subject = String(requirement.get("stat", "")).to_lower().strip_edges()
			current = _stat_value(instance, species, subject, calculator)
			supported = not subject.is_empty() and int(current) >= 0
			met = supported and int(current) >= int(required)
		"item":
			subject = String(requirement.get("id", requirement.get("item", ""))).strip_edges()
			var inventory = context.get("inventory", {})
			current = int((inventory as Dictionary).get(subject, 0)) if inventory is Dictionary else 0
			required = int(requirement.get("amount", required if int(required) > 0 else 1))
			met = not subject.is_empty() and int(current) >= int(required)
		"link":
			# Link is currently a tactical cooperation mechanic rather than persistent
			# Digimon state. A caller may provide a future progression-safe Link value.
			current = int(context.get("link", 0))
			met = int(current) >= int(required)
		"battles_won":
			current = int(context.get("battles_won", 0))
			met = int(current) >= int(required)
		"species_defeated":
			subject = String(requirement.get("species_id", requirement.get("id", "")))
			var defeated = context.get("species_defeated", {})
			current = int((defeated as Dictionary).get(subject, 0)) if defeated is Dictionary else 0
			met = not subject.is_empty() and int(current) >= int(required)
		"quest":
			subject = String(requirement.get("id", ""))
			var quests = context.get("quests", {})
			current = String((quests as Dictionary).get(subject, "locked")) if quests is Dictionary else "locked"
			required = String(requirement.get("state", "completed"))
			met = String(current) == String(required)
		"flag":
			subject = String(requirement.get("id", ""))
			var flags = context.get("flags", {})
			current = bool((flags as Dictionary).get(subject, false)) if flags is Dictionary else false
			required = bool(requirement.get("value", true))
			met = bool(current) == bool(required)
		"time":
			current = int(context.get("time", 0))
			met = int(current) >= int(required)
		"party_condition":
			subject = String(requirement.get("id", requirement.get("condition", "")))
			var conditions = context.get("party_conditions", {})
			current = bool((conditions as Dictionary).get(subject, false)) if conditions is Dictionary else false
			required = true
			met = bool(current)
		_:
			if DIRECT_STATS.has(kind):
				current = _stat_value(instance, species, kind, calculator)
				met = int(current) >= int(required)
			else:
				supported = false
				met = false

	return _result(kind, subject, current, required, met, supported, requirement)


func _stat_value(instance: DigimonInstance, species: Dictionary, raw_stat: String, calculator: DigimonStatCalculator) -> int:
	if calculator == null:
		return -1
	var stat := String(STAT_ALIASES.get(raw_stat, raw_stat)).to_lower()
	if not ["hp", "mp", "atk", "def", "int", "speed"].has(stat):
		return -1
	return int(calculator.get_stat(instance, species, stat))


func _result(kind: String, subject: String, current: Variant, required: Variant, met: bool, supported: bool, source: Dictionary) -> Dictionary:
	return {
		"type": kind,
		"subject": subject,
		"current_value": current,
		"required_value": required,
		"is_met": met,
		"supported": supported,
		"source": source.duplicate(true),
	}
