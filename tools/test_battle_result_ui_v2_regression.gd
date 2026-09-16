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
	var party_grid := screen.get("_party_grid") as GridContainer
	var content := screen.get("_content") as VBoxContainer
	_check(party_grid != null and party_grid.get_parent() == content, "Squad report must participate directly in the result layout")
	_check(screen.find_child("SquadReportScrollV2", true, false) == null, "Squad report must not use an internal scroll viewport")
	await _verify_card_layout_stability(screen)

	# Victory is intentionally verified first and also reproduces the first-open
	# late-minimum-size case that caused the production overflow.
	await _verify_outcome(screen, viewport, "victory", "VICTORY", true)
	await _verify_outcome(screen, viewport, "escaped", "RETREATED")
	await _verify_outcome(screen, viewport, "defeat", "DEFEAT")

	viewport.size = Vector2i(700, 540)
	await _frames(2)
	screen.call("_layout")
	await _frames(2)
	_check_frame_inside_viewport(screen, viewport, "compact")
	_check_frame_centered(screen, viewport, "compact")
	_check(party_grid != null and party_grid.columns == 1, "Compact result layout must collapse squad cards to one column")

	screen.queue_free()
	viewport.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("battle result ui v2 regression passed")
		get_tree().quit()
		return
	for failure in _failures:
		# Keep an explicit stdout diagnostic before the non-zero quit. GitHub's
		# headless runner can terminate before push_error output is flushed.
		print("[battle-result-ui-v2] FAILURE: %s" % failure)
	get_tree().quit(1)


func _verify_card_layout_stability(screen: BattleResultScreen) -> void:
	screen.set("_result", {"outcome": "victory", "victory": true})
	var reward := {
		"instance_id": "layout-stability",
		"display_name": "Agumon",
		"species_name": "Agumon",
		"rank": "Rookie",
		"xp_gained": 96,
		"old_level": 4,
		"new_level": 5,
		"levels_gained": 1,
		"old_exp": 90,
		"new_exp": 101,
		"old_xp_required": 120,
		"new_xp_required": 229,
		"level_steps": [{
			"level": 4,
			"required": 120,
			"start_exp": 90,
			"end_exp": 120,
			"leveled_up": true,
			"next_level": 5,
		}],
		"learned_skills": ["pepper_breath", "baby_flame"],
		"unlocked_evolutions": [{"name": "Greymon"}],
	}
	var created = screen.call("_create_party_card", reward, V2.GREEN, true)
	if not _check(created is Dictionary, "Card stability regression requires a synthetic reward card"):
		return
	var card: Dictionary = created as Dictionary
	await _frames(2)
	var panel := card.get("panel") as PanelContainer
	var unlocks := card.get("unlocks") as Label
	var badge := card.get("level_up") as Label
	if not _check(panel != null and unlocks != null and badge != null, "Synthetic reward card must expose its dynamic presentation nodes"):
		return
	var initial_height := panel.get_combined_minimum_size().y
	_check(not unlocks.text.is_empty(), "Final unlock copy must be reserved before reward animation starts")
	_check(is_zero_approx(unlocks.modulate.a), "Reserved unlock copy should start visually hidden")
	_check(badge.visible and is_zero_approx(badge.modulate.a), "Level-up feedback must reserve its slot without changing card height")

	# Revealing final reward copy and level-up feedback must be purely visual. If
	# either changes minimum size, the grid will visibly bounce during animation.
	screen.call("_set_unlock_text", card)
	badge.modulate.a = 1.0
	await _frames(2)
	var revealed_height := panel.get_combined_minimum_size().y
	_check(absf(revealed_height - initial_height) <= 0.5, "Reward animation must not change Digimon card height")

	panel.queue_free()
	await _frames(2)


func _verify_outcome(
	screen: BattleResultScreen,
	viewport: SubViewport,
	outcome: String,
	expected_title: String,
	simulate_first_open_growth: bool = false
) -> void:
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

	var reward_panel := screen.get("_reward_panel") as Control
	var original_minimum := Vector2.ZERO
	if simulate_first_open_growth and _check(reward_panel != null, "First-open regression requires the rewards panel"):
		original_minimum = reward_panel.custom_minimum_size
		# Reproduce the real failure mode: descendants report a larger minimum after
		# the first layout pass. The shared safe-frame guard must re-fit/recenter it.
		await _frames(1)
		reward_panel.custom_minimum_size = Vector2(original_minimum.x, 420.0)
		await _frames(2)
		_check_frame_inside_viewport(screen, viewport, "first-open late growth")
		_check_frame_centered(screen, viewport, "first-open late growth")
	else:
		await _frames(3)

	var title := screen.get("_title") as Label
	_check(title != null and title.text == expected_title, "%s result must communicate its outcome clearly" % expected_title)
	_check_frame_inside_viewport(screen, viewport, outcome)
	_check_frame_centered(screen, viewport, outcome)

	if simulate_first_open_growth and reward_panel != null:
		reward_panel.custom_minimum_size = original_minimum
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
