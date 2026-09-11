extends "res://src/MainCamera.gd"

const OPENING_BOOT_ZOOM := 0.94
const DESKTOP_BATTLE_ZOOM := 1.08
const LAPTOP_BATTLE_ZOOM := 1.00
const COMPACT_BATTLE_ZOOM := 1.02
const OPENING_ZOOM_TIME := 0.58

var _battle_default_zoom := DESKTOP_BATTLE_ZOOM


func _ready() -> void:
	super._ready()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * minf(OPENING_BOOT_ZOOM, _battle_default_zoom)


func animate_opening_overview(duration: float = OPENING_ZOOM_TIME) -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	var target_position := _overview_center_for_zoom(_battle_default_zoom)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", Vector2.ONE * _battle_default_zoom, maxf(0.05, duration))
	tween.tween_property(self, "global_position", target_position, maxf(0.05, duration))
	await tween.finished
	zoom = Vector2.ONE * _battle_default_zoom
	global_position = target_position
	_clamp_to_pan_bounds()


func reset_view() -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * _battle_default_zoom
	global_position = _overview_center_for_zoom(_battle_default_zoom)
	_clamp_to_pan_bounds()


func get_battle_default_zoom() -> float:
	return _battle_default_zoom


func _preferred_battle_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y < 560.0 or viewport_size.x < 1000.0:
		return COMPACT_BATTLE_ZOOM
	# Short landscape browser windows need a little more breathing room because
	# deployment can legitimately place Digimon on the first/last grid rows. A
	# 1.00 zoom is still noticeably closer than the old 0.90 opening, while
	# keeping those edge spawns readable instead of hiding them under browser/UI
	# chrome. Taller desktop screens can afford the more cinematic 1.08 framing.
	if viewport_size.y < 780.0:
		return LAPTOP_BATTLE_ZOOM
	return DESKTOP_BATTLE_ZOOM


func _overview_center_for_zoom(target_zoom: float) -> Vector2:
	if not _has_pan_bounds:
		return Vector2.ZERO
	var center := _pan_bounds.position + _pan_bounds.size * 0.5
	var viewport_size := get_viewport_rect().size
	# Desktop has a left command/actor rail and a much narrower turn-order strip
	# on the right. Shift the world slightly right on screen so the tactical board
	# is visually centered in the actually usable play area instead of the raw
	# browser rectangle. Compact/mobile layouts put commands at the bottom, so no
	# horizontal bias is needed there.
	if viewport_size.y >= 560.0 and viewport_size.x >= 1000.0:
		var left_reserved := minf(280.0, viewport_size.x * 0.21)
		var right_reserved := minf(112.0, viewport_size.x * 0.09)
		var screen_bias := (left_reserved - right_reserved) * 0.5
		center.x -= screen_bias / maxf(target_zoom, 0.01)
	return center
