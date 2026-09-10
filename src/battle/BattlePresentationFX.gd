extends Node
class_name BattlePresentationFX

var _battle_controller: Node = null
var _digimon_controller: Node = null


func _ready() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	_battle_controller = main.get_node_or_null("BattleController")
	_digimon_controller = main.get_node_or_null("DigimonController")
	if _battle_controller != null and _battle_controller.has_signal("combat_event"):
		_battle_controller.connect("combat_event", _on_combat_event)


func _on_combat_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"action_started":
			_present_action_started(event)
		"damage_applied":
			var profile := _current_action_profile(event)
			_present_damage_delayed(event.duplicate(true), profile)
		"action_missed":
			_present_miss_delayed(event.duplicate(true))
		"unit_knocked_out":
			_present_knockout_delayed(event.duplicate(true))


func _present_action_started(event: Dictionary) -> void:
	var attacker := _find_actor(String(event.get("actor_id", "")))
	var target := _find_actor(String(event.get("target_id", "")))
	if attacker == null or target == null or not attacker.has_method("play_attack_animation"):
		return
	var profile := _current_action_profile(event)
	attacker.call(
		"play_attack_animation",
		target,
		float(profile.get("intensity", 4.0)),
		bool(profile.get("ranged", false))
	)


func _present_damage_delayed(event: Dictionary, profile: Dictionary) -> void:
	await get_tree().create_timer(0.075).timeout
	var attacker := _find_actor(String(event.get("actor_id", "")))
	var target := _find_actor(String(event.get("target_id", "")))
	if target == null:
		return
	var critical := bool(event.get("critical", false))
	var intensity := float(profile.get("intensity", 4.0)) * (1.22 if critical else 1.0)
	if target.has_method("play_hit_reaction"):
		target.call("play_hit_reaction", attacker, intensity)
	if target.has_method("show_damage_number"):
		target.call("show_damage_number", int(event.get("damage", 0)), critical)
	if target.has_method("emit_hit_particles"):
		target.call(
			"emit_hit_particles",
			_element_color(String(profile.get("element", "neutral"))),
			critical,
			intensity
		)
	_shake_camera(intensity, 0.16 + intensity * 0.018)


func _present_miss_delayed(event: Dictionary) -> void:
	await get_tree().create_timer(0.10).timeout
	var target := _find_actor(String(event.get("target_id", "")))
	if target != null and target.has_method("show_miss_feedback"):
		target.call("show_miss_feedback")


func _present_knockout_delayed(event: Dictionary) -> void:
	await get_tree().create_timer(0.20).timeout
	var target := _find_actor(String(event.get("target_id", "")))
	if target != null and target.has_method("play_knockout_animation"):
		target.call("play_knockout_animation")


func _current_action_profile(event: Dictionary) -> Dictionary:
	var action: Dictionary = {}
	if _battle_controller != null and _battle_controller.has_method("get_selected_action"):
		var raw_action = _battle_controller.call("get_selected_action")
		if raw_action is Dictionary:
			action = raw_action
	var power := maxi(1, int(action.get("power", 28)))
	var intensity := clampf(2.5 + float(power) / 18.0, 3.2, 6.5)
	var range_data = action.get("range", {})
	var max_range := 1
	if range_data is Dictionary:
		max_range = int(range_data.get("max", 1))
	return {
		"action_id": String(event.get("action_id", action.get("id", ""))),
		"element": String(action.get("element", "neutral")),
		"intensity": intensity,
		"ranged": max_range > 1,
	}


func _find_actor(event_id: String) -> Node:
	if event_id.is_empty() or _digimon_controller == null:
		return null
	for child in _digimon_controller.get_children():
		if not child is CharacterBody2D:
			continue
		if str(child.get_instance_id()) == event_id:
			return child
	return null


func _shake_camera(intensity: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", clampf(intensity, 2.5, 8.0), clampf(duration, 0.14, 0.32))


func _element_color(element: String) -> Color:
	match element.to_lower():
		"fire": return Color(1.0, 0.36, 0.16, 1.0)
		"water": return Color(0.20, 0.72, 1.0, 1.0)
		"plant": return Color(0.30, 1.0, 0.48, 1.0)
		"electric": return Color(1.0, 0.90, 0.20, 1.0)
		"wind": return Color(0.64, 1.0, 0.88, 1.0)
		"earth": return Color(0.78, 0.55, 0.28, 1.0)
		"light": return Color(1.0, 0.96, 0.72, 1.0)
		"dark": return Color(0.72, 0.35, 1.0, 1.0)
	return Color(0.38, 0.90, 1.0, 1.0)
