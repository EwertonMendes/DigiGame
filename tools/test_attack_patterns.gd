extends Node

const FieldScript = preload("res://src/Field.gd")
const PatternResolverScript = preload("res://src/battle/combat/TargetPatternResolver.gd")
const EscapeResolverScript = preload("res://src/battle/BattleEscapeResolver.gd")


func _ready() -> void:
	var field := FieldScript.new()
	var resolver = PatternResolverScript.new()
	var origin := Vector2i(7, 12)

	var basic := {
		"range": {"shape": "adjacent_8", "min": 1, "max": 1},
		"area": {"shape": "single"},
	}
	var adjacent := resolver.cast_grids(field, origin, basic)
	_assert(adjacent.size() == 8, "basic attack must expose exactly eight adjacent tiles")
	_assert(adjacent.has(origin + Vector2i(-1, -1)), "basic attack must include upper-left diagonal")
	_assert(adjacent.has(origin + Vector2i(1, -1)), "basic attack must include upper-right diagonal")
	_assert(adjacent.has(origin + Vector2i(-1, 1)), "basic attack must include lower-left diagonal")
	_assert(adjacent.has(origin + Vector2i(1, 1)), "basic attack must include lower-right diagonal")

	var splash := {"area": {"shape": "diamond", "radius": 1}}
	var splash_grids := resolver.effect_grids(field, origin, origin + Vector2i(2, 0), splash)
	_assert(splash_grids.size() == 5, "radius-one diamond must affect center plus four neighbours")

	var beam := {"area": {"shape": "line", "length": 4}}
	var beam_grids := resolver.effect_grids(field, origin, origin + Vector2i(1, 0), beam)
	_assert(beam_grids.size() == 4, "length-four beam must affect four tiles")
	_assert(beam_grids[3] == origin + Vector2i(4, 0), "beam must extend in the selected direction")

	var cone := {"area": {"shape": "cone", "length": 4, "angle": 80}}
	var cone_grids := resolver.effect_grids(field, origin, origin + Vector2i(1, 0), cone)
	_assert(cone_grids.has(origin + Vector2i(1, 0)), "cone must include its forward axis")
	_assert(cone_grids.has(origin + Vector2i(4, 0)), "cone must reach its configured length")
	_assert(not cone_grids.has(origin + Vector2i(-1, 0)), "cone must never hit behind the caster")

	var escape_resolver = EscapeResolverScript.new()
	_expect_escape_chance(escape_resolver.calculate(50.0, 10.0, 10.0, 1, 0), 50.0, "equal-speed adjacent retreat")
	_expect_escape_chance(escape_resolver.calculate(50.0, 10.0, 10.0, 5, 0), 66.0, "safe-distance retreat bonus")
	_expect_escape_chance(escape_resolver.calculate(50.0, 20.0, 10.0, 1, 0), 70.0, "retreat speed advantage cap")
	_expect_escape_chance(escape_resolver.calculate(50.0, 5.0, 10.0, 1, 0), 30.0, "retreat speed disadvantage cap")
	_expect_escape_chance(escape_resolver.calculate(50.0, 10.0, 10.0, 1, 1), 65.0, "first failed-retreat pity")
	_expect_escape_chance(escape_resolver.calculate(50.0, 10.0, 10.0, 1, 3), 80.0, "failed-retreat pity cap")
	_expect_escape_chance(escape_resolver.calculate(90.0, 30.0, 10.0, 8, 2), 95.0, "retreat global chance cap")
	var forbidden: Dictionary = escape_resolver.preview(null, null, [], 0, {"mode": "forbidden", "reason": "boss"})
	_assert(not bool(forbidden.get("allowed", true)), "forbidden escape policy must block retreat")
	_assert(String(forbidden.get("reason", "")) == "boss", "forbidden escape policy must preserve its reason")
	var guaranteed: Dictionary = escape_resolver.preview(null, null, [], 0, {"mode": "guaranteed"})
	_assert(bool(guaranteed.get("allowed", false)), "guaranteed escape policy must allow retreat")
	_expect_escape_chance(guaranteed, 100.0, "guaranteed retreat")

	# This field is instantiated only as a lightweight board-bounds collaborator;
	# free it explicitly so the headless regression exits without resource noise.
	field.free()
	resolver = null
	escape_resolver = null
	print("advanced attack pattern regression passed")
	get_tree().quit()


func _expect_escape_chance(result: Dictionary, expected: float, label: String) -> void:
	var actual := float(result.get("chance", -999.0))
	_assert(is_equal_approx(actual, expected), "%s expected %.1f but got %.1f" % [label, expected, actual])


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
