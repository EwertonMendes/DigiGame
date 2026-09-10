extends "res://src/battle/BattlePresentationFX.gd"

const KO_SMOKE_PATH := "res://assets/vfx/kenney/smoke_03.png"
const KO_FLASH_DURATION := 0.34

var _ko_smoke_texture: Texture2D = null
var _sequenced_events_seen := 0


func _ready() -> void:
	super._ready()
	_ko_smoke_texture = _load_texture(KO_SMOKE_PATH)

	# Register an explicit runtime handler owned by this class. This avoids the
	# inherited method-reference connection silently missing exported combat FX.
	if _battle_controller != null and _battle_controller.has_signal("combat_event"):
		var inherited_handler := Callable(self, "_on_combat_event")
		if _battle_controller.is_connected("combat_event", inherited_handler):
			_battle_controller.disconnect("combat_event", inherited_handler)
		var sequenced_handler := Callable(self, "_on_sequenced_combat_event")
		if not _battle_controller.is_connected("combat_event", sequenced_handler):
			_battle_controller.connect("combat_event", sequenced_handler)


func _on_sequenced_combat_event(event: Dictionary) -> void:
	_sequenced_events_seen += 1
	match String(event.get("type", "")):
		"action_started":
			_present_action_started(event)
		"damage_applied":
			var profile: Dictionary = _current_action_profile(event)
			_present_damage(event, profile)
		"action_missed":
			_present_miss(event)
		"unit_knocked_out":
			_schedule_after_impact(
				Callable(self, "_present_knockout").bind(event.duplicate(true)),
				0.20
			)


func wait_for_current_impact() -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout


func _find_actor(event_id: String) -> Node:
	if event_id.is_empty() or _digimon_controller == null:
		return null
	for child in _digimon_controller.get_children():
		if not child is CharacterBody2D:
			continue
		if child.has_method("get_digimon_instance_id"):
			var persistent_id: String = String(child.call("get_digimon_instance_id"))
			if persistent_id == event_id:
				return child
		if str(child.get_instance_id()) == event_id:
			return child
	return null


func _present_knockout(event: Dictionary) -> void:
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target == null or not is_instance_valid(target):
		return

	var anchor: Vector2 = _actor_fx_anchor(target)
	var defeat_color: Color = (
		Color(0.30, 0.92, 1.0, 1.0)
		if bool(target.get("is_player_controlled"))
		else Color(1.0, 0.34, 0.45, 1.0)
	)

	if _ko_smoke_texture != null:
		_spawn_world_sprite(
			_ko_smoke_texture,
			anchor + Vector2(-8.0, 3.0),
			Color(defeat_color.r, defeat_color.g, defeat_color.b, 0.78),
			0.055,
			0.16,
			KO_FLASH_DURATION,
			-0.12,
			0.28
		)
		_spawn_world_sprite(
			_ko_smoke_texture,
			anchor + Vector2(10.0, -5.0),
			Color(0.88, 0.96, 1.0, 0.68),
			0.04,
			0.13,
			KO_FLASH_DURATION + 0.08,
			0.20,
			-0.22
		)
	if _flare_texture != null:
		_spawn_world_sprite(
			_flare_texture,
			anchor,
			Color(1.0, 0.96, 0.82, 0.92),
			0.028,
			0.14,
			0.24,
			0.0,
			0.0
		)
	if _spark_texture != null:
		_spawn_world_sprite(
			_spark_texture,
			anchor,
			defeat_color.lightened(0.22),
			0.03,
			0.15,
			0.28,
			-0.35,
			0.85
		)

	_shake_camera(6.0, 0.26)
	if target.has_method("play_knockout_animation"):
		target.call("play_knockout_animation")
