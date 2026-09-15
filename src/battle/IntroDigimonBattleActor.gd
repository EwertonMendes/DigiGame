extends "res://src/battle/DigimonBattleActor.gd"

const SPAWN_RISE := Vector2(0.0, 18.0)
const SPAWN_IN_TIME := 0.16
const SPAWN_SETTLE_TIME := 0.20

var _spawn_prepared := false
var _spawn_base_position := Vector2.ZERO
var _spawn_base_scale := Vector2.ONE


func prepare_battle_spawn() -> void:
	if sprite == null:
		return
	_spawn_prepared = true
	_spawn_base_position = sprite.position
	_spawn_base_scale = sprite.scale
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.position = _spawn_base_position + SPAWN_RISE
	sprite.scale = _spawn_base_scale * 0.36
	sprite.modulate = Color(0.72, 0.96, 1.0, 0.72) if is_player_controlled else Color(1.0, 0.62, 0.78, 0.72)


func play_battle_spawn_animation() -> void:
	if sprite == null:
		return
	if not _spawn_prepared:
		prepare_battle_spawn()

	var team_color := Color(0.28, 0.92, 1.0, 1.0) if is_player_controlled else Color(1.0, 0.30, 0.58, 1.0)
	_spawn_burst(team_color, 20, 104.0, 0.48, 1.65)
	_spawn_burst(Color(0.90, 0.98, 1.0, 1.0), 10, 68.0, 0.42, 1.1)
	_spawn_arrival_diamond(team_color)

	if OS.has_feature("web"):
		await _play_battle_spawn_frame_driven()
	else:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 1.0, SPAWN_IN_TIME)
		tween.parallel().tween_property(sprite, "position", _spawn_base_position + Vector2(0.0, -4.0), SPAWN_IN_TIME)
		tween.parallel().tween_property(sprite, "scale", _spawn_base_scale * 1.16, SPAWN_IN_TIME)
		tween.parallel().tween_property(sprite, "modulate", Color.WHITE, SPAWN_IN_TIME)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position", _spawn_base_position, SPAWN_SETTLE_TIME)
		tween.parallel().tween_property(sprite, "scale", _spawn_base_scale, SPAWN_SETTLE_TIME)
		await tween.finished

	modulate = Color.WHITE
	sprite.position = _spawn_base_position
	sprite.scale = _spawn_base_scale
	sprite.modulate = Color.WHITE
	_spawn_prepared = false
	print("[BattleIntro] SPAWN actor=%s team=%s" % [name, "player" if is_player_controlled else "enemy"])


func _play_battle_spawn_frame_driven() -> void:
	# Web battle startup already uses frame-driven camera presentation to avoid an
	# intermittent Wasm renderer failure. Keep the awaited actor reveal on the same
	# deterministic path so the opening cannot stall on Tween.finished while the
	# renderer is settling the newly-instantiated battle scene.
	var initial_position := _spawn_base_position + SPAWN_RISE
	var overshoot_position := _spawn_base_position + Vector2(0.0, -4.0)
	var initial_scale := _spawn_base_scale * 0.36
	var overshoot_scale := _spawn_base_scale * 1.16
	var initial_modulate := sprite.modulate
	var elapsed := 0.0

	while elapsed < SPAWN_IN_TIME:
		await get_tree().process_frame
		elapsed = minf(SPAWN_IN_TIME, elapsed + maxf(get_process_delta_time(), 0.0))
		var progress := _frame_ease(elapsed, SPAWN_IN_TIME, Tween.TRANS_EXPO, Tween.EASE_OUT)
		modulate.a = lerpf(0.0, 1.0, progress)
		sprite.position = initial_position.lerp(overshoot_position, progress)
		sprite.scale = initial_scale.lerp(overshoot_scale, progress)
		sprite.modulate = initial_modulate.lerp(Color.WHITE, progress)

	elapsed = 0.0
	while elapsed < SPAWN_SETTLE_TIME:
		await get_tree().process_frame
		elapsed = minf(SPAWN_SETTLE_TIME, elapsed + maxf(get_process_delta_time(), 0.0))
		var progress := _frame_ease(elapsed, SPAWN_SETTLE_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)
		sprite.position = overshoot_position.lerp(_spawn_base_position, progress)
		sprite.scale = overshoot_scale.lerp(_spawn_base_scale, progress)


func _frame_ease(elapsed: float, duration: float, transition: Tween.TransitionType, easing: Tween.EaseType) -> float:
	return float(Tween.interpolate_value(0.0, 1.0, elapsed, duration, transition, easing))


func play_battle_escape_animation() -> void:
	if sprite == null:
		visible = false
		return
	var base_position := sprite.position
	var base_scale := sprite.scale
	var escape_color := Color(0.24, 0.94, 1.0, 1.0)
	_spawn_burst(escape_color, 18, 92.0, 0.40, 1.4)
	_spawn_burst(Color(0.86, 0.98, 1.0, 1.0), 9, 58.0, 0.34, 1.0)
	_spawn_arrival_diamond(escape_color)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", base_scale * 0.28, 0.28)
	tween.tween_property(sprite, "position", base_position + Vector2(0.0, -18.0), 0.28)
	tween.tween_property(sprite, "modulate", Color(0.45, 0.96, 1.0, 0.18), 0.24)
	tween.tween_property(self, "modulate:a", 0.0, 0.28)
	await tween.finished
	visible = false
	sprite.position = base_position
	sprite.scale = base_scale
	sprite.modulate = Color.WHITE
	print("[BattleEscape] DESPAWN actor=%s" % name)


func play_battle_escape_failed_animation() -> void:
	if sprite == null:
		return
	var base_position := sprite.position
	var base_modulate := sprite.modulate
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for offset_x in [-4.0, 5.0, -3.0, 2.0, 0.0]:
		tween.tween_property(sprite, "position", base_position + Vector2(offset_x, 0.0), 0.045)
		tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.55, 0.58, 1.0) if offset_x != 0.0 else base_modulate, 0.045)
	await tween.finished
	sprite.position = base_position
	sprite.modulate = base_modulate


func _spawn_arrival_diamond(color: Color) -> void:
	var diamond := Line2D.new()
	diamond.name = "SpawnDiamond"
	diamond.points = PackedVector2Array([
		Vector2(-24.0, 0.0),
		Vector2(0.0, -12.0),
		Vector2(24.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(-24.0, 0.0),
	])
	diamond.width = 2.4
	diamond.default_color = color
	diamond.antialiased = true
	diamond.position = Vector2(0.0, -2.0)
	diamond.scale = Vector2.ONE * 0.42
	diamond.modulate.a = 0.9
	diamond.z_index = 65
	add_child(diamond)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(diamond, "scale", Vector2.ONE * 1.62, 0.42)
	tween.tween_property(diamond, "modulate:a", 0.0, 0.42)
	tween.finished.connect(diamond.queue_free)
