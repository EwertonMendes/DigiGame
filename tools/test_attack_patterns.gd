extends Node

const FieldScript = preload("res://src/Field.gd")
const PatternResolverScript = preload("res://src/battle/combat/TargetPatternResolver.gd")


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

	print("advanced attack pattern regression passed")
	get_tree().quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
