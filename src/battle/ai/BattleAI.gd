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
	if _targeting == null:
		return best

	for action: Dictionary in actions:
		var aim_grids: Array[Vector2i] = _targeting.grids_in_range(field, actor, action)
		for aim_grid: Vector2i in aim_grids:
			var targets: Array[Node] = _targeting.valid_targets_for_aim(field, actor, opponents, action, aim_grid)
			if targets.is_empty():
				continue

			var score := -float(action.get("spCost", 0)) * 0.35
			score -= float(action.get("recoveryCost", 30.0)) * 0.08
			var primary: Node = null
			var primary_value := -INF
			for target: Node in targets:
				var preview: Dictionary = _damage.preview(actor, target, action) if _damage != null else {}
				var damage := float(preview.get("damage", 0))
				var hit := float(preview.get("hit_chance", action.get("accuracy", 100.0))) / 100.0
				var expected := damage * hit
				var hp := _current_hp(target)
				var ko_bonus := 120.0 if damage >= hp and hp > 0 else 0.0
				var matchup_bonus := (float(preview.get("type_modifier", 1.0)) - 1.0) * 40.0
				var target_value := expected + ko_bonus + matchup_bonus
				score += target_value
				if target_value > primary_value:
					primary_value = target_value
					primary = target

			# Multi-target pressure is strategically valuable beyond raw damage: it
			# rewards spreading out and makes formation matter to both sides.
			if targets.size() > 1:
				score += float(targets.size() - 1) * 18.0

			if score > best_score:
				best_score = score
				best = {
					"action": action.duplicate(true),
					"target": primary,
					"target_grid": aim_grid,
					"target_count": targets.size(),
					"score": score,
				}
	return best


func _current_hp(actor: Node) -> int:
	if actor == null:
		return 0
	var battle_state = actor.get("battle_state")
	return int(battle_state.current_hp) if battle_state != null else 0
