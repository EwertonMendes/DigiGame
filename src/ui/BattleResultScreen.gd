extends Control
class_name BattleResultScreen

signal return_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")

var _backdrop: ColorRect = null
var _shell: PanelContainer = null
var _content: VBoxContainer = null
var _eyebrow: Label = null
var _title: Label = null
var _subtitle: Label = null
var _party_scroll: ScrollContainer = null
var _party_grid: GridContainer = null
var _reward_panel: PanelContainer = null
var _bits_value: Label = null
var _data_value: Label = null
var _continue_button: Button = null
var _cards: Array[Dictionary] = []
var _result: Dictionary = {}
var _result_key := ""
var _sequence_id := 0
var _animating := false
var _active_tween: Tween = null
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	set_process(true)


func _process(_delta: float) -> void:
	if not visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not _animating:
		return_requested.emit()
		get_viewport().set_input_as_handled()


func show_result(result: Dictionary) -> void:
	# Result fields are intentionally an extensible Variant-based contract. Use
	# str() here because numeric `acts` is valid input and String(int) is not a
	# supported constructor in Godot 4.7.
	var key := "%s:%s:%s" % [str(result.get("battle_seed", "")), str(result.get("outcome", "")), str(result.get("acts", ""))]
	if visible and key == _result_key:
		return
	_result_key = key
	_result = result.duplicate(true)
	_sequence_id += 1
	_animating = true
	visible = true
	_rebuild()
	_layout()
	call_deferred("_play_sequence", _sequence_id)


func hide_result() -> void:
	_sequence_id += 1
	_animating = false
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	visible = false
	_result_key = ""


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.004, 0.008, 0.018, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_shell = PanelContainer.new()
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shell)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_content)

	_eyebrow = _label("RESULT", 12, UI.MUTED, true)
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_eyebrow)

	_title = _label("VICTORY", 36, UI.GOLD, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_title.add_theme_constant_override("outline_size", 6)
	_content.add_child(_title)

	_subtitle = _label("", 13, UI.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_subtitle)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", UI.separator(UI.GOLD, 0.24))
	_content.add_child(separator)

	_party_scroll = ScrollContainer.new()
	_party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_party_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_party_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_party_scroll)

	_party_grid = GridContainer.new()
	_party_grid.columns = 3
	_party_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_grid.add_theme_constant_override("h_separation", 10)
	_party_grid.add_theme_constant_override("v_separation", 8)
	_party_scroll.add_child(_party_grid)

	_reward_panel = PanelContainer.new()
	_reward_panel.add_theme_stylebox_override("panel", _reward_style(UI.CYAN))
	_content.add_child(_reward_panel)
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 18)
	_reward_panel.add_child(reward_row)
	var reward_title := _label("REWARDS", 12, UI.MUTED, true)
	reward_title.custom_minimum_size = Vector2(82.0, 0.0)
	reward_row.add_child(reward_title)
	_bits_value = _label("0 Bits", 16, UI.GOLD, true)
	_bits_value.custom_minimum_size = Vector2(120.0, 0.0)
	reward_row.add_child(_bits_value)
	_data_value = _label("", 13, UI.CYAN)
	_data_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_data_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_row.add_child(_data_value)

	_continue_button = Button.new()
	_continue_button.text = "SKIP"
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue_button.custom_minimum_size = Vector2(0.0, 48.0)
	_continue_button.add_theme_font_size_override("font_size", 14)
	_continue_button.add_theme_color_override("font_color", UI.TEXT)
	_continue_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_continue_button.add_theme_color_override("font_focus_color", Color.WHITE)
	_continue_button.add_theme_stylebox_override("normal", UI.action_style(UI.GOLD, "normal"))
	_continue_button.add_theme_stylebox_override("hover", UI.action_style(UI.GOLD, "hover"))
	_continue_button.add_theme_stylebox_override("pressed", UI.action_style(UI.GOLD, "pressed"))
	_continue_button.add_theme_stylebox_override("focus", UI.focus_outline(UI.GOLD, 8))
	_continue_button.pressed.connect(_on_continue_pressed)
	_content.add_child(_continue_button)


func _rebuild() -> void:
	for child in _party_grid.get_children():
		_party_grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	var outcome := String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))
	var accent := UI.GOLD
	match outcome:
		"victory":
			_eyebrow.text = "BATTLE RESULT"
			_title.text = "VICTORY"
			accent = UI.GOLD
		"escaped":
			_eyebrow.text = "BATTLE RESULT"
			_title.text = "RETREATED"
			accent = UI.CYAN
		_:
			_eyebrow.text = "BATTLE RESULT"
			_title.text = "DEFEAT"
			accent = UI.RED
	_title.add_theme_color_override("font_color", accent)
	_shell.add_theme_stylebox_override("panel", _shell_style(accent))
	_reward_panel.add_theme_stylebox_override("panel", _reward_style(accent))
	_continue_button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	_continue_button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	_continue_button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	_continue_button.add_theme_stylebox_override("focus", UI.focus_outline(accent, 8))

	var acts := int(_result.get("acts", 0))
	_subtitle.text = "%d ACT%s  •  %s" % [acts, "" if acts == 1 else "S", "Rewards secured" if outcome == "victory" else "Return, regroup, and try again"]

	var reward_by_id: Dictionary = {}
	var xp_rewards = _result.get("xp_rewards", {})
	if xp_rewards is Dictionary:
		var raw_digimon = xp_rewards.get("digimon", [])
		if raw_digimon is Array:
			for raw_reward in raw_digimon:
				if raw_reward is Dictionary:
					var reward: Dictionary = raw_reward
					reward_by_id[String(reward.get("instance_id", ""))] = reward

	var active_party: Array[DigimonInstance] = OverworldState.get_active_instances()
	for instance: DigimonInstance in active_party:
		var reward: Dictionary = reward_by_id.get(instance.id, {}) as Dictionary
		if reward.is_empty():
			reward = _snapshot_reward(instance)
		_cards.append(_create_party_card(reward, accent, outcome == "victory"))

	var bits := int(_result.get("bits", 0)) if outcome == "victory" else 0
	_bits_value.text = "+0 Bits" if outcome == "victory" else "NO REWARDS"
	_bits_value.add_theme_color_override("font_color", UI.GOLD if outcome == "victory" else UI.MUTED)
	var digi_data = _result.get("digi_data", {})
	if outcome == "victory" and digi_data is Dictionary and not digi_data.is_empty():
		var data_parts: Array[String] = []
		for species_name in digi_data.keys():
			data_parts.append("%s +%d Data" % [String(species_name), int(digi_data[species_name])])
		_data_value.text = "  •  ".join(data_parts)
	else:
		_data_value.text = "No XP, Bits, or Digi Data earned." if outcome != "victory" else "No Digi Data recovered."
	_continue_button.text = "SKIP" if outcome == "victory" else "CONTINUE"
	_continue_button.grab_focus()
	if outcome != "victory":
		_animating = false


func _snapshot_reward(instance: DigimonInstance) -> Dictionary:
	var database: DigimonDatabase = OverworldState.get_database()
	var species: Dictionary = database.get_by_seed(instance.species_seed) if database != null else {}
	var required := 0
	if instance.level < 99:
		var progression = preload("res://src/digimon/DigimonProgressionService.gd").new(database)
		required = int(progression.exp_to_next_level(instance))
	var species_name := String(species.get("name", "Digimon"))
	return {
		"instance_id": instance.id,
		"display_name": instance.get_display_name(species_name),
		"species_name": species_name,
		"rank": String(species.get("rank", "")),
		"xp_gained": 0,
		"old_level": instance.level,
		"new_level": instance.level,
		"levels_gained": 0,
		"old_exp": instance.exp,
		"new_exp": instance.exp,
		"old_xp_required": required,
		"new_xp_required": required,
		"level_steps": [],
		"learned_skills": [],
		"unlocked_evolutions": [],
	}


func _create_party_card(reward: Dictionary, accent: Color, rewards_enabled: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 146.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(accent, false))
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
	portrait_frame.custom_minimum_size = Vector2(92.0, 106.0)
	portrait_frame.add_theme_stylebox_override("panel", UI.turn_node_style(UI.CYAN, false))
	row.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new()
	portrait.custom_minimum_size = Vector2(84.0, 98.0)
	portrait.set_species(String(reward.get("species_name", "")))
	portrait_frame.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var name_label := _label(String(reward.get("display_name", reward.get("species_name", "Digimon"))), 17, UI.TEXT, true)
	info.add_child(name_label)
	var rank := String(reward.get("rank", ""))
	var level_label := _label("Lv. %d  •  %s" % [int(reward.get("old_level", 1)), rank], 12, UI.rank_color(rank))
	info.add_child(level_label)

	var xp_bar := ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0.0, 12.0)
	xp_bar.add_theme_stylebox_override("background", _xp_bar_background())
	xp_bar.add_theme_stylebox_override("fill", _xp_bar_fill(accent))
	info.add_child(xp_bar)
	var required := int(reward.get("old_xp_required", 0))
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(reward.get("old_exp", 0)) if required > 0 else 1.0
	var xp_text := _label(_xp_text(int(reward.get("old_exp", 0)), required), 11, UI.MUTED)
	info.add_child(xp_text)
	var gained := _label("+0 XP" if rewards_enabled else "Battle lost", 12, UI.CYAN if rewards_enabled else UI.RED, true)
	info.add_child(gained)
	var unlocks := _label("", 10, UI.GREEN)
	unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(unlocks)
	var level_up := _label("LEVEL UP!", 21, UI.GOLD, true)
	level_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up.add_theme_color_override("font_outline_color", Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.52))
	level_up.add_theme_constant_override("outline_size", 8)
	level_up.visible = false
	info.add_child(level_up)

	card.modulate.a = 0.0
	return {
		"panel": card,
		"level": level_label,
		"bar": xp_bar,
		"xp_text": xp_text,
		"gain": gained,
		"unlocks": unlocks,
		"level_up": level_up,
		"reward": reward,
		"accent": accent,
	}


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

	for card: Dictionary in _cards:
		await _animate_card(card, sequence_id)
		if sequence_id != _sequence_id:
			return
	await _animate_bits(sequence_id)
	if sequence_id != _sequence_id:
		return
	_finish_animation()


func _animate_card(card: Dictionary, sequence_id: int) -> void:
	var reward: Dictionary = card["reward"] as Dictionary
	var gain_label: Label = card["gain"] as Label
	var xp_gained := int(reward.get("xp_gained", 0))
	if xp_gained <= 0:
		gain_label.text = "+0 XP"
		_set_unlock_text(card)
		return

	_active_tween = create_tween()
	_active_tween.tween_method(Callable(self, "_set_gain_counter").bind(gain_label), 0.0, float(xp_gained), 0.34)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return

	var steps = reward.get("level_steps", [])
	if steps is Array:
		for raw_step in steps:
			if not raw_step is Dictionary:
				continue
			var step: Dictionary = raw_step
			var required := int(step.get("required", 0))
			var start_exp := int(step.get("start_exp", 0))
			var end_exp := int(step.get("end_exp", 0))
			(card["level"] as Label).text = "Lv. %d  •  %s" % [int(step.get("level", 1)), String(reward.get("rank", ""))]
			_set_card_xp_value(float(start_exp), card, required)
			var duration := clampf(0.24 + float(maxi(0, end_exp - start_exp)) / maxf(float(maxi(required, 1)), 1.0) * 0.42, 0.24, 0.62)
			_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_active_tween.tween_method(Callable(self, "_set_card_xp_value").bind(card, required), float(start_exp), float(end_exp), duration)
			await _active_tween.finished
			if sequence_id != _sequence_id:
				return
			if bool(step.get("leveled_up", false)):
				await _celebrate_level_up(card, int(step.get("next_level", int(step.get("level", 1)) + 1)), sequence_id)
				if sequence_id != _sequence_id:
					return
	_set_card_final(card)
	_set_unlock_text(card)


func _celebrate_level_up(card: Dictionary, new_level: int, sequence_id: int) -> void:
	var panel: PanelContainer = card["panel"] as PanelContainer
	var badge: Label = card["level_up"] as Label
	var level_label: Label = card["level"] as Label
	var rank := String((card["reward"] as Dictionary).get("rank", ""))
	level_label.text = "Lv. %d  •  %s" % [new_level, rank]
	badge.text = "LEVEL UP!  Lv. %d" % new_level
	badge.visible = true
	badge.modulate.a = 0.0
	badge.scale = Vector2(0.82, 0.82)
	badge.pivot_offset = badge.size * 0.5
	panel.add_theme_stylebox_override("panel", _card_style(UI.GOLD, true))
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(badge, "modulate:a", 1.0, 0.12)
	_active_tween.parallel().tween_property(badge, "scale", Vector2(1.08, 1.08), 0.22)
	_active_tween.tween_property(badge, "scale", Vector2.ONE, 0.12)
	_active_tween.tween_interval(0.34)
	_active_tween.tween_property(badge, "modulate:a", 0.0, 0.18)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return
	badge.visible = false
	panel.add_theme_stylebox_override("panel", _card_style(card["accent"] as Color, false))


func _animate_bits(sequence_id: int) -> void:
	var bits := int(_result.get("bits", 0))
	if bits <= 0:
		_bits_value.text = "+0 Bits"
		return
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(Callable(self, "_set_bits_counter"), 0.0, float(bits), 0.45)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return


func _set_gain_counter(value: float, label: Label) -> void:
	if label != null:
		label.text = "+%d XP" % int(round(value))


func _set_bits_counter(value: float) -> void:
	_bits_value.text = "+%d Bits" % int(round(value))


func _set_card_xp_value(value: float, card: Dictionary, required: int) -> void:
	var bar: ProgressBar = card["bar"] as ProgressBar
	var text: Label = card["xp_text"] as Label
	if required <= 0:
		bar.max_value = 1.0
		bar.value = 1.0
		text.text = "MAX LEVEL"
		return
	bar.max_value = float(required)
	bar.value = clampf(value, 0.0, float(required))
	text.text = _xp_text(int(round(value)), required)


func _set_card_final(card: Dictionary) -> void:
	var reward: Dictionary = card["reward"] as Dictionary
	var new_level := int(reward.get("new_level", reward.get("old_level", 1)))
	var rank := String(reward.get("rank", ""))
	(card["level"] as Label).text = "Lv. %d  •  %s" % [new_level, rank]
	_set_card_xp_value(float(reward.get("new_exp", 0)), card, int(reward.get("new_xp_required", 0)))


func _set_unlock_text(card: Dictionary) -> void:
	var reward: Dictionary = card["reward"] as Dictionary
	var messages: Array[String] = []
	var learned = reward.get("learned_skills", [])
	if learned is Array and not learned.is_empty():
		var names: Array[String] = []
		for skill in learned:
			names.append(String(skill).replace("_", " ").capitalize())
		messages.append("New technique: %s" % ", ".join(names))
	var evolutions = reward.get("unlocked_evolutions", [])
	if evolutions is Array and not evolutions.is_empty():
		var evo_names: Array[String] = []
		for raw_evo in evolutions:
			if raw_evo is Dictionary:
				evo_names.append(String((raw_evo as Dictionary).get("name", "Evolution")))
		messages.append("Digivolution ready: %s" % ", ".join(evo_names))
	(card["unlocks"] as Label).text = "\n".join(messages)


func _apply_final_state() -> void:
	for card: Dictionary in _cards:
		var panel: PanelContainer = card["panel"] as PanelContainer
		panel.modulate.a = 1.0
		_set_card_final(card)
		_set_unlock_text(card)
		var reward: Dictionary = card["reward"] as Dictionary
		(card["gain"] as Label).text = "+%d XP" % int(reward.get("xp_gained", 0)) if bool(_result.get("victory", false)) else "Battle lost"
		(card["level_up"] as Label).visible = false
		panel.add_theme_stylebox_override("panel", _card_style(card["accent"] as Color, false))
	_bits_value.text = "+%d Bits" % int(_result.get("bits", 0)) if bool(_result.get("victory", false)) else "NO REWARDS"
	_shell.modulate.a = 1.0
	_shell.scale = Vector2.ONE


func _finish_animation() -> void:
	_animating = false
	_continue_button.text = "RETURN TO TERMINAL COMMONS"
	_continue_button.grab_focus()


func _on_continue_pressed() -> void:
	if _animating:
		_sequence_id += 1
		if _active_tween != null and _active_tween.is_valid():
			_active_tween.kill()
		_apply_final_state()
		_finish_animation()
		return
	return_requested.emit()


func _layout() -> void:
	if _shell == null:
		return
	var viewport := get_viewport()
	var physical := UI.physical_window_size(viewport)
	var ui_scale := UI.ui_scale(viewport)
	_last_viewport_size = viewport.get_visible_rect().size
	_last_window_size = DisplayServer.window_get_size()
	var portrait_mobile := physical.x < 620.0 and physical.y > physical.x
	var compact := UI.is_compact(viewport, 880.0)
	_party_grid.columns = 1 if portrait_mobile else 3
	var outer_margin := 12.0 if compact else 26.0
	var target_width := minf(1120.0, physical.x - outer_margin * 2.0)
	var target_height := minf(760.0, physical.y - outer_margin * 2.0)
	if portrait_mobile:
		target_width = physical.x - 16.0
		target_height = physical.y - 16.0
	_shell.scale = Vector2.ONE * ui_scale
	_shell.position = Vector2((physical.x - target_width) * 0.5 * ui_scale, (physical.y - target_height) * 0.5 * ui_scale)
	_shell.size = Vector2(target_width, target_height)
	var style := _shell.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.content_margin_left = 18.0 if compact else 26.0
		style.content_margin_right = 18.0 if compact else 26.0
		style.content_margin_top = 16.0 if compact else 22.0
		style.content_margin_bottom = 16.0 if compact else 22.0
	_party_scroll.custom_minimum_size = Vector2(0.0, maxf(150.0, target_height - (280.0 if portrait_mobile else 250.0)))
	_title.add_theme_font_size_override("font_size", 30 if compact else 40)
	_eyebrow.add_theme_font_size_override("font_size", 10 if compact else 12)
	_subtitle.add_theme_font_size_override("font_size", 11 if compact else 13)
	for card: Dictionary in _cards:
		var panel: Control = card["panel"] as Control
		panel.custom_minimum_size = Vector2(0.0, 132.0 if compact else 146.0)


func _label(text_value: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _xp_text(value: int, required: int) -> String:
	return "MAX LEVEL" if required <= 0 else "%d / %d XP" % [value, required]


func _shell_style(accent: Color) -> StyleBoxFlat:
	var style := UI.panel_strong(accent, 12)
	style.bg_color = Color(0.008, 0.012, 0.020, 0.97)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.60)
	style.set_border_width_all(1)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 12
	return style


func _reward_style(accent: Color) -> StyleBoxFlat:
	var style := UI.glass_panel(accent, 0.72, 7)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := UI.glass_panel(accent, 0.82 if highlighted else 0.68, 9)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.96 if highlighted else 0.28)
	style.set_border_width_all(2 if highlighted else 1)
	if highlighted:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.26)
		style.shadow_size = 8
	return style


func _xp_bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.52)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _xp_bar_fill(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
