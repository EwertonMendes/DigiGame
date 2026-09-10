extends "res://src/BattleHUD.gd"

const TurnOrderHUDScript = preload("res://src/TurnOrderHUD.gd")
const BattleTopBarScript = preload("res://src/ui/BattleTopBar.gd")

var _turn_order_hud: Control = null
var _top_bar: Control = null


func _ready() -> void:
	super._ready()
	_top_bar = BattleTopBarScript.new()
	_top_bar.name = "BattleTopBar"
	add_child(_top_bar)
	if _top_bar.has_method("setup"):
		_top_bar.call("setup", _controller)

	_turn_order_hud = TurnOrderHUDScript.new()
	_turn_order_hud.name = "TurnOrderHUD"
	add_child(_turn_order_hud)
	if _turn_order_hud.has_method("setup"):
		_turn_order_hud.call("setup", _controller)


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	if _top_bar != null and _top_bar.has_method("refresh"):
		_top_bar.call("refresh")
	if _turn_order_hud != null and _turn_order_hud.has_method("refresh"):
		_turn_order_hud.call("refresh")
