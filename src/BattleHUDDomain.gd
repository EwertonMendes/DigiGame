extends "res://src/BattleHUD.gd"

const TurnOrderHUDScript = preload("res://src/TurnOrderHUD.gd")

var _turn_order_hud: Control = null


func _ready() -> void:
	super._ready()
	_turn_order_hud = TurnOrderHUDScript.new()
	_turn_order_hud.name = "TurnOrderHUD"
	add_child(_turn_order_hud)
	if _turn_order_hud.has_method("setup"):
		_turn_order_hud.call("setup", _controller)


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	if _controller == null or not _controller.has_method("get_hud_state") or _turn_label == null:
		return
	var state: Dictionary = _controller.call("get_hud_state")
	var actor_name := String(state.get("actor_name", ""))
	if not actor_name.is_empty():
		var level := int(state.get("level", 1))
		var speed := int(state.get("speed", 1))
		_turn_label.text = "%s  //  LV %d" % [actor_name.to_upper(), level]
		_turn_label.tooltip_text = "Battle Speed: %d" % speed
	if _turn_order_hud != null and _turn_order_hud.has_method("refresh"):
		_turn_order_hud.call("refresh")


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if raw_phase == "Preview movement":
		return "Point to preview • click/tap to lock • drag to trace"
	return super._phase_copy(state)
