extends "res://src/BattleHUD.gd"


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	if _controller == null or not _controller.has_method("get_hud_state") or _turn_label == null:
		return
	var state: Dictionary = _controller.call("get_hud_state")
	var actor_name := String(state.get("actor_name", ""))
	if actor_name.is_empty():
		return
	var level := int(state.get("level", 1))
	_turn_label.text = "%s  //  LV %d" % [actor_name.to_upper(), level]


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if raw_phase == "Preview movement":
		return "Point to preview • click/tap to lock • drag to trace"
	return super._phase_copy(state)
