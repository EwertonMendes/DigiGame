extends "res://src/ui/BattleResultScreen.gd"
class_name ParallelBattleResultScreen

signal parallel_card_batch_finished(sequence_id: int)

var _parallel_card_tweens: Array[Tween] = []
var _pending_parallel_cards := 0


func hide_result() -> void:
	var cancelled_sequence := _sequence_id
	_sequence_id += 1
	_animating = false
	_cancel_parallel_card_animations(cancelled_sequence)
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	visible = false
	_result_key = ""


func _play_sequence(sequence_id: int) -> void:
	if sequence_id != _sequence_id or not visible:
		return
	var outcome := String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))
	_shell.modulate.a = 0.0
	_shell.scale = Vector2(0.985, 0.985)
	_shell.pivot_offset = _shell.size * 0.5
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_shell, "modulate:a", 1.0, 0.22)
	_active_tween.tween_property(_shell, "scale", Vector2.ONE, 0.22)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return

	_active_tween = create_tween().set_parallel(true)
	for index in range(_cards.size()):
		var panel: Control = _cards[index]["panel"] as Control
		panel.position.y += 10.0
		_active_tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_delay(float(index) * 0.07)
		_active_tween.tween_property(panel, "position:y", panel.position.y - 10.0, 0.18).set_delay(float(index) * 0.07)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return

	if outcome != "victory":
		_apply_final_state()
		_finish_animation()
		return

	# Every Digimon owns an independent timeline. All XP counters/bars begin in
	# the same frame, and each LEVEL UP celebration fires as soon as that card's
	# own XP crosses the threshold. A slow/multi-level card never blocks another.
	var running_cards := _start_parallel_card_animations(sequence_id)
	if running_cards > 0:
		var finished_sequence: int = await parallel_card_batch_finished
		if finished_sequence != sequence_id or sequence_id != _sequence_id:
			return

	await _animate_bits(sequence_id)
	if sequence_id != _sequence_id:
		return
	_finish_animation()


func _start_parallel_card_animations(sequence_id: int) -> int:
	_parallel_card_tweens.clear()
	_pending_parallel_cards = 0

	for card: Dictionary in _cards:
		var reward: Dictionary = card["reward"] as Dictionary
		var xp_gained := int(reward.get("xp_gained", 0))
		if xp_gained <= 0:
			(card["gain"] as Label).text = "+0 XP"
			_set_card_final(card)
			_set_unlock_text(card)
			continue

		_pending_parallel_cards += 1
		_start_card_timeline(card, sequence_id)

	return _pending_parallel_cards


func _start_card_timeline(card: Dictionary, sequence_id: int) -> void:
	var reward: Dictionary = card["reward"] as Dictionary
	var gain_label: Label = card["gain"] as Label
	var xp_gained := int(reward.get("xp_gained", 0))
	var tween := create_tween()
	_parallel_card_tweens.append(tween)

	# The visible +XP counter starts together for every party member.
	tween.tween_method(
		Callable(self, "_set_gain_counter").bind(gain_label),
		0.0,
		float(xp_gained),
		0.34
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var steps = reward.get("level_steps", [])
	if steps is Array:
		for raw_step in steps:
			if not raw_step is Dictionary:
				continue
			var step: Dictionary = raw_step
			var required := int(step.get("required", 0))
			var start_exp := int(step.get("start_exp", 0))
			var end_exp := int(step.get("end_exp", 0))
			var duration := clampf(
				0.24 + float(maxi(0, end_exp - start_exp)) / maxf(float(maxi(required, 1)), 1.0) * 0.42,
				0.24,
				0.62
			)

			tween.tween_callback(Callable(self, "_prepare_parallel_step").bind(card, reward, step))
			tween.tween_method(
				Callable(self, "_set_card_xp_value").bind(card, required),
				float(start_exp),
				float(end_exp),
				duration
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			if bool(step.get("leveled_up", false)):
				var new_level := int(step.get("next_level", int(step.get("level", 1)) + 1))
				var badge: Label = card["level_up"] as Label
				tween.tween_callback(Callable(self, "_begin_parallel_level_up").bind(card, new_level))
				tween.tween_property(badge, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(badge, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(badge, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_interval(0.34)
				tween.tween_property(badge, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.tween_callback(Callable(self, "_end_parallel_level_up").bind(card))

	tween.tween_callback(Callable(self, "_finalize_parallel_card").bind(card))
	tween.finished.connect(Callable(self, "_on_parallel_card_finished").bind(sequence_id), CONNECT_ONE_SHOT)


func _prepare_parallel_step(card: Dictionary, reward: Dictionary, step: Dictionary) -> void:
	var level := int(step.get("level", 1))
	var rank := String(reward.get("rank", ""))
	(card["level"] as Label).text = "Lv. %d  •  %s" % [level, rank]
	_set_card_xp_value(float(step.get("start_exp", 0)), card, int(step.get("required", 0)))


func _begin_parallel_level_up(card: Dictionary, new_level: int) -> void:
	var panel: PanelContainer = card["panel"] as PanelContainer
	var badge: Label = card["level_up"] as Label
	var reward: Dictionary = card["reward"] as Dictionary
	var rank := String(reward.get("rank", ""))

	(card["level"] as Label).text = "Lv. %d  •  %s" % [new_level, rank]
	badge.text = "LEVEL UP!  Lv. %d" % new_level
	badge.visible = true
	badge.modulate.a = 0.0
	badge.scale = Vector2(0.82, 0.82)
	badge.pivot_offset = badge.size * 0.5
	panel.add_theme_stylebox_override("panel", _card_style(UI.GOLD, true))


func _end_parallel_level_up(card: Dictionary) -> void:
	var badge: Label = card["level_up"] as Label
	var panel: PanelContainer = card["panel"] as PanelContainer
	badge.visible = false
	panel.add_theme_stylebox_override("panel", _card_style(card["accent"] as Color, false))


func _finalize_parallel_card(card: Dictionary) -> void:
	_set_card_final(card)
	_set_unlock_text(card)


func _on_parallel_card_finished(sequence_id: int) -> void:
	if sequence_id != _sequence_id:
		return
	_pending_parallel_cards = maxi(0, _pending_parallel_cards - 1)
	if _pending_parallel_cards == 0:
		_parallel_card_tweens.clear()
		parallel_card_batch_finished.emit(sequence_id)


func _cancel_parallel_card_animations(cancelled_sequence: int) -> void:
	var had_pending := _pending_parallel_cards > 0
	for tween: Tween in _parallel_card_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_parallel_card_tweens.clear()
	_pending_parallel_cards = 0
	if had_pending:
		# Wake the orchestration coroutine so it can observe the incremented
		# sequence id and exit cleanly instead of remaining suspended forever.
		parallel_card_batch_finished.emit(cancelled_sequence)


func _on_continue_pressed() -> void:
	if _animating:
		var cancelled_sequence := _sequence_id
		_sequence_id += 1
		_cancel_parallel_card_animations(cancelled_sequence)
		if _active_tween != null and _active_tween.is_valid():
			_active_tween.kill()
		_apply_final_state()
		_finish_animation()
		return
	return_requested.emit()
