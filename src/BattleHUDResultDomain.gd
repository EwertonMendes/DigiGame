extends "res://src/BattleHUDDomain.gd"

const BattleResultScreenScript = preload("res://src/ui/RetreatAwareBattleResultScreen.gd")

var _battle_result_screen: BattleResultScreen = null
var _post_battle_locked := false

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
	var battle_over := bool(state.get("battle_over", false))
	_set_post_battle_controls_locked(battle_over)
	if battle_over:
		var result = state.get("battle_result", {})
		if result is Dictionary:
			_battle_result_screen.show_result(result as Dictionary)
	else:
		_battle_result_screen.hide_result()

func _set_post_battle_controls_locked(locked: bool) -> void:
	if _post_battle_locked == locked:
		return
	_post_battle_locked = locked
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var debug_root := main.get_node_or_null("DebugUI/Root") as Control
	if debug_root != null:
		debug_root.visible = not locked
	var info_layer := main.get_node_or_null("DigimonInfoUI") as CanvasLayer
	if info_layer != null:
		info_layer.visible = not locked

func _on_result_return_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/world/hub.tscn")
