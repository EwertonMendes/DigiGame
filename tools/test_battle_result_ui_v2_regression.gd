extends Node

const ResultScreenScript = preload("res://src/ui/RetreatAwareBattleResultScreen.gd")
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.name = "BattleResultRegressionViewport"
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	var screen := ResultScreenScript.new() as BattleResultScreen
	viewport.add_child(screen)
	await _frames(2)

	_check(screen.has_meta("digi_ui_v2_component"), "Battle result root must opt into Digi UI V2")
	var shell := screen.get("_shell") as Control
	_check(shell != null and shell.has_meta("digi_glass_surface"), "Battle result must use the shared V2 glass surface")
	var continue_button := screen.get("_continue_button") as Button
	_check(continue_button != null and continue_button.custom_minimum_size.y >= V2.TOUCH_TARGET, "Result action must remain touch-safe")
	_check(screen.find_child("KenneyResultDivider", true, false) == null, "Battle result must not recreate legacy Kenney chrome")

	await _verify_first_open_reflow(screen, viewport)
	await _verify_outcome(screen, viewport, "victory", "VICTORY")
	await _verify_outcome(screen, viewport, "escaped", "RETREATED")
	await _verify_outcome(screen, viewport, "defeat", "DEFEAT")

	viewport.size = Vector2i(700, 540)
	await _frames(2)
	screen.call("_layout")
	await _frames(2)
	_check_frame_inside_viewport(screen, viewport, "compact")
	_check_frame_centered(screen, viewport, "compact")
	var party_grid := screen.get("_party_grid") as GridContainer
	_check(party_grid != null and party_grid.columns == 1, "Compact result layout must collapse squad cards to one column")

	screen.queue_free()
	viewport.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("battle result ui v2 regression passed")
		get_tree().quit()
		return
	for failure in _failures:
		push_error("[battle-result-ui-v2] %s" % failure)
	get_tree().quit(1)


func _verify_first_open_reflow(screen: BattleResultScreen, viewport: SubViewport) -> void:
	screen.show_result({
		"battle_seed": "ui-v2-first-open-reflow",
		"outcome": "victory",
		"victory": true,
		"acts": 12,
		"bits": 120,
		"digi_data": {"Agumon": 8},
		"digi_data_progress": {},
		"xp_rewards": {"digimon": []},
	})
	await _frames(1)

	# Reproduce the real first-open failure mode: descendants can report a larger
	# minimum size after the initial layout pass (fonts, portraits and reward rows
	# all participate in that minimum). The shell must re-fit and remain centered
	# without relying on a resize event or a second battle opening.
	var reward_panel := screen.get("_reward_panel") as Control
	if _check(reward_panel != null, "First-open regression requires the rewards panel"):
		var original_minimum := reward_panel.custom_minimum_size
		reward_panel.custom_minimum_size = Vector2(original_minimum.x, 420.0)
		await _frames(2)
		_check_frame_inside_viewport(screen, viewport, "first-open late growth")
		_check_frame_centered(screen, viewport, "first-open late growth")
		reward_panel.custom_minimum_size = original_minimum
		await _frames(2)

	screen.hide_result()
	await _frames(1)


func _verify_outcome(screen: BattleResultScreen, viewport: SubViewport, outcome: String, expected_title: String) -> void:
	screen.show_result({
		"battle_seed": "ui-v2-%s" % outcome,
		"outcome": outcome,
		"victory": outcome == "victory",
		"acts": 12,
		"bits": 120 if outcome == "victory" else 0,
		"digi_data": {"Agumon": 8} if outcome == "victory" else {},
		"digi_data_progress": {},
		"xp_rewards": {"digimon": []},
	})
	await _frames(3)
	var title := screen.get("_title") as Label
	_check(title != null and title.text == expected_title, "%s result must communicate its outcome clearly" % expected_title)
	_check_frame_inside_viewport(screen, viewport, outcome)
	_check_frame_centered(screen, viewport, outcome)
	screen.hide_result()
	await _frames(1)


func _check_frame_inside_viewport(screen: BattleResultScreen, viewport: SubViewport, context: String) -> void:
	var shell := screen.get("_shell") as Control
	if not _check(shell != null, "%s result requires a shell" % context):
		return
	var bounds := _control_bounds(shell)
	_check(bounds.position.x >= -1.0 and bounds.position.y >= -1.0, "%s result frame must not begin outside the viewport" % context)
	_check(bounds.end.x <= float(viewport.size.x) + 1.0, "%s result frame must not overflow horizontally" % context)
	_check(bounds.end.y <= float(viewport.size.y) + 1.0, "%s result frame must not overflow vertically" % context)
	_check(shell.clip_contents, "%s result frame must clip late dynamic content safely" % context)


func _check_frame_centered(screen: BattleResultScreen, viewport: SubViewport, context: String) -> void:
	var shell := screen.get("_shell") as Control
	if shell == null:
		return
	var bounds := _control_bounds(shell)
	var viewport_center := Vector2(viewport.size) * 0.5
	_check(
		bounds.get_center().distance_to(viewport_center) <= 1.5,
		"%s result frame must remain centered after fitting" % context
	)


func _control_bounds(control: Control) -> Rect2:
	var transform := control.get_global_transform()
	var points := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
