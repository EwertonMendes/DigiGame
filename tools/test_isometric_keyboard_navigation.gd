extends Node

const FieldScript = preload("res://src/Field.gd")
const ControllerScript = preload("res://src/battle/StableSequencedBattleController.gd")

var _failed := false


func _ready() -> void:
	var field := FieldScript.new()
	var controller := ControllerScript.new()
	_run(field, controller)
	if _failed:
		get_tree().quit(1)
		return
	print("isometric keyboard navigation regression passed")
	get_tree().quit(0)


func _run(field: Node, controller: Node) -> void:
	var cases := [
		{"name": "up", "direction": Vector2.UP, "step": Vector2i(-1, 0), "world": Vector2(-32.0, -16.0)},
		{"name": "right", "direction": Vector2.RIGHT, "step": Vector2i(0, -1), "world": Vector2(32.0, -16.0)},
		{"name": "down", "direction": Vector2.DOWN, "step": Vector2i(1, 0), "world": Vector2(32.0, 16.0)},
		{"name": "left", "direction": Vector2.LEFT, "step": Vector2i(0, 1), "world": Vector2(-32.0, 16.0)},
	]
	var origin := Vector2i(7, 12)

	for case in cases:
		var direction: Vector2 = case["direction"]
		var expected_step: Vector2i = case["step"]
		var expected_world: Vector2 = case["world"]
		var step := Vector2i(controller.call("keyboard_grid_step_for_direction", direction))
		_assert(step == expected_step, "%s input mapped to %s instead of %s" % [case["name"], step, expected_step])

		var current := origin
		for repeat in range(4):
			var next := current + step
			var world_delta := Vector2(field.call("grid_to_world", next)) - Vector2(field.call("grid_to_world", current))
			_assert(world_delta.is_equal_approx(expected_world), "%s input changed lane on repeat %d: %s" % [case["name"], repeat + 1, world_delta])
			current = next

		var total_delta := Vector2(field.call("grid_to_world", current)) - Vector2(field.call("grid_to_world", origin))
		_assert(total_delta.is_equal_approx(expected_world * 4.0), "%s repeated input did not stay on one isometric axis" % case["name"])

	_assert(
		Vector2i(controller.call("keyboard_grid_step_for_direction", Vector2.UP))
		+ Vector2i(controller.call("keyboard_grid_step_for_direction", Vector2.DOWN)) == Vector2i.ZERO,
		"up/down isometric directions are not exact opposites"
	)
	_assert(
		Vector2i(controller.call("keyboard_grid_step_for_direction", Vector2.LEFT))
		+ Vector2i(controller.call("keyboard_grid_step_for_direction", Vector2.RIGHT)) == Vector2i.ZERO,
		"left/right isometric directions are not exact opposites"
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
