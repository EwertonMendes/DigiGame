extends "res://src/ui/ParallelBattleResultScreen.gd"
class_name RetreatAwareBattleResultScreen

const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")


func _populate_reward_details(outcome: String) -> void:
	_clear_container(_reward_details)
	if outcome != "victory":
		var message := (
			"Retreat completed safely. No XP, Bits, or Digi Data were recovered."
			if outcome == "escaped"
			else "The squad was defeated. No XP, Bits, or Digi Data were recovered."
		)
		_reward_details.add_child(_reward_message(message, V2.MUTED))
		return

	var progress = _result.get("digi_data_progress", {})
	if progress is Dictionary and not progress.is_empty():
		for raw_seed in progress.keys():
			var entry = progress[raw_seed]
			if entry is Dictionary:
				_reward_details.add_child(_data_progress_row(entry as Dictionary, String(raw_seed)))
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
		return

	_reward_details.add_child(_reward_message("No Digi Data recovered in this battle.", V2.MUTED))


func _data_progress_row(data: Dictionary, fallback_name: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(V2.SURFACE_SOFT, V2.BORDER_SOFT, 6, Vector4(10.0, 7.0, 10.0, 7.0))
	)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)

	var species_name := String(data.get("species_name", fallback_name)).to_upper()
	var before := int(data.get("before", 0))
	var after := int(data.get("after", 0))
	var required := maxi(1, int(data.get("required", 100)))
	var gained := int(data.get("gained", after - before))
	var percent := int(round(minf(100.0, float(after) * 100.0 / float(required))))

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	stack.add_child(top)
	var name_label := _label("%s DATA" % species_name, 10, V2.CYAN, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var gain_label := _label("+%d" % gained, 10, V2.GREEN, true)
	top.add_child(gain_label)
	if bool(data.get("newly_ready", false)):
		var ready := _label("READY", 9, V2.GREEN, true)
		ready.add_theme_stylebox_override("normal", V2.pill_style(V2.GREEN, true))
		top.add_child(ready)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 7)
	stack.add_child(progress_row)
	var before_label := _label("%d / %d" % [before, required], 9, V2.MUTED)
	progress_row.add_child(before_label)
	var icon := TextureRect.new()
	icon.texture = CHANGE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.modulate = V2.CYAN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_row.add_child(icon)
	var after_label := _label("%d / %d  ·  %d%%" % [after, required, percent], 9, V2.TEXT, true)
	after_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(after_label)
	return panel


func _create_party_card(reward: Dictionary, accent: Color, rewards_enabled: bool) -> Dictionary:
	var card: Dictionary = super._create_party_card(reward, accent, rewards_enabled)
	_apply_retreat_status(card)
	return card


func _set_unlock_text(card: Dictionary) -> void:
	super._set_unlock_text(card)
	var reward := card.get("reward", {}) as Dictionary
	var label := card.get("unlocks") as Label
	if label == null or int(reward.get("levels_gained", 0)) <= 0:
		return
	var deltas = reward.get("stat_deltas", {})
	if not deltas is Dictionary:
		return
	var parts: Array[String] = []
	for stat_key: String in ["hp", "sp", "atk", "def", "int", "speed"]:
		var delta := int((deltas as Dictionary).get(stat_key, 0))
		if delta > 0:
			parts.append("%s +%d" % [stat_key.to_upper(), delta])
	if parts.is_empty():
		return
	var growth := "Stats: " + "  |  ".join(parts)
	label.text = growth if label.text.is_empty() else label.text + "\n" + growth


func _apply_final_state() -> void:
	super._apply_final_state()
	if _result_outcome() == "escaped":
		for card: Dictionary in _cards:
			_apply_retreat_status(card)


func _apply_retreat_status(card: Dictionary) -> void:
	if _result_outcome() != "escaped":
		return
	var gain := card.get("gain") as Label
	if gain == null:
		return
	gain.text = "Retreated safely"
	gain.add_theme_color_override("font_color", V2.CYAN)
