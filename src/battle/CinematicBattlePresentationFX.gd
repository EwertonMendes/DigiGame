extends "res://src/battle/SequencedBattlePresentationFX.gd"

# Final game-feel layer for combat. The base presentation still owns event
# sequencing and the Kenney textures; this subclass deliberately exaggerates
# anticipation and impact so attacks remain readable at the zoom levels used by
# the tactical board.

const IMPACT_RING_TIME := 0.30
const IMPACT_RAY_TIME := 0.22
const ATTACK_STREAK_TIME := 0.26
const SCREEN_FLASH_TIME := 0.16


func _spawn_melee_windup(attacker: Node, target: Node, color: Color, intensity: float) -> void:
	super._spawn_melee_windup(attacker, target, color, intensity)
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var direction: Vector2 = finish - start
	if direction.length_squared() < 1.0:
		return
	var midpoint: Vector2 = start.lerp(finish, 0.58)
	var angle: float = direction.angle()

	# The original 512px slash was previously rendered at roughly 50px and could
	# disappear visually against the board. This secondary arc is intentionally
	# much larger and persists through the lunge.
	_spawn_world_sprite(
		_slash_texture,
		midpoint,
		Color(color.r, color.g, color.b, 0.96),
		0.08,
		0.30 + intensity * 0.010,
		0.28,
		angle - 0.42,
		0.72
	)
	_spawn_directional_streak(start, finish, color, intensity, ATTACK_STREAK_TIME)
	_spawn_charge_ring(start, color, intensity, false)


func _spawn_charge_flash(attacker: Node, color: Color, intensity: float) -> void:
	super._spawn_charge_flash(attacker, color, intensity)
	var anchor: Vector2 = _actor_fx_anchor(attacker)
	_spawn_world_sprite(
		_muzzle_texture if _muzzle_texture != null else _flare_texture,
		anchor,
		Color(color.r, color.g, color.b, 0.96),
		0.06,
		0.22 + intensity * 0.009,
		0.24,
		0.0,
		0.34
	)
	_spawn_charge_ring(anchor, color, intensity, true)


func _spawn_projectile(
	attacker: Node,
	target: Node,
	color: Color,
	intensity: float,
	impact_delay: float
) -> void:
	super._spawn_projectile(attacker, target, color, intensity, impact_delay)
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var travel_time: float = maxf(PROJECTILE_MIN_TIME, impact_delay - RANGED_CHARGE_TIME)
	_spawn_directional_streak(start, finish, color, intensity * 0.82, travel_time + 0.08)

	# A larger luminous projectile sits on top of the compact base projectile.
	# It is built from the same committed local CC0 textures, so there is no new
	# runtime dependency.
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var projectile := Node2D.new()
	projectile.name = "CinematicTechniqueProjectileFX"
	projectile.global_position = start
	projectile.z_index = 97
	parent_node.add_child(projectile)

	if _magic_texture != null:
		var core := Sprite2D.new()
		core.texture = _magic_texture
		core.modulate = Color(color.r, color.g, color.b, 0.94)
		core.scale = Vector2.ONE * (0.10 + intensity * 0.004)
		core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		projectile.add_child(core)
	if _flare_texture != null:
		var glow := Sprite2D.new()
		glow.texture = _flare_texture
		glow.modulate = Color(1.0, 1.0, 1.0, 0.70)
		glow.scale = Vector2.ONE * (0.065 + intensity * 0.003)
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		projectile.add_child(glow)

	projectile.scale = Vector2.ONE * 0.35
	var tween: Tween = projectile.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(projectile, "scale", Vector2.ONE, RANGED_CHARGE_TIME)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "global_position", finish, travel_time)
	tween.parallel().tween_property(projectile, "rotation", TAU * 0.55, travel_time)
	tween.finished.connect(projectile.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_vfx(
	target: Node,
	color: Color,
	critical: bool,
	ranged: bool,
	intensity: float
) -> void:
	super._spawn_impact_vfx(target, color, critical, ranged, intensity)
	var anchor: Vector2 = _actor_fx_anchor(target)
	var impact_color: Color = Color(1.0, 0.92, 0.52, 1.0) if critical else color.lightened(0.18)

	# Big silhouette-breaking burst. At normal camera zoom this occupies roughly
	# 120-190px instead of being swallowed by a 32px character sprite.
	if ranged:
		_spawn_world_sprite(
			_magic_texture,
			anchor,
			Color(impact_color.r, impact_color.g, impact_color.b, 0.90),
			0.07,
			0.30 + intensity * 0.010,
			0.28,
			0.0,
			0.55
		)
	else:
		_spawn_world_sprite(
			_slash_texture,
			anchor,
			Color(impact_color.r, impact_color.g, impact_color.b, 1.0),
			0.08,
			0.34 + intensity * 0.012,
			0.30,
			-0.72,
			1.18
		)
		_spawn_world_sprite(
			_slash_texture,
			anchor,
			Color(1.0, 1.0, 1.0, 0.82),
			0.05,
			0.25 + intensity * 0.008,
			0.22,
			0.68,
			-0.88
		)

	_spawn_world_sprite(
		_spark_texture,
		anchor,
		Color.WHITE if critical else impact_color,
		0.06,
		0.25 + intensity * 0.010,
		0.25,
		0.0,
		1.10
	)
	_spawn_world_sprite(
		_flare_texture,
		anchor,
		Color(1.0, 0.96, 0.78, 0.94) if critical else Color(impact_color.r, impact_color.g, impact_color.b, 0.86),
		0.04,
		0.19 + intensity * 0.008,
		0.20,
		0.0,
		0.18
	)

	_spawn_impact_ring(anchor, impact_color, intensity, critical)
	_spawn_impact_rays(anchor, impact_color, intensity, critical)
	_spawn_screen_flash(impact_color, critical)


func _spawn_damage_text(target: Node, amount: int, critical: bool) -> void:
	var damage: int = maxi(0, amount)
	var text_value: String = "CRIT  %d" % damage if critical else "-%d" % damage
	var color: Color = Color(1.0, 0.84, 0.22, 1.0) if critical else Color(1.0, 0.98, 0.92, 1.0)
	_spawn_floating_text(target, text_value, color, 46 if critical else 38)


func _spawn_charge_ring(world_position: Vector2, color: Color, intensity: float, ranged: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ring: Line2D = _make_ring(15.0 + intensity * 1.4, 30, 3.0 + intensity * 0.30)
	ring.name = "AttackChargeRingFX"
	ring.global_position = world_position
	ring.default_color = Color(color.r, color.g, color.b, 0.80 if ranged else 0.62)
	ring.scale = Vector2.ONE * (1.25 if ranged else 0.75)
	ring.z_index = 96
	parent_node.add_child(ring)
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * (0.48 if ranged else 1.65), 0.24)
	tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	tween.finished.connect(ring.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_ring(world_position: Vector2, color: Color, intensity: float, critical: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ring: Line2D = _make_ring(
		18.0 + intensity * 1.8,
		36,
		(6.5 if critical else 5.0) + intensity * 0.32
	)
	ring.name = "ImpactRingFX"
	ring.global_position = world_position
	ring.default_color = Color(1.0, 0.98, 0.82, 1.0) if critical else Color(color.r, color.g, color.b, 0.96)
	ring.scale = Vector2.ONE * 0.40
	ring.z_index = 99
	parent_node.add_child(ring)
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * (2.65 if critical else 2.20), IMPACT_RING_TIME)
	tween.tween_property(ring, "width", 1.0, IMPACT_RING_TIME)
	tween.tween_property(ring, "modulate:a", 0.0, IMPACT_RING_TIME)
	tween.finished.connect(ring.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_rays(world_position: Vector2, color: Color, intensity: float, critical: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var ray_count: int = 6 if critical else 4
	var length: float = 30.0 + intensity * 4.6
	for index in range(ray_count):
		var angle: float = (TAU / float(ray_count)) * float(index) + 0.18
		var ray := Line2D.new()
		ray.name = "ImpactRayFX"
		ray.width = 5.5 if critical else 4.0
		ray.default_color = Color.WHITE if critical else Color(color.r, color.g, color.b, 0.96)
		ray.points = PackedVector2Array([
			Vector2.from_angle(angle) * 7.0,
			Vector2.from_angle(angle) * length,
		])
		ray.global_position = world_position
		ray.z_index = 100
		parent_node.add_child(ray)
		var tween: Tween = ray.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "scale", Vector2.ONE * 1.55, IMPACT_RAY_TIME)
		tween.tween_property(ray, "modulate:a", 0.0, IMPACT_RAY_TIME)
		tween.finished.connect(ray.queue_free, CONNECT_ONE_SHOT)


func _spawn_directional_streak(
	start: Vector2,
	finish: Vector2,
	color: Color,
	intensity: float,
	duration: float
) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var delta: Vector2 = finish - start
	if delta.length_squared() < 1.0:
		return
	var streak := Line2D.new()
	streak.name = "AttackStreakFX"
	streak.width = 3.5 + intensity * 0.42
	streak.default_color = Color(color.r, color.g, color.b, 0.76)
	streak.points = PackedVector2Array([
		Vector2.ZERO,
		delta * 0.72,
	])
	streak.global_position = start + delta * 0.12
	streak.z_index = 93
	parent_node.add_child(streak)
	var tween: Tween = streak.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(streak, "width", 0.8, duration)
	tween.tween_property(streak, "modulate:a", 0.0, duration)
	tween.finished.connect(streak.queue_free, CONNECT_ONE_SHOT)


func _spawn_screen_flash(color: Color, critical: bool) -> void:
	# Dedicated layer 89 keeps the flash over the battlefield but under the HUD,
	# so impact feels global without washing out tactical information.
	var flash_layer := CanvasLayer.new()
	flash_layer.name = "CombatImpactFlashLayer"
	flash_layer.layer = 89
	add_child(flash_layer)

	var flash := ColorRect.new()
	flash.name = "CombatImpactFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.96, 0.80, 0.20) if critical else Color(color.r, color.g, color.b, 0.13)
	flash.modulate.a = 0.0
	flash_layer.add_child(flash)

	var tween: Tween = flash.create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 1.0, 0.025)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(flash, "modulate:a", 0.0, SCREEN_FLASH_TIME - 0.025)
	tween.finished.connect(flash_layer.queue_free, CONNECT_ONE_SHOT)


func _make_ring(radius: float, segments: int, width: float) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.antialiased = true
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var angle: float = TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	return ring
