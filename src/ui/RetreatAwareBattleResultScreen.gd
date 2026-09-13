extends "res://src/ui/ParallelBattleResultScreen.gd"
class_name RetreatAwareBattleResultScreen


func _rebuild() -> void:
	super._rebuild()
	if _result_outcome() == "victory":
		_apply_digi_data_progress_copy()


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
	var growth := "Stats: " + "  ·  ".join(parts)
	label.text = growth if label.text.is_empty() else label.text + "\n" + growth


func _apply_final_state() -> void:
	super._apply_final_state()
	if _result_outcome() == "victory":
		_apply_digi_data_progress_copy()
	if _result_outcome() != "escaped":
		return
	for card: Dictionary in _cards:
		_apply_retreat_status(card)


func _apply_digi_data_progress_copy() -> void:
	if _data_value == null:
		return
	var progress = _result.get("digi_data_progress", {})
	if not progress is Dictionary or progress.is_empty():
		return
	var parts: Array[String] = []
	for raw_seed in progress.keys():
		var entry = progress[raw_seed]
		if not entry is Dictionary:
			continue
		var data := entry as Dictionary
		var species_name := String(data.get("species_name", raw_seed))
		var before := int(data.get("before", 0))
		var after := int(data.get("after", 0))
		var required := maxi(1, int(data.get("required", 100)))
		var gained := int(data.get("gained", after - before))
		var text := "%s Data +%d  ·  %d → %d / %d (%d%%)" % [species_name, gained, before, after, required, int(round(minf(100.0, float(after) * 100.0 / float(required))))]
		if bool(data.get("newly_ready", false)):
			text += "  ·  CREATE READY"
		parts.append(text)
	if not parts.is_empty():
		_data_value.text = "\n".join(parts)


func _apply_retreat_status(card: Dictionary) -> void:
	if _result_outcome() != "escaped":
		return
	var gain := card.get("gain") as Label
	if gain == null:
		return
	gain.text = "Retreated safely"
	gain.add_theme_color_override("font_color", UI.CYAN)


func _result_outcome() -> String:
	return String(_result.get("outcome", "victory" if bool(_result.get("victory", false)) else "defeat"))
