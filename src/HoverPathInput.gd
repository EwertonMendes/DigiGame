extends Node

# Mouse movement can extend a tactical route without requiring a click on every
# tile. A tiny dwell prevents incidental cursor travel toward the HUD from
# changing the route, while click/drag input remains immediate in BattleController.
const HOVER_DWELL_SECONDS := 0.055
const INVALID_GRID := Vector2i(-9999, -9999)

var _candidate_grid := INVALID_GRID
var _candidate_elapsed := 0.0


func _process(delta: float) -> void:
	# Touch route drawing is owned by MainCamera so one-finger tracing and
	# two-finger pan/pinch stay deterministic and never compete with mouse input.
	if GlobalVariables.TouchInputActive:
		_reset_candidate()
		return

	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		_reset_candidate()
		return

	var battle := main.get_node_or_null("BattleController")
	var field := main.get_node_or_null("Blocks")
	if (
		battle == null
		or field == null
		or not battle.has_method("is_manual_path_input_active")
		or not bool(battle.call("is_manual_path_input_active"))
		or not battle.has_method("handle_path_pointer_world")
	):
		_reset_candidate()
		return

	var camera := get_viewport().get_camera_2d()
	if camera == null:
		_reset_candidate()
		return

	var world_position := camera.get_global_mouse_position()
	var grid := Vector2i(field.call("world_to_grid", field.to_local(world_position)))
	if not _can_hover_extend_route(battle, grid):
		_reset_candidate()
		return

	if grid != _candidate_grid:
		_candidate_grid = grid
		_candidate_elapsed = 0.0
		return

	_candidate_elapsed += delta
	if _candidate_elapsed < HOVER_DWELL_SECONDS:
		return

	# BattleController owns all movement validation and MOV accounting. This
	# helper only decides when a hover should be promoted to the same route step
	# used by click/drag input.
	battle.call("handle_path_pointer_world", world_position)
	_reset_candidate()


func _can_hover_extend_route(battle: Node, grid: Vector2i) -> bool:
	# Hover only EXTENDS a route. It never trims/backtracks an existing route,
	# because moving the mouse toward CONFIRM could otherwise accidentally undo
	# the player's plan. Clicking/tapping or deliberate dragging can still edit
	# backwards using the existing manual-path controls.
	var origin_variant = battle.get("_turn_start_grid")
	if origin_variant is Vector2i and grid == Vector2i(origin_variant):
		return false

	var path_variant = battle.get("_planned_move_path")
	if path_variant is Array and path_variant.has(grid):
		return false

	var steps_variant = battle.get("_valid_next_steps")
	return steps_variant is Dictionary and steps_variant.has(grid)


func _reset_candidate() -> void:
	_candidate_grid = INVALID_GRID
	_candidate_elapsed = 0.0
