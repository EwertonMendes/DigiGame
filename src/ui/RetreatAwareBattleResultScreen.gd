extends "res://src/ui/ParallelBattleResultScreen.gd"
class_name RetreatAwareBattleResultScreen

const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")

var _data_rows: VBoxContainer = null

func _build_ui() -> void:
	super._build_ui()
	_content.add_theme_constant_override("separation", 8)
	_rebuild_reward_panel()

func _rebuild_reward_panel() -> void:
	if _reward_panel == null:
		return
	for child in _reward_panel.get_children():
		_reward_panel.remove_child(child)
		child.queue_free()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_reward_panel.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var reward_title := _label("REWARDS", 11, UI.MUTED, true)
	reward_title.custom_minimum_size = Vector2(84, 0)
	header.add_child(reward_title)
	_bits_value = _label("0 Bits", 15, UI.GOLD, true)
	_bits_value.custom_minimum_size = Vector2(130, 0)
	header.add_child(_bits_value)
	var data_title := _label("DIGI DATA", 10, UI.CYAN, true)
	data_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(data_title)
	_data_rows = VBoxContainer.new()
	_data_rows.add_theme_constant_override("separation", 3)
	root.add_child(_data_rows)
	_data_value = _label("", 11, UI.CYAN)
	_data_value.visible = false
	root.add_child(_data_value)

func _rebuild() -> void:
	super._rebuild()
	if _result_outcome() == "victory":
		_render_digi_data_progress()
	else:
		_render_no_data("No rewards recovered.")

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
	if _result_outcome() == "victory":
		_render_digi_data_progress()
	if _result_outcome() == "escaped":
		for card: Dictionary in _cards:
			_apply_retreat_status(card)

func _apply_digi_data_progress_copy() -> void:
	_render_digi_data_progress()

func _render_digi_data_progress() -> void:
	if _data_rows == null:
		return
	_clear_data_rows()
	var progress = _result.get("digi_data_progress", {})
	if progress is Dictionary and not progress.is_empty():
		for raw_seed in progress.keys():
			var entry = progress[raw_seed]
			if entry is Dictionary:
				_data_rows.add_child(_data_progress_row(entry as Dictionary, String(raw_seed)))
		return
	var digi_data = _result.get("digi_data", {})
	if digi_data is Dictionary and not digi_data.is_empty():
		for species_name in digi_data.keys():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var name_label := _label("%s DATA" % String(species_name).to_upper(), 10, UI.CYAN, true)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			row.add_child(_label("+%d" % int(digi_data[species_name]), 11, UI.GREEN, true))
			_data_rows.add_child(row)
		return
	_render_no_data("No Digi Data recovered.")

func _data_progress_row(data: Dictionary, fallback_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var species_name := String(data.get("species_name", fallback_name)).to_upper()
	var before := int(data.get("before", 0))
	var after := int(data.get("after", 0))
	var required := maxi(1, int(data.get("required", 100)))
	var gained := int(data.get("gained", after - before))
	var percent := int(round(minf(100.0, float(after) * 100.0 / float(required))))
	var name_label := _label("%s DATA" % species_name, 10, UI.CYAN, true)
	name_label.custom_minimum_size.x = 150
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var gain_label := _label("+%d" % gained, 10, UI.GREEN, true)
	gain_label.custom_minimum_size.x = 46
	row.add_child(gain_label)
	var before_label := _label("%d / %d" % [before, required], 10, UI.MUTED)
	before_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	before_label.custom_minimum_size.x = 76
	row.add_child(before_label)
	var icon := TextureRect.new()
	icon.texture = CHANGE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(20, 20)
	icon.modulate = UI.CYAN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var after_label := _label("%d / %d  %d%%" % [after, required, percent], 10, UI.TEXT, true)
	after_label.custom_minimum_size.x = 112
	row.add_child(after_label)
	if bool(data.get("newly_ready", false)):
		var ready := _label("READY", 9, UI.GREEN, true)
		ready.custom_minimum_size.x = 48
		row.add_child(ready)
	return row

func _render_no_data(message: String) -> void:
	if _data_rows == null:
		return
	_clear_data_rows()
	_data_rows.add_child(_label(message, 10, UI.MUTED))

func _clear_data_rows() -> void:
	for child in _data_rows.get_children():
		_data_rows.remove_child(child)
		child.queue_free()

func _apply_retreat_status(card: Dictionary) -> void:
	if _result_outcome() != "escaped":
		return
	var gain := card.get("gain") as Label
	if gain == null:
		return
	gain.text = "Retreated safely"
	gain.add_theme_color_override("font_color", UI.CYAN)

func _finish_animation() -> void:
	super._finish_animation()
	_continue_button.text = "RETURN TO COMMONS"

func _layout() -> void:
	super._layout()
	if _shell == null:
		return
	var viewport := get_viewport()
	var physical := UI.physical_window_size(viewport)
	var scale_factor := UI.ui_scale(viewport)
	var portrait_mobile := physical.x < 620.0 and physical.y > physical.x
	var compact := UI.is_compact(viewport, 880.0)
	var edge := 12.0 if compact else 20.0
	var target_width := minf(1120.0, physical.x - edge * 2.0)
	var target_height := minf(620.0, physical.y - edge * 2.0)
	if portrait_mobile:
		target_width = physical.x - 12.0
		target_height = physical.y - 12.0
	_shell.scale = Vector2.ONE * scale_factor
	_shell.position = Vector2((physical.x - target_width) * 0.5 * scale_factor, (physical.y - target_height) * 0.5 * scale_factor)
	_shell.size = Vector2(target_width, target_height)
	_party_grid.columns = 1 if portrait_mobile else 3
	_party_scroll.custom_minimum_size = Vector2(0, minf(270.0, target_height * 0.43) if portrait_mobile else (166.0 if compact else 178.0))
	_reward_panel.custom_minimum_size = Vector2(0, 84.0)
	_continue_button.custom_minimum_size = Vector2(0, 44.0)
	_title.add_theme_font_size_override("font_size", 28 if compact else 34)
	for card: Dictionary in _cards:
		var panel := card.get("panel") as Control
		if panel != null:
			panel.custom_minimum_size = Vector2(0, 126.0 if compact else 136.0)

func _result_outcome() -> String:
	return String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))
