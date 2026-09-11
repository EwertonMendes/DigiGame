extends "res://src/ui/BattleResultScreen.gd"
class_name ParallelBattleResultScreen

signal parallel_card_batch_finished(sequence_id: int)

const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")

var _parallel_card_tweens: Array[Tween] = []
var _pending_parallel_cards := 0
var _result_divider: TextureRect = null


func _build_ui() -> void:
	super._build_ui()
	_replace_result_divider_with_kenney_asset()
	SKIN.apply_button(_continue_button, UI.GOLD)


func _rebuild() -> void:
	super._rebuild()
	_apply_result_skin(_current_result_accent())


func _create_party_card(reward: Dictionary, accent: Color, rewards_enabled: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.name = "VictoryDigimonCard"
	card.custom_minimum_size = Vector2(0.0, 146.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", SKIN.frame_style(UI.FRAME_DARK))
	_party_grid.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "VictoryPortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(92.0, 106.0)
	portrait_frame.add_theme_stylebox_override(
		"panel",
		SKIN.frame_style(UI.FRAME_DARK, Vector4(6.0, 6.0, 6.0, 6.0), 10.0)
	)
	row.add_child(portrait_frame)

	var portrait := PortraitPreviewScript.new()
	portrait.custom_minimum_size = Vector2(84.0, 98.0)
	portrait.set_species(String(reward.get("species_name", "")))
	portrait_frame.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var name_label := _label(
		String(reward.get("display_name", reward.get("species_name", "Digimon"))),
		17,
		UI.TEXT,
		true
	)
	info.add_child(name_label)

	var rank := String(reward.get("rank", ""))
	var level_label := _label(
		"Lv. %d  •  %s" % [int(reward.get("old_level", 1)), rank],
		12,
		UI.rank_color(rank)
	)
	info.add_child(level_label)

	var xp_bar := ProgressBar.new()
	xp_bar.name = "VictoryXPBar"
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0.0, 18.0)
	xp_bar.add_theme_stylebox_override("background", SKIN.progress_track_style())
	xp_bar.add_theme_stylebox_override("fill", SKIN.progress_fill_style(accent))
	info.add_child(xp_bar)

	var required := int(reward.get("old_xp_required", 0))
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(reward.get("old_exp", 0)) if required > 0 else 1.0

	var xp_text := _label(_xp_text(int(reward.get("old_exp", 0)), required), 11, UI.MUTED)
	info.add_child(xp_text)

	var gained := _label(
		"+0 XP" if rewards_enabled else "Battle lost",
		12,
		UI.CYAN if rewards_enabled else UI.RED,
		true
	)
	info.add_child(gained)

	var unlocks := _label("", 10, UI.GREEN)
	unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(unlocks)

	var level_up := _label("LEVEL UP!", 18, UI.GOLD, true)
	level_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up.custom_minimum_size = Vector2(0.0, 30.0)
	level_up.add_theme_stylebox_override(
		"normal",
		SKIN.frame_style(UI.GOLD, Vector4(8.0, 3.0, 8.0, 3.0), 10.0)
	)
	level_up.visible = false
	info.add_child(level_up)

	card.modulate.a = 0.0
	return {
		"panel": card,
		"portrait_frame": portrait_frame,
		"level": level_label,
		"bar": xp_bar,
		"xp_text": xp_text,
		"gain": gained,
		"unlocks": unlocks,
		"level_up": level_up,
		"reward": reward,
		"accent": accent,
	}


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
	panel.add_theme_stylebox_override("panel", SKIN.frame_style(UI.GOLD))


func _end_parallel_level_up(card: Dictionary) -> void:
	var badge: Label = card["level_up"] as Label
	var panel: PanelContainer = card["panel"] as PanelContainer
	badge.visible = false
	panel.add_theme_stylebox_override("panel", SKIN.frame_style(UI.FRAME_DARK))


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


func _apply_final_state() -> void:
	super._apply_final_state()
	_apply_result_skin(_current_result_accent())


func _layout() -> void:
	super._layout()
	if _shell == null:
		return
	var style := _shell.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null:
		return
	var compact := UI.is_compact(get_viewport(), 880.0)
	style.set_content_margin(SIDE_LEFT, 18.0 if compact else 26.0)
	style.set_content_margin(SIDE_RIGHT, 18.0 if compact else 26.0)
	style.set_content_margin(SIDE_TOP, 16.0 if compact else 22.0)
	style.set_content_margin(SIDE_BOTTOM, 16.0 if compact else 22.0)


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


func _replace_result_divider_with_kenney_asset() -> void:
	if _content == null:
		return
	for child: Node in _content.get_children():
		if not child is HSeparator:
			continue
		# Keep the original Control alive because DigiUiRuntime decorates freshly
		# added nodes deferred. Hiding it avoids a dangling deferred argument while
		# ensuring no Godot-drawn separator is ever visible or consumes layout.
		var separator := child as HSeparator
		var separator_index := separator.get_index()
		separator.visible = false
		separator.custom_minimum_size = Vector2.ZERO

		_result_divider = TextureRect.new()
		_result_divider.name = "KenneyResultDivider"
		_result_divider.texture = SKIN.DIVIDER_TEXTURE
		_result_divider.custom_minimum_size = Vector2(0.0, 10.0)
		_result_divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_result_divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_result_divider.stretch_mode = TextureRect.STRETCH_SCALE
		_result_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_result_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_result_divider.modulate = UI.GOLD
		_content.add_child(_result_divider)
		_content.move_child(_result_divider, separator_index + 1)
		return


func _apply_result_skin(accent: Color) -> void:
	if _shell != null:
		_shell.add_theme_stylebox_override(
			"panel",
			SKIN.frame_style(UI.FRAME_DARK, _shell_content_margins())
		)
	if _reward_panel != null:
		_reward_panel.add_theme_stylebox_override(
			"panel",
			SKIN.frame_style(UI.FRAME_DARK, Vector4(12.0, 9.0, 12.0, 9.0))
		)
	if _continue_button != null:
		SKIN.apply_button(_continue_button, accent)
	if _result_divider != null:
		_result_divider.modulate = accent
	for card: Dictionary in _cards:
		_apply_kenney_card_skin(card)


func _apply_kenney_card_skin(card: Dictionary) -> void:
	var panel: PanelContainer = card.get("panel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", SKIN.frame_style(UI.FRAME_DARK))
	var portrait_frame: PanelContainer = card.get("portrait_frame") as PanelContainer
	if portrait_frame != null:
		portrait_frame.add_theme_stylebox_override(
			"panel",
			SKIN.frame_style(UI.FRAME_DARK, Vector4(6.0, 6.0, 6.0, 6.0), 10.0)
		)
	var bar: ProgressBar = card.get("bar") as ProgressBar
	if bar != null:
		bar.add_theme_stylebox_override("background", SKIN.progress_track_style())
		bar.add_theme_stylebox_override("fill", SKIN.progress_fill_style(card.get("accent", UI.GOLD) as Color))
	var badge: Label = card.get("level_up") as Label
	if badge != null:
		badge.add_theme_stylebox_override(
			"normal",
			SKIN.frame_style(UI.GOLD, Vector4(8.0, 3.0, 8.0, 3.0), 10.0)
		)


func _shell_content_margins() -> Vector4:
	var compact := UI.is_compact(get_viewport(), 880.0)
	return Vector4(
		18.0 if compact else 26.0,
		16.0 if compact else 22.0,
		18.0 if compact else 26.0,
		16.0 if compact else 22.0
	)


func _current_result_accent() -> Color:
	var outcome := String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))
	match outcome:
		"escaped":
			return UI.CYAN
		"defeat":
			return UI.RED
	return UI.GOLD
