extends Control
class_name BattleResultScreen

signal return_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const MenuUiStyleScript = preload("res://src/ui/MenuUiStyle.gd")
const GlassPanelScript = preload("res://src/ui/components/DigiGlassPanel.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

const MAX_FRAME_SIZE := Vector2(1180.0, 760.0)
const DESKTOP_COLUMNS := 3
const TABLET_COLUMNS := 2

var _backdrop: ColorRect = null
var _shell: PanelContainer = null
var _content: VBoxContainer = null
var _hero_panel: PanelContainer = null
var _hero_accent: ColorRect = null
var _eyebrow: Label = null
var _title: Label = null
var _subtitle: Label = null
var _party_heading_value: Label = null
var _party_scroll: ScrollContainer = null
var _party_grid: GridContainer = null
var _reward_panel: PanelContainer = null
var _reward_title: Label = null
var _bits_value: Label = null
var _reward_details: VBoxContainer = null
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
	set_meta("digi_ui_v2_component", true)
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
	var key := "%s:%s:%s" % [
		str(result.get("battle_seed", "")),
		str(result.get("outcome", "")),
		str(result.get("acts", "")),
	]
	if visible and key == _result_key:
		return
	_result_key = key
	_result = result.duplicate(true)
	_sequence_id += 1
	_animating = true
	visible = true
	_rebuild()
	_layout()
	call_deferred("_layout")
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
	_backdrop.name = "BattleResultBackdropV2"
	_backdrop.color = Color(0.006, 0.015, 0.026, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_shell = GlassPanelScript.new() as PanelContainer
	_shell.name = "BattleResultV2"
	_shell.set_meta("digi_ui_v2_component", true)
	_shell.clip_contents = true
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_shell.call("configure_glass", V2.CYAN, "modal", Vector4(24.0, 20.0, 24.0, 20.0), 14)
	add_child(_shell)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_content)

	_hero_panel = PanelContainer.new()
	_hero_panel.name = "ResultHeroV2"
	_hero_panel.add_theme_stylebox_override("panel", V2.outlined_surface(V2.CYAN, true, 10))
	_content.add_child(_hero_panel)
	var hero_stack := VBoxContainer.new()
	hero_stack.add_theme_constant_override("separation", 4)
	_hero_panel.add_child(hero_stack)
	_hero_accent = ColorRect.new()
	_hero_accent.color = V2.CYAN
	_hero_accent.custom_minimum_size = Vector2(0.0, 3.0)
	_hero_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_stack.add_child(_hero_accent)
	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 16)
	hero_margin.add_theme_constant_override("margin_top", 10)
	hero_margin.add_theme_constant_override("margin_right", 16)
	hero_margin.add_theme_constant_override("margin_bottom", 12)
	hero_stack.add_child(hero_margin)
	var hero_body := VBoxContainer.new()
	hero_body.add_theme_constant_override("separation", 3)
	hero_margin.add_child(hero_body)
	_eyebrow = _label("BATTLE RESULT", 10, V2.MUTED, true)
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_body.add_child(_eyebrow)
	_title = _label("VICTORY", 40, V2.GREEN, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	_title.add_theme_constant_override("outline_size", 4)
	hero_body.add_child(_title)
	_subtitle = _label("", 12, V2.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_body.add_child(_subtitle)

	var party_heading := HBoxContainer.new()
	party_heading.add_theme_constant_override("separation", 10)
	_content.add_child(party_heading)
	var party_title := _label("SQUAD REPORT", 11, V2.TEXT, true)
	party_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_heading.add_child(party_title)
	_party_heading_value = _label("", 10, V2.MUTED, true)
	_party_heading_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	party_heading.add_child(_party_heading_value)

	_party_scroll = ScrollContainer.new()
	_party_scroll.name = "SquadReportScrollV2"
	_party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_party_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_party_scroll.follow_focus = true
	_party_scroll.scroll_deadzone = 8
	_party_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_party_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(_party_scroll)
	_party_grid = GridContainer.new()
	_party_grid.columns = DESKTOP_COLUMNS
	_party_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_grid.add_theme_constant_override("h_separation", 10)
	_party_grid.add_theme_constant_override("v_separation", 10)
	_party_scroll.add_child(_party_grid)

	_reward_panel = PanelContainer.new()
	_reward_panel.name = "BattleRewardsV2"
	_reward_panel.add_theme_stylebox_override("panel", V2.panel_style(V2.BORDER_SOFT, 8))
	_content.add_child(_reward_panel)
	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 14)
	reward_margin.add_theme_constant_override("margin_top", 10)
	reward_margin.add_theme_constant_override("margin_right", 14)
	reward_margin.add_theme_constant_override("margin_bottom", 10)
	_reward_panel.add_child(reward_margin)
	var reward_stack := VBoxContainer.new()
	reward_stack.add_theme_constant_override("separation", 7)
	reward_margin.add_child(reward_stack)
	var reward_header := HBoxContainer.new()
	reward_header.add_theme_constant_override("separation", 12)
	reward_stack.add_child(reward_header)
	_reward_title = _label("BATTLE REWARDS", 11, V2.TEXT, true)
	_reward_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_header.add_child(_reward_title)
	_bits_value = _label("+0 Bits", 13, V2.AMBER, true)
	_bits_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_header.add_child(_bits_value)
	_reward_details = VBoxContainer.new()
	_reward_details.add_theme_constant_override("separation", 5)
	reward_stack.add_child(_reward_details)

	_continue_button = Button.new()
	_continue_button.name = "BattleResultContinueV2"
	_continue_button.text = "SKIP ANIMATION"
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue_button.custom_minimum_size = Vector2(0.0, V2.TOUCH_TARGET)
	_continue_button.add_theme_font_size_override("font_size", 12)
	_continue_button.add_theme_color_override("font_color", V2.TEXT)
	_continue_button.add_theme_color_override("font_hover_color", V2.WHITE)
	_continue_button.add_theme_color_override("font_focus_color", V2.WHITE)
	_continue_button.add_theme_color_override("font_pressed_color", V2.WHITE)
	V2.apply_heading(_continue_button)
	_style_continue_button(V2.CYAN)
	_continue_button.pressed.connect(_on_continue_pressed)
	_content.add_child(_continue_button)


func _rebuild() -> void:
	_clear_container(_party_grid)
	_cards.clear()

	var outcome := _result_outcome()
	var accent := _outcome_accent(outcome)
	_shell.call("configure_glass", accent, "modal", Vector4(24.0, 20.0, 24.0, 20.0), 14)
	_hero_panel.add_theme_stylebox_override("panel", V2.outlined_surface(accent, true, 10))
	_hero_accent.color = accent
	_title.add_theme_color_override("font_color", accent)
	_reward_panel.add_theme_stylebox_override(
		"panel",
		V2.panel_style(Color(accent.r, accent.g, accent.b, 0.46), 8)
	)
	_style_continue_button(accent)

	match outcome:
		"victory":
			_title.text = "VICTORY"
		"escaped":
			_title.text = "RETREATED"
		_:
			_title.text = "DEFEAT"

	var acts := int(_result.get("acts", 0))
	_subtitle.text = _outcome_summary(outcome, acts)

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
	_party_heading_value.text = "%d ACTIVE" % active_party.size()
	for instance: DigimonInstance in active_party:
		var reward: Dictionary = reward_by_id.get(instance.id, {}) as Dictionary
		if reward.is_empty():
			reward = _snapshot_reward(instance)
		_cards.append(_create_party_card(reward, accent, outcome == "victory"))

	_bits_value.text = "+0 Bits" if outcome == "victory" else "NO REWARDS"
	_bits_value.add_theme_color_override("font_color", V2.AMBER if outcome == "victory" else V2.MUTED)
	_populate_reward_details(outcome)
	_continue_button.text = "SKIP ANIMATION"
	_continue_button.grab_focus()


func _populate_reward_details(outcome: String) -> void:
	_clear_container(_reward_details)
	if outcome != "victory":
		_reward_details.add_child(_reward_message(
			"No battle rewards recovered. Your squad keeps its current progression.",
			V2.MUTED
		))
		return

	var digi_data = _result.get("digi_data", {})
	if digi_data is Dictionary and not digi_data.is_empty():
		for species_name in digi_data.keys():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var name_label := _label("%s DATA" % String(species_name).to_upper(), 10, V2.CYAN, true)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(_label("+%d" % int(digi_data[species_name]), 11, V2.GREEN, true))
			_reward_details.add_child(row)
	else:
		_reward_details.add_child(_reward_message("No Digi Data recovered in this battle.", V2.MUTED))


func _reward_message(message: String, color: Color) -> Label:
	var label := _label(message, 10, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _snapshot_reward(instance: DigimonInstance) -> Dictionary:
	var database: DigimonDatabase = OverworldState.get_database()
	var species: Dictionary = database.get_by_seed(instance.species_seed) if database != null else {}
	var required := 0
	if instance.level < 99:
		var progression = ProgressionServiceScript.new(database)
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
	card.name = "BattleResultDigimonCardV2"
	card.custom_minimum_size = Vector2(0.0, 126.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(accent, false))
	_party_grid.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	var accent_bar := ColorRect.new()
	accent_bar.color = Color(accent.r, accent.g, accent.b, 0.86)
	accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent_bar)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(78.0, 94.0)
	portrait_frame.add_theme_stylebox_override(
		"panel",
		V2.surface_style(V2.PANEL_DEEP, Color(accent.r, accent.g, accent.b, 0.34), 7, Vector4(4.0, 4.0, 4.0, 4.0))
	)
	row.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new()
	portrait.custom_minimum_size = Vector2(70.0, 86.0)
	portrait.set_species(String(reward.get("species_name", "")))
	portrait_frame.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := _label(
		String(reward.get("display_name", reward.get("species_name", "Digimon"))),
		15,
		V2.TEXT,
		true
	)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var rank := String(reward.get("rank", ""))
	var level_label := _label("Lv. %d  •  %s" % [int(reward.get("old_level", 1)), rank], 10, V2.rank_color(rank))
	info.add_child(level_label)

	var xp_bar := ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0.0, 10.0)
	xp_bar.add_theme_stylebox_override("background", V2.progress_track_style())
	xp_bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent))
	info.add_child(xp_bar)
	var required := int(reward.get("old_xp_required", 0))
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(reward.get("old_exp", 0)) if required > 0 else 1.0
	var xp_text := _label(_xp_text(int(reward.get("old_exp", 0)), required), 9, V2.MUTED)
	info.add_child(xp_text)
	var gained := _label(
		"+0 XP" if rewards_enabled else _non_victory_status(_result_outcome()),
		10,
		V2.CYAN if rewards_enabled else _outcome_accent(_result_outcome()),
		true
	)
	info.add_child(gained)
	var unlocks := _label("", 9, V2.GREEN)
	unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(unlocks)
	var level_up := _label("LEVEL UP!", 14, V2.AMBER, true)
	level_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up.add_theme_stylebox_override("normal", V2.pill_style(V2.AMBER, true))
	level_up.custom_minimum_size = Vector2(0.0, 28.0)
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


func _play_sequence(sequence_id: int) -> void:
	if not await _animate_entrance(sequence_id):
		return
	var outcome := _result_outcome()
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


func _animate_entrance(sequence_id: int) -> bool:
	if sequence_id != _sequence_id or not visible:
		return false
	_backdrop.modulate.a = 0.0
	_shell.modulate.a = 0.0
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.16)
	_active_tween.tween_property(_shell, "modulate:a", 1.0, 0.22)
	await _active_tween.finished
	if sequence_id != _sequence_id:
		return false

	if not _cards.is_empty():
		_active_tween = create_tween().set_parallel(true)
		for index in range(_cards.size()):
			var panel: Control = _cards[index]["panel"] as Control
			panel.position.y += 8.0
			_active_tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_delay(float(index) * 0.055)
			_active_tween.tween_property(panel, "position:y", panel.position.y - 8.0, 0.18).set_delay(float(index) * 0.055)
		await _active_tween.finished
	return sequence_id == _sequence_id


func _animate_card(card: Dictionary, sequence_id: int) -> void:
	var reward: Dictionary = card["reward"] as Dictionary
	var gain_label: Label = card["gain"] as Label
	var xp_gained := int(reward.get("xp_gained", 0))
	if xp_gained <= 0:
		gain_label.text = "+0 XP"
		_set_card_final(card)
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
			var duration := clampf(
				0.24 + float(maxi(0, end_exp - start_exp)) / maxf(float(maxi(required, 1)), 1.0) * 0.42,
				0.24,
				0.62
			)
			_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_active_tween.tween_method(
				Callable(self, "_set_card_xp_value").bind(card, required),
				float(start_exp),
				float(end_exp),
				duration
			)
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
	panel.add_theme_stylebox_override("panel", _card_style(V2.AMBER, true))
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(badge, "modulate:a", 1.0, 0.12)
	_active_tween.parallel().tween_property(badge, "scale", Vector2(1.08, 1.08), 0.22)
	_active_tween.tween_property(badge, "scale", Vector2.ONE, 0.12)
	_active_tween.tween_interval(0.30)
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
	_active_tween.tween_method(Callable(self, "_set_bits_counter"), 0.0, float(bits), 0.42)
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
	var outcome := _result_outcome()
	for card: Dictionary in _cards:
		var panel: PanelContainer = card["panel"] as PanelContainer
		panel.modulate.a = 1.0
		_set_card_final(card)
		_set_unlock_text(card)
		var reward: Dictionary = card["reward"] as Dictionary
		(card["gain"] as Label).text = (
			"+%d XP" % int(reward.get("xp_gained", 0))
			if outcome == "victory"
			else _non_victory_status(outcome)
		)
		(card["level_up"] as Label).visible = false
		panel.add_theme_stylebox_override("panel", _card_style(card["accent"] as Color, false))
	_bits_value.text = "+%d Bits" % int(_result.get("bits", 0)) if outcome == "victory" else "NO REWARDS"
	_shell.modulate.a = 1.0
	_backdrop.modulate.a = 1.0


func _finish_animation() -> void:
	_animating = false
	_continue_button.text = "RETURN TO COMMONS"
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
	var physical := V2.physical_window_size(viewport)
	_last_viewport_size = viewport.get_visible_rect().size
	_last_window_size = DisplayServer.window_get_size()

	var compact := V2.is_compact(viewport, 900.0)
	var narrow := physical.x < 720.0
	var columns := 1 if narrow else (TABLET_COLUMNS if physical.x < 1180.0 else DESKTOP_COLUMNS)
	_party_grid.columns = columns

	var card_height := 116.0 if compact else 126.0
	for card: Dictionary in _cards:
		var panel := card.get("panel") as Control
		if panel != null:
			panel.custom_minimum_size = Vector2(0.0, card_height)

	var row_count := maxi(1, ceili(float(maxi(1, _cards.size())) / float(columns)))
	var party_height := card_height
	if row_count > 1:
		party_height = minf(card_height * 2.0 + 10.0, card_height * float(row_count) + 10.0 * float(row_count - 1))
	if narrow:
		party_height = minf(maxf(176.0, physical.y * 0.34), 300.0)
	_party_scroll.custom_minimum_size = Vector2(0.0, party_height)

	_title.add_theme_font_size_override("font_size", 31 if compact else 40)
	_subtitle.add_theme_font_size_override("font_size", 10 if compact else 12)
	_continue_button.custom_minimum_size.y = V2.TOUCH_TARGET

	var desired_height := minf(MAX_FRAME_SIZE.y, 340.0 + party_height)
	MenuUiStyleScript.apply_safe_frame(
		_shell,
		viewport,
		Vector2(MAX_FRAME_SIZE.x, desired_height),
		900.0
	)
	# Safe-frame positioning assumes scaling around the top-left. Keep the layout
	# pivot at zero so fit scaling stays mathematically centered and cannot drift
	# down/right when first-frame content grows beyond the available viewport.
	_shell.pivot_offset = Vector2.ZERO


func _label(text_value: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _xp_text(value: int, required: int) -> String:
	return "MAX LEVEL" if required <= 0 else "%d / %d XP" % [value, required]


func _card_style(accent: Color, highlighted: bool) -> StyleBoxFlat:
	var style := V2.outlined_surface(accent, highlighted, 8)
	style.bg_color = Color(V2.PANEL_FILL.r, V2.PANEL_FILL.g, V2.PANEL_FILL.b, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.96 if highlighted else 0.30)
	style.set_border_width_all(2 if highlighted else 1)
	return style


func _style_continue_button(accent: Color) -> void:
	_continue_button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal"))
	_continue_button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover"))
	_continue_button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus"))
	_continue_button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed"))
	_continue_button.add_theme_stylebox_override("hover_pressed", V2.button_style(accent, "pressed"))


func _result_outcome() -> String:
	return String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))


func _outcome_accent(outcome: String) -> Color:
	match outcome:
		"victory":
			return V2.GREEN
		"escaped":
			return V2.CYAN
		_:
			return V2.RED


func _outcome_summary(outcome: String, acts: int) -> String:
	var turn_copy := "%d ACT%s" % [acts, "" if acts == 1 else "S"]
	match outcome:
		"victory":
			return "%s  •  Opponents defeated  •  Rewards secured" % turn_copy
		"escaped":
			return "%s  •  Squad withdrew safely  •  No rewards recovered" % turn_copy
		_:
			return "%s  •  Squad defeated  •  Regroup and try again" % turn_copy


func _non_victory_status(outcome: String) -> String:
	return "Retreated safely" if outcome == "escaped" else "Defeated · No XP"


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()