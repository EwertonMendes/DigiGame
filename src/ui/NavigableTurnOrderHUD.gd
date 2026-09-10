extends "res://src/TurnOrderHUD.gd"
class_name NavigableTurnOrderHUD

const NavUI = preload("res://src/ui/TacticalTheme.gd")

var _keyboard_navigation_active := false
var _keyboard_index := 0


func refresh() -> void:
	var restore_navigation := _keyboard_navigation_active
	var restore_index := _keyboard_index
	super.refresh()
	if restore_navigation:
		_keyboard_index = restore_index
		call_deferred("_restore_keyboard_navigation")


func enter_keyboard_navigation() -> bool:
	var nodes := _turn_nodes()
	if nodes.is_empty():
		return false
	_keyboard_navigation_active = true
	_keyboard_index = clampi(_keyboard_index, 0, nodes.size() - 1)
	_set_keyboard_focus_enabled(true)
	_focus_keyboard_index()
	return true


func exit_keyboard_navigation() -> void:
	_keyboard_navigation_active = false
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and _is_turn_node(owner):
		owner.release_focus()
	_set_keyboard_focus_enabled(false)


func is_keyboard_navigation_active() -> bool:
	return _keyboard_navigation_active


func navigate_keyboard(step: int) -> bool:
	if not _keyboard_navigation_active:
		return false
	var nodes := _turn_nodes()
	if nodes.is_empty():
		return false
	_keyboard_index = posmod(_keyboard_index + step, nodes.size())
	_focus_keyboard_index()
	return true


func activate_keyboard_selection() -> bool:
	if not _keyboard_navigation_active:
		return false
	var nodes := _turn_nodes()
	if nodes.is_empty():
		return false
	_keyboard_index = clampi(_keyboard_index, 0, nodes.size() - 1)
	var card := nodes[_keyboard_index]
	card.emit_signal("pressed")
	return true


func _restore_keyboard_navigation() -> void:
	if not _keyboard_navigation_active:
		return
	var nodes := _turn_nodes()
	if nodes.is_empty():
		_keyboard_navigation_active = false
		return
	_keyboard_index = clampi(_keyboard_index, 0, nodes.size() - 1)
	_set_keyboard_focus_enabled(true)
	_focus_keyboard_index()


func _turn_nodes() -> Array[Button]:
	var result: Array[Button] = []
	if _cards == null:
		return result
	for child: Node in _cards.get_children():
		if child is Button and not child.is_queued_for_deletion():
			result.append(child as Button)
	return result


func _set_keyboard_focus_enabled(enabled: bool) -> void:
	for card: Button in _turn_nodes():
		card.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		if enabled:
			card.add_theme_stylebox_override("focus", NavUI.focus_outline(NavUI.GOLD, 12))
			_hook_focus_animation(card)


func _hook_focus_animation(card: Button) -> void:
	var entered := Callable(self, "_on_keyboard_focus_entered").bind(card)
	var exited := Callable(self, "_on_keyboard_focus_exited").bind(card)
	var mouse_exited := Callable(self, "_on_keyboard_mouse_exited").bind(card)
	if not card.focus_entered.is_connected(entered):
		card.focus_entered.connect(entered)
	if not card.focus_exited.is_connected(exited):
		card.focus_exited.connect(exited)
	if not card.mouse_exited.is_connected(mouse_exited):
		card.mouse_exited.connect(mouse_exited)


func _focus_keyboard_index() -> void:
	var nodes := _turn_nodes()
	if nodes.is_empty():
		return
	_keyboard_index = clampi(_keyboard_index, 0, nodes.size() - 1)
	var card := nodes[_keyboard_index]
	card.grab_focus()
	_animate_card_scale(card, Vector2(1.07, 1.07))


func _on_keyboard_focus_entered(card: Button) -> void:
	var nodes := _turn_nodes()
	var index := nodes.find(card)
	if index >= 0:
		_keyboard_index = index
	_animate_card_scale(card, Vector2(1.07, 1.07))


func _on_keyboard_focus_exited(card: Button) -> void:
	_animate_card_scale(card, Vector2.ONE)


func _on_keyboard_mouse_exited(card: Button) -> void:
	if _keyboard_navigation_active and get_viewport().gui_get_focus_owner() == card:
		_animate_card_scale(card, Vector2(1.07, 1.07))


func _is_turn_node(control: Control) -> bool:
	for card: Button in _turn_nodes():
		if card == control:
			return true
	return false
