extends "res://src/ui/ParallelBattleResultScreen.gd"
class_name RetreatAwareBattleResultScreen


func _create_party_card(reward: Dictionary, accent: Color, rewards_enabled: bool) -> Dictionary:
	var card: Dictionary = super._create_party_card(reward, accent, rewards_enabled)
	_apply_retreat_status(card)
	return card


func _apply_final_state() -> void:
	super._apply_final_state()
	if _result_outcome() != "escaped":
		return
	for card: Dictionary in _cards:
		_apply_retreat_status(card)


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
