extends "res://src/battle/CinematicBattlePresentationFX.gd"

const PRESENTATION_LIBRARY_SCRIPT = preload("res://src/battle/CombatPresentationLibrary.gd")
const PRESENTATION_LOG_PREFIX := "[CombatPresentation]"

var _presentation_library: Node = null


func _ready() -> void:
	_presentation_library = PRESENTATION_LIBRARY_SCRIPT.new()
	_presentation_library.name = "CombatPresentationLibrary"
	add_child(_presentation_library)
	if not bool(_presentation_library.call("load_default")):
		push_error("%s failed to load presentation databases" % PRESENTATION_LOG_PREFIX)
	super._ready()


func _on_combat_event(event: Dictionary) -> void:
	super._on_combat_event(event)
	if String(event.get("type", "")) != "status_applied" or _presentation_library == null:
		return
	var profile: Dictionary = _current_action_profile(event)
	var presentation: Dictionary = _presentation_for_profile(profile)
	if presentation.is_empty() or String(_presentation_library.call("resolve_on", presentation)) != "status":
		return
	_schedule_after_impact(
		Callable(self, "_present_status_resolution").bind(
			event.duplicate(true),
			profile.duplicate(true),
			presentation.duplicate(true)
		),
		0.0
	)


func _present_action_started(event: Dictionary) -> void:
	var profile: Dictionary = _current_action_profile(event)
	var presentation: Dictionary = _presentation_for_profile(profile)
	var attacker: Node = _find_actor(String(event.get("actor_id", "")))
	var target: Node = _find_actor(String(event.get("target_id", "")))

	super._present_action_started(event)

	if _presentation_library == null or presentation.is_empty() or attacker == null or target == null:
		return
	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	var action_id := String(profile.get("action_id", event.get("action_id", "")))
	var start_count: int = int(_presentation_library.call(
		"play_phase",
		"start",
		presentation,
		attacker,
		target,
		element_color,
		0.0
	))
	var audio_started: bool = bool(_presentation_library.call("play_audio_phase", presentation, "start", action_id != "basic_attack"))
	var projectile_count := 0
	if bool(profile.get("ranged", false)):
		var impact_delay: float = _impact_delay(attacker, target, true)
		var travel_time: float = maxf(PROJECTILE_MIN_TIME, impact_delay - RANGED_CHARGE_TIME)
		var projectile_specs = presentation.get("projectile", [])
		if projectile_specs is Array:
			projectile_count = projectile_specs.size()
		if projectile_count > 0:
			get_tree().create_timer(RANGED_CHARGE_TIME).timeout.connect(
				Callable(_presentation_library, "play_phase").bind(
					"projectile",
					presentation.duplicate(true),
					attacker,
					target,
					element_color,
					travel_time
				),
				CONNECT_ONE_SHOT
			)
	print(
		"%s phase=start action=%s start_fx=%d projectile_fx=%d audio=%s" % [
			PRESENTATION_LOG_PREFIX,
			action_id,
			start_count,
			projectile_count,
			str(audio_started),
		]
	)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	super._present_damage(event, profile)
	var presentation: Dictionary = _presentation_for_profile(profile)
	if _presentation_library == null or presentation.is_empty():
		return
	if String(_presentation_library.call("resolve_on", presentation)) != "damage":
		return
	var attacker: Node = _find_actor(String(event.get("actor_id", "")))
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target == null:
		return
	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	var impact_count: int = int(_presentation_library.call(
		"play_phase",
		"impact",
		presentation,
		attacker,
		target,
		element_color,
		0.0
	))
	var action_id := String(profile.get("action_id", event.get("action_id", "")))
	var audio_started: bool = bool(_presentation_library.call("play_audio_phase", presentation, "impact", action_id != "basic_attack"))
	print(
		"%s phase=impact action=%s trigger=damage fx=%d audio=%s" % [
			PRESENTATION_LOG_PREFIX,
			action_id,
			impact_count,
			str(audio_started),
		]
	)


func _present_status_resolution(event: Dictionary, profile: Dictionary, presentation: Dictionary) -> void:
	if _presentation_library == null:
		return
	var attacker: Node = _find_actor(String(event.get("actor_id", "")))
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target == null:
		return
	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	var impact_count: int = int(_presentation_library.call(
		"play_phase",
		"impact",
		presentation,
		attacker,
		target,
		element_color,
		0.0
	))
	var action_id := String(profile.get("action_id", ""))
	var audio_started: bool = bool(_presentation_library.call("play_audio_phase", presentation, "impact", true))
	print(
		"%s phase=impact action=%s trigger=status fx=%d audio=%s" % [
			PRESENTATION_LOG_PREFIX,
			action_id,
			impact_count,
			str(audio_started),
		]
	)


func _presentation_for_profile(profile: Dictionary) -> Dictionary:
	if _presentation_library == null:
		return {}
	return _presentation_library.call(
		"get_presentation",
		String(profile.get("action_id", "")),
		String(profile.get("element", "neutral"))
	) as Dictionary
