extends "res://src/BattleHUDDomain.gd"

const BattleResultScreenScript = preload("res://src/ui/RetreatAwareBattleResultScreen.gd")

var _battle_result_screen: BattleResultScreen = null


func _ready() -> void:
	super._ready()
	_battle_result_screen = BattleResultScreenScript.new() as BattleResultScreen
	_battle_result_screen.name = "BattleResultScreen"
	add_child(_battle_result_screen)
	_battle_result_screen.return_requested.connect(_on_result_return_requested)
	refresh_from_controller()


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	if _battle_result_screen == null or _controller == null or not _controller.has_method("get_hud_state"):
		return
	var state: Dictionary = _controller.call("get_hud_state")
	if bool(state.get("battle_over", false)):
		var result = state.get("battle_result", {})
		if result is Dictionary:
			_battle_result_screen.show_result(result as Dictionary)
	else:
		_battle_result_screen.hide_result()


func _on_result_return_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/world/hub.tscn")
