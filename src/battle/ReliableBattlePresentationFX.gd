extends "res://src/battle/BattlePresentationFX.gd"

# These are deliberately static dependencies. A missing combat texture must fail
# during Godot import/export instead of silently turning VFX into a no-op.
const VFX_SLASH = preload("res://assets/vfx/kenney/slash_03.png")
const VFX_SPARK = preload("res://assets/vfx/kenney/spark_04.png")
const VFX_MAGIC = preload("res://assets/vfx/kenney/magic_03.png")
const VFX_FLARE = preload("res://assets/vfx/kenney/flare_01.png")
const VFX_MUZZLE = preload("res://assets/vfx/kenney/muzzle_01.png")

const FX_LOG_PREFIX := "[CombatFX]"
const RING_SEGMENTS := 28
const WORLD_SPRITE_SCALE_BOOST := 1.55
const MIN_VISIBLE_FX_DURATION := 0.25


func _load_vfx_assets() -> void:
	_slash_texture = VFX_SLASH
	_spark_texture = VFX_SPARK
	_magic_texture = VFX_MAGIC
	_flare_texture = VFX_FLARE
	_muzzle_texture = VFX_MUZZLE


func _find_actor(event_id: String) -> Node:
	if event_id.is_empty() or _digimon_controller == null:
		return null
	for child in _digimon_controller.get_children():
		if not child is CharacterBody2D:
			continue
		if child.has_method("get_digimon_instance_id"):
			var stable_id: String = String(child.call("get_digimon_instance_id")).strip_edges()
			if not stable_id.is_empty() and stable_id == event_id:
				return child
		# Keep a fallback for old events/saves that still contain Godot's transient
		# Object instance id.
		if str(child.get_instance_id()) == event_id:
			return child
	return null


func _present_action_started(event: Dictionary) -> void:
	var actor_id := String(event.get("actor_id", ""))
	var target_id := String(event.get("target_id", ""))
	var attacker: Node = _find_actor(actor_id)
	var target: Node = _find_actor(target_id)
	if attacker == null or target == null:
		_impact_deadline_msec = Time.get_ticks_msec()
		push_error(
			"%s START could not resolve actor=%s target=%s" % [FX_LOG_PREFIX, actor_id, target_id]
		)
		return

	var profile: Dictionary = _current_action_profile(event)
	print(
		"%s START action=%s actor=%s target=%s ranged=%s" % [
			FX_LOG_PREFIX,
			String(profile.get("action_id", event.get("action_id", ""))),
			actor_id,
			target_id,
			str(bool(profile.get("ranged", false))),
		]
	)

	# Parent presentation owns the real Digimon lunge/cast and impact deadline.
	super._present_action_started(event)

	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	var intensity: float = float(profile.get("intensity", 4.0))
	if bool(profile.get("ranged", false)):
		_spawn_energy_trace(attacker, target, element_color, intensity, _impact_delay(attacker, target, true))
	else:
		_spawn_melee_speed_line(attacker, target, element_color, intensity)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	var target_id := String(event.get("target_id", ""))
	var target: Node = _find_actor(target_id)
	if target == null:
		push_error("%s IMPACT could not resolve target=%s" % [FX_LOG_PREFIX, target_id])
		return

	var critical: bool = bool(event.get("critical", false))
	var intensity: float = float(profile.get("intensity", 4.0)) * (1.25 if critical else 1.0)
	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	print(
		"%s IMPACT action=%s target=%s damage=%d critical=%s" % [
			FX_LOG_PREFIX,
			String(event.get("action_id", "")),
			target_id,
			int(event.get("damage", 0)),
			str(critical),
		]
	)

	super._present_damage(event, profile)
	_spawn_impact_ring(target, Color.WHITE if critical else element_color.lightened(0.22), intensity)
	_spawn_impact_cross(target, Color.WHITE if critical else element_color.lightened(0.34), intensity)


func _spawn_world_sprite(
	texture: Texture2D,
	world_position: Vector2,
	color: Color,
	start_scale: float,
	end_scale: float,
	duration: float,
	rotation_value: float,
	rotation_delta: float
) -> void:
	# The first version used correct textures but rendered them small and for only
	# a few frames. Keep the same art while making the attack readable at normal
	# tactical zoom.
	super._spawn_world_sprite(
		texture,
		world_position,
		color,
		start_scale * WORLD_SPRITE_SCALE_BOOST,
		end_scale * WORLD_SPRITE_SCALE_BOOST,
		maxf(duration, MIN_VISIBLE_FX_DURATION),
		rotation_value,
		rotation_delta
	)


func _spawn_melee_speed_line(attacker: Node, target: Node, color: Color, intensity: float) -> void:
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var direction := finish - start
	if direction.length_squared() < 1.0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var line := Line2D.new()
	line.name = "MeleeSpeedLineFX"
	line.width = 5.5 + intensity * 0.55
	line.default_color = Color(color.r, color.g, color.b, 0.82)
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(28.0, 0.0))
	line.global_position = start
	line.rotation = direction.angle()
	line.scale = Vector2(0.12, 0.65)
	line.z_index = 93
	line.antialiased = true
	parent_node.add_child(line)

	var final_x: float = maxf(1.0, direction.length() / 28.0)
	var tween := line.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "scale", Vector2(final_x, 1.0), 0.16)
	tween.tween_property(line, "modulate:a", 0.0, 0.23).set_delay(0.06)
	tween.finished.connect(line.queue_free, CONNECT_ONE_SHOT)


func _spawn_energy_trace(
	attacker: Node,
	target: Node,
	color: Color,
	intensity: float,
	impact_delay: float
) -> void:
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var direction := finish - start
	if direction.length_squared() < 1.0:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var line := Line2D.new()
	line.name = "TechniqueTrailFX"
	line.width = 3.5 + intensity * 0.35
	line.default_color = Color(color.r, color.g, color.b, 0.52)
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(24.0, 0.0))
	line.global_position = start
	line.rotation = direction.angle()
	line.scale = Vector2(0.05, 0.72)
	line.z_index = 91
	line.antialiased = true
	parent_node.add_child(line)

	var travel_time: float = maxf(PROJECTILE_MIN_TIME, impact_delay - RANGED_CHARGE_TIME)
	var final_x: float = maxf(1.0, direction.length() / 24.0)
	var tween := line.create_tween()
	tween.tween_interval(RANGED_CHARGE_TIME)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "scale", Vector2(final_x, 1.0), travel_time)
	tween.parallel().tween_property(line, "modulate:a", 0.12, travel_time)
	tween.tween_property(line, "modulate:a", 0.0, 0.10)
	tween.finished.connect(line.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_ring(target: Node, color: Color, intensity: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ring := Line2D.new()
	ring.name = "ImpactRingFX"
	ring.width = 3.0 + intensity * 0.24
	ring.default_color = Color(color.r, color.g, color.b, 0.94)
	ring.global_position = _actor_fx_anchor(target)
	ring.scale = Vector2.ONE * 0.24
	ring.z_index = 97
	ring.antialiased = true
	var radius: float = 24.0 + intensity * 2.7
	for index in range(RING_SEGMENTS + 1):
		var angle: float = TAU * float(index) / float(RING_SEGMENTS)
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	parent_node.add_child(ring)

	var tween := ring.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.20, 0.30)
	tween.tween_property(ring, "modulate:a", 0.0, 0.30).set_delay(0.04)
	tween.finished.connect(ring.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_cross(target: Node, color: Color, intensity: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var anchor: Vector2 = _actor_fx_anchor(target)
	var half_length: float = 20.0 + intensity * 1.8
	for rotation_value in [PI * 0.25, PI * 0.75]:
		var slash := Line2D.new()
		slash.name = "ImpactCrossFX"
		slash.width = 3.0 + intensity * 0.18
		slash.default_color = Color(color.r, color.g, color.b, 0.92)
		slash.add_point(Vector2(-half_length, 0.0))
		slash.add_point(Vector2(half_length, 0.0))
		slash.global_position = anchor
		slash.rotation = rotation_value
		slash.scale = Vector2.ONE * 0.45
		slash.z_index = 98
		slash.antialiased = true
		parent_node.add_child(slash)
		var tween := slash.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "scale", Vector2.ONE * 1.12, 0.18)
		tween.tween_property(slash, "modulate:a", 0.0, 0.24).set_delay(0.05)
		tween.finished.connect(slash.queue_free, CONNECT_ONE_SHOT)
