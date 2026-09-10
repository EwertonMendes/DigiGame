extends RefCounted
class_name TypeChart

const TYPE_ADVANTAGE := {
	"vaccine": "virus",
	"virus": "data",
	"data": "vaccine",
}
const ELEMENT_ADVANTAGE := {
	"fire": "plant",
	"plant": "water",
	"water": "fire",
	"electric": "wind",
	"wind": "earth",
	"earth": "electric",
	"light": "dark",
	"dark": "light",
}


func type_modifier(attacker_type: String, defender_type: String, advantage: float = 1.35, disadvantage: float = 0.75) -> float:
	var source := attacker_type.to_lower().strip_edges()
	var target := defender_type.to_lower().strip_edges()
	if source.is_empty() or target.is_empty() or source == "free" or target == "free":
		return 1.0
	if String(TYPE_ADVANTAGE.get(source, "")) == target:
		return advantage
	if String(TYPE_ADVANTAGE.get(target, "")) == source:
		return disadvantage
	return 1.0


func element_modifier(attack_element: String, defender_element: String, advantage: float = 1.25, resisted: float = 0.8) -> float:
	var source := attack_element.to_lower().strip_edges()
	var target := defender_element.to_lower().strip_edges()
	if source.is_empty() or target.is_empty() or source == "neutral" or target == "neutral":
		return 1.0
	if String(ELEMENT_ADVANTAGE.get(source, "")) == target:
		return advantage
	if String(ELEMENT_ADVANTAGE.get(target, "")) == source:
		return resisted
	return 1.0
