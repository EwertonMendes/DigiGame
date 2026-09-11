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
