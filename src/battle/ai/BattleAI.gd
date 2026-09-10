extends RefCounted
class_name BattleAI

var _targeting = null
var _damage = null


func _init(targeting_system = null, damage_calculator = null) -> void:
	_targeting = targeting_system
	_damage = damage_calculator


func choose_action(field: Node, actor: Node, opponents: Array[Node], actions: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for action: Dictionary in actions:
		for target: Node in opponents:
			if _targeting == null or not _targeting.is_valid_target(field, actor, target, action):
				continue
			var preview: Dictionary = _damage.preview(actor, target, action) if _damage != null else {}
			var damage := float(preview.get("damage", 0))
			var hit := float(preview.get("hit_chance", 100.0)) / 100.0
			var expected := damage * hit
			var hp := _current_hp(target)
			var ko_bonus := 120.0 if damage >= hp and hp > 0 else 0.0
			var matchup_bonus := (float(preview.get("type_modifier", 1.0)) - 1.0) * 40.0
			var sp_penalty := float(action.get("spCost", 0)) * 0.35
			var recovery_penalty := float(action.get("recoveryCost", 30.0)) * 0.08
			var score := expected + ko_bonus + matchup_bonus - sp_penalty - recovery_penalty
			if score > best_score:
				best_score = score
				best = {"action": action.duplicate(true), "target": target, "score": score}
	return best


func _current_hp(actor: Node) -> int:
	if actor == null:
		return 0
	var battle_state = actor.get("battle_state")
	return int(battle_state.current_hp) if battle_state != null else 0
