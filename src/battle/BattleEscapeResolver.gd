extends RefCounted
class_name BattleEscapeResolver

const DEFAULT_BASE_CHANCE := 50.0
const DEFAULT_FAILURE_BONUS := 15.0
const DEFAULT_FAILURE_BONUS_CAP := 30.0
const DEFAULT_FAILURE_RECOVERY := 120.0
const MIN_ESCAPE_CHANCE := 20.0
const MAX_ESCAPE_CHANCE := 95.0
const MAX_SPEED_MODIFIER := 20.0
const MAX_DISTANCE_MODIFIER := 16.0
const DISTANCE_BONUS_PER_TILE := 4.0


func default_policy() -> Dictionary:
	return {
		"mode": "allowed",
		"baseChance": DEFAULT_BASE_CHANCE,
		"failureBonus": DEFAULT_FAILURE_BONUS,
		"failureBonusCap": DEFAULT_FAILURE_BONUS_CAP,
		"failureRecovery": DEFAULT_FAILURE_RECOVERY,
		"reason": "",
	}


func normalize_policy(raw_policy: Dictionary) -> Dictionary:
	var policy := default_policy()
	policy.merge(raw_policy, true)
	var mode := String(policy.get("mode", "allowed")).to_lower()
	if mode != "allowed" and mode != "forbidden" and mode != "guaranteed":
		mode = "allowed"
	policy["mode"] = mode
	policy["baseChance"] = clampf(float(policy.get("baseChance", DEFAULT_BASE_CHANCE)), 0.0, 100.0)
	policy["failureBonus"] = maxf(0.0, float(policy.get("failureBonus", DEFAULT_FAILURE_BONUS)))
	policy["failureBonusCap"] = maxf(0.0, float(policy.get("failureBonusCap", DEFAULT_FAILURE_BONUS_CAP)))
	policy["failureRecovery"] = maxf(1.0, float(policy.get("failureRecovery", DEFAULT_FAILURE_RECOVERY)))
	policy["reason"] = String(policy.get("reason", ""))
	return policy


func preview(field: Node, actor: Node, enemies: Array[Node], failed_attempts: int, raw_policy: Dictionary) -> Dictionary:
	var policy := normalize_policy(raw_policy)
	var mode := String(policy["mode"])
	if mode == "forbidden":
		return {
			"allowed": false,
			"mode": mode,
			"chance": 0.0,
			"base_chance": float(policy["baseChance"]),
			"speed_modifier": 0.0,
			"distance_modifier": 0.0,
			"retry_modifier": 0.0,
			"nearest_distance": 0,
			"actor_speed": _speed_for(actor),
			"enemy_speed": _average_speed(enemies),
			"failure_recovery": float(policy["failureRecovery"]),
			"failed_attempts": failed_attempts,
			"reason": String(policy["reason"]),
		}
	if mode == "guaranteed":
		return {
			"allowed": true,
			"mode": mode,
			"chance": 100.0,
			"base_chance": 100.0,
			"speed_modifier": 0.0,
			"distance_modifier": 0.0,
			"retry_modifier": 0.0,
			"nearest_distance": _nearest_distance(field, actor, enemies),
			"actor_speed": _speed_for(actor),
			"enemy_speed": _average_speed(enemies),
			"failure_recovery": float(policy["failureRecovery"]),
			"failed_attempts": failed_attempts,
			"reason": "",
		}

	var actor_speed := _speed_for(actor)
	var enemy_speed := _average_speed(enemies)
	var nearest_distance := _nearest_distance(field, actor, enemies)
	return calculate(
		float(policy["baseChance"]),
		actor_speed,
		enemy_speed,
		nearest_distance,
		failed_attempts,
		float(policy["failureBonus"]),
		float(policy["failureBonusCap"]),
		float(policy["failureRecovery"])
	)


func calculate(base_chance: float, actor_speed: float, enemy_speed: float, nearest_distance: int, failed_attempts: int, failure_bonus: float = DEFAULT_FAILURE_BONUS, failure_bonus_cap: float = DEFAULT_FAILURE_BONUS_CAP, failure_recovery: float = DEFAULT_FAILURE_RECOVERY) -> Dictionary:
	var safe_enemy_speed := maxf(1.0, enemy_speed)
	var speed_modifier := clampf(((actor_speed - safe_enemy_speed) / safe_enemy_speed) * 40.0, -MAX_SPEED_MODIFIER, MAX_SPEED_MODIFIER)
	# Adjacent enemies grant no safety bonus. Every clear tile after that grants
	# +4%, capped at +16%, so repositioning before retreat is tactically useful.
	var distance_modifier := clampf(float(maxi(0, nearest_distance - 1)) * DISTANCE_BONUS_PER_TILE, 0.0, MAX_DISTANCE_MODIFIER)
	var retry_modifier := minf(float(maxi(0, failed_attempts)) * failure_bonus, failure_bonus_cap)
	var chance := clampf(base_chance + speed_modifier + distance_modifier + retry_modifier, MIN_ESCAPE_CHANCE, MAX_ESCAPE_CHANCE)
	return {
		"allowed": true,
		"mode": "allowed",
		"chance": chance,
		"base_chance": base_chance,
		"speed_modifier": speed_modifier,
		"distance_modifier": distance_modifier,
		"retry_modifier": retry_modifier,
		"nearest_distance": nearest_distance,
		"actor_speed": actor_speed,
		"enemy_speed": enemy_speed,
		"failure_recovery": failure_recovery,
		"failed_attempts": failed_attempts,
		"reason": "",
	}


func _speed_for(actor: Node) -> float:
	if actor == null or not is_instance_valid(actor):
		return 1.0
	if actor.has_method("get_final_stat"):
		return maxf(1.0, float(actor.call("get_final_stat", "speed")))
	return 1.0


func _average_speed(actors: Array[Node]) -> float:
	if actors.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for actor: Node in actors:
		if actor == null or not is_instance_valid(actor):
			continue
		total += _speed_for(actor)
		count += 1
	return total / float(maxi(1, count))


func _nearest_distance(field: Node, actor: Node, enemies: Array[Node]) -> int:
	if actor == null or enemies.is_empty():
		return 1
	var origin := _grid_for(field, actor)
	var best := 999999
	for enemy: Node in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var target := _grid_for(field, enemy)
		best = mini(best, absi(origin.x - target.x) + absi(origin.y - target.y))
	return 1 if best == 999999 else best


func _grid_for(field: Node, actor: Node) -> Vector2i:
	if field == null or actor == null or not actor.has_method("get_tile_world_position") or not field.has_method("world_to_grid"):
		return Vector2i.ZERO
	var world_position := Vector2(actor.call("get_tile_world_position"))
	if field is Node2D:
		return Vector2i(field.call("world_to_grid", (field as Node2D).to_local(world_position)))
	return Vector2i(field.call("world_to_grid", world_position))
