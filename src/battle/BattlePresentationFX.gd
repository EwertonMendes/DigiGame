extends Node
class_name BattlePresentationFX

const VFX_ROOT := "res://assets/vfx/kenney"
const MELEE_IMPACT_DELAY := 0.22
const RANGED_CHARGE_TIME := 0.10
const PROJECTILE_MIN_TIME := 0.18
const PROJECTILE_MAX_TIME := 0.34
const FLOATING_TEXT_DURATION := 0.78
const FLOATING_TEXT_RISE := 46.0

var _battle_controller: Node = null
var _digimon_controller: Node = null
var _impact_deadline_msec: int = 0
var _floating_entries: Array[Dictionary] = []
var _overlay_layer: CanvasLayer = null
var _overlay_root: Control = null

var _slash_texture: Texture2D = null
var _spark_texture: Texture2D = null
var _magic_texture: Texture2D = null
var _flare_texture: Texture2D = null
var _muzzle_texture: Texture2D = null


func _ready() -> void:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	_battle_controller = main.get_node_or_null("BattleController")
	_digimon_controller = main.get_node_or_null("DigimonController")
	_build_screen_overlay()
	_load_vfx_assets()
	if _battle_controller != null and _battle_controller.has_signal("combat_event"):
		_battle_controller.connect("combat_event", _on_combat_event)
	set_process(true)


func _process(delta: float) -> void:
	_update_floating_text(delta)


func _on_combat_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"action_started":
			_present_action_started(event)
		"damage_applied":
			var profile: Dictionary = _current_action_profile(event)
			_schedule_after_impact(
				Callable(self, "_present_damage").bind(event.duplicate(true), profile),
				0.0
			)
		"action_missed":
			_schedule_after_impact(
				Callable(self, "_present_miss").bind(event.duplicate(true)),
				0.0
			)
		"unit_knocked_out":
			_schedule_after_impact(
				Callable(self, "_present_knockout").bind(event.duplicate(true)),
				0.20
			)


func _present_action_started(event: Dictionary) -> void:
	var attacker: Node = _find_actor(String(event.get("actor_id", "")))
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if attacker == null or target == null:
		_impact_deadline_msec = Time.get_ticks_msec()
		return

	var profile: Dictionary = _current_action_profile(event)
	var ranged: bool = bool(profile.get("ranged", false))
	var intensity: float = float(profile.get("intensity", 4.0))
	var impact_delay: float = _impact_delay(attacker, target, ranged)
	_impact_deadline_msec = Time.get_ticks_msec() + int(round(impact_delay * 1000.0))

	if attacker.has_method("play_attack_animation"):
		attacker.call("play_attack_animation", target, intensity, ranged)

	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	if ranged:
		_spawn_charge_flash(attacker, element_color, intensity)
		_spawn_projectile(attacker, target, element_color, intensity, impact_delay)
	else:
		_spawn_melee_windup(attacker, target, element_color, intensity)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	var attacker: Node = _find_actor(String(event.get("actor_id", "")))
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target == null:
		return

	var critical: bool = bool(event.get("critical", false))
	var intensity: float = float(profile.get("intensity", 4.0)) * (1.25 if critical else 1.0)
	var element_color: Color = _element_color(String(profile.get("element", "neutral")))
	if target.has_method("play_hit_reaction"):
		target.call("play_hit_reaction", attacker, intensity)
	if target.has_method("emit_hit_particles"):
		target.call("emit_hit_particles", element_color, critical, intensity)

	_spawn_impact_vfx(target, element_color, critical, bool(profile.get("ranged", false)), intensity)
	_spawn_damage_text(target, int(event.get("damage", 0)), critical)
	_shake_camera(intensity * 1.15, 0.18 + intensity * 0.018)


func _present_miss(event: Dictionary) -> void:
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target == null:
		return
	_spawn_floating_text(target, "MISS", Color(0.70, 0.90, 1.0, 1.0), 25)


func _present_knockout(event: Dictionary) -> void:
	var target: Node = _find_actor(String(event.get("target_id", "")))
	if target != null and target.has_method("play_knockout_animation"):
		target.call("play_knockout_animation")


func _schedule_after_impact(callback: Callable, extra_delay: float) -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	var total_delay: float = remaining + maxf(0.0, extra_delay)
	if total_delay <= 0.001:
		callback.call()
		return
	var timer: SceneTreeTimer = get_tree().create_timer(total_delay)
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)


func _impact_delay(attacker: Node, target: Node, ranged: bool) -> float:
	if not ranged:
		return MELEE_IMPACT_DELAY
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var travel_time: float = clampf(
		start.distance_to(finish) / 720.0,
		PROJECTILE_MIN_TIME,
		PROJECTILE_MAX_TIME
	)
	return RANGED_CHARGE_TIME + travel_time


func _spawn_melee_windup(attacker: Node, target: Node, color: Color, intensity: float) -> void:
	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var direction: Vector2 = finish - start
	if direction.length_squared() < 1.0:
		return
	var midpoint: Vector2 = start.lerp(finish, 0.50)
	var angle: float = direction.angle()
	_spawn_world_sprite(
		_slash_texture,
		midpoint,
		color,
		0.045,
		0.105 + intensity * 0.004,
		0.20,
		angle,
		0.32
	)


func _spawn_charge_flash(attacker: Node, color: Color, intensity: float) -> void:
	var anchor: Vector2 = _actor_fx_anchor(attacker)
	_spawn_world_sprite(
		_muzzle_texture if _muzzle_texture != null else _flare_texture,
		anchor,
		color,
		0.025,
		0.085 + intensity * 0.004,
		0.18,
		0.0,
		0.18
	)


func _spawn_projectile(
	attacker: Node,
	target: Node,
	color: Color,
	intensity: float,
	impact_delay: float
) -> void:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var start: Vector2 = _actor_fx_anchor(attacker)
	var finish: Vector2 = _actor_fx_anchor(target)
	var travel_time: float = maxf(PROJECTILE_MIN_TIME, impact_delay - RANGED_CHARGE_TIME)
	var projectile: Node2D = Node2D.new()
	projectile.name = "TechniqueProjectileFX"
	projectile.global_position = start
	projectile.scale = Vector2.ONE * 0.45
	projectile.z_index = 92
	parent_node.add_child(projectile)

	if _magic_texture != null:
		var core: Sprite2D = Sprite2D.new()
		core.texture = _magic_texture
		core.modulate = color
		core.scale = Vector2.ONE * (0.050 + intensity * 0.002)
		core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		projectile.add_child(core)
	if _flare_texture != null:
		var glow: Sprite2D = Sprite2D.new()
		glow.texture = _flare_texture
		glow.modulate = Color(color.r, color.g, color.b, 0.62)
		glow.scale = Vector2.ONE * (0.028 + intensity * 0.0015)
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		projectile.add_child(glow)

	var tween: Tween = projectile.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(projectile, "scale", Vector2.ONE, RANGED_CHARGE_TIME)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(projectile, "global_position", finish, travel_time)
	tween.parallel().tween_property(projectile, "rotation", TAU * 0.72, travel_time)
	tween.finished.connect(projectile.queue_free, CONNECT_ONE_SHOT)


func _spawn_impact_vfx(
	target: Node,
	color: Color,
	critical: bool,
	ranged: bool,
	intensity: float
) -> void:
	var anchor: Vector2 = _actor_fx_anchor(target)
	if not ranged:
		_spawn_world_sprite(
			_slash_texture,
			anchor,
			color.lightened(0.18),
			0.050,
			0.125 + intensity * 0.005,
			0.22,
			-0.25,
			0.46
		)
	_spawn_world_sprite(
		_spark_texture,
		anchor,
		Color.WHITE if critical else color.lightened(0.24),
		0.028,
		0.105 + intensity * 0.004,
		0.20,
		0.0,
		0.72
	)
	_spawn_world_sprite(
		_flare_texture,
		anchor,
		Color(1.0, 0.94, 0.62, 0.92) if critical else Color(color.r, color.g, color.b, 0.70),
		0.020,
		0.075 + intensity * 0.003,
		0.16,
		0.0,
		0.0
	)


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
	if texture == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var fx: Sprite2D = Sprite2D.new()
	fx.texture = texture
	fx.global_position = world_position
	fx.modulate = color
	fx.scale = Vector2.ONE * start_scale
	fx.rotation = rotation_value
	fx.z_index = 94
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent_node.add_child(fx)
	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fx, "scale", Vector2.ONE * end_scale, duration)
	tween.tween_property(fx, "rotation", rotation_value + rotation_delta, duration)
	tween.tween_property(fx, "modulate:a", 0.0, duration)
	tween.finished.connect(fx.queue_free, CONNECT_ONE_SHOT)


func _spawn_damage_text(target: Node, amount: int, critical: bool) -> void:
	var damage: int = maxi(0, amount)
	var text_value: String = "CRIT  %d" % damage if critical else "%d" % damage
	var color: Color = Color(1.0, 0.82, 0.20, 1.0) if critical else Color(1.0, 0.97, 0.91, 1.0)
	_spawn_floating_text(target, text_value, color, 33 if critical else 27)


func _spawn_floating_text(target: Node, text_value: String, color: Color, font_size: int) -> void:
	if _overlay_root == null or target == null or not is_instance_valid(target):
		return
	var label: Label = Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(180.0, 56.0)
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.98))
	label.add_theme_constant_override("outline_size", 7)
	_overlay_root.add_child(label)

	var anchor: Vector2 = _damage_anchor(target)
	_floating_entries.append({
		"label": label,
		"target": target,
		"anchor": anchor,
		"elapsed": 0.0,
		"duration": FLOATING_TEXT_DURATION,
	})
	_position_floating_entry(_floating_entries[_floating_entries.size() - 1])


func _update_floating_text(delta: float) -> void:
	for index in range(_floating_entries.size() - 1, -1, -1):
		var entry: Dictionary = _floating_entries[index]
		var label: Label = entry.get("label") as Label
		if label == null or not is_instance_valid(label):
			_floating_entries.remove_at(index)
			continue
		var elapsed: float = float(entry.get("elapsed", 0.0)) + delta
		var duration: float = maxf(0.1, float(entry.get("duration", FLOATING_TEXT_DURATION)))
		entry["elapsed"] = elapsed
		_position_floating_entry(entry)
		var progress: float = clampf(elapsed / duration, 0.0, 1.0)
		var fade_start: float = 0.48
		var alpha: float = 1.0
		if progress > fade_start:
			alpha = 1.0 - ((progress - fade_start) / (1.0 - fade_start))
		label.modulate.a = clampf(alpha, 0.0, 1.0)
		label.scale = Vector2.ONE * (1.0 + (0.12 if progress < 0.16 else 0.0))
		if elapsed >= duration:
			label.queue_free()
			_floating_entries.remove_at(index)


func _position_floating_entry(entry: Dictionary) -> void:
	var label: Label = entry.get("label") as Label
	if label == null:
		return
	var anchor: Vector2 = Vector2(entry.get("anchor", Vector2.ZERO))
	var target: Node = entry.get("target") as Node
	if target != null and is_instance_valid(target):
		anchor = _damage_anchor(target)
		entry["anchor"] = anchor
	var elapsed: float = float(entry.get("elapsed", 0.0))
	var duration: float = maxf(0.1, float(entry.get("duration", FLOATING_TEXT_DURATION)))
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var eased_rise: float = 1.0 - pow(1.0 - progress, 2.0)
	var screen_position: Vector2 = _world_to_screen(anchor)
	label.position = screen_position - label.size * 0.5 + Vector2(0.0, -FLOATING_TEXT_RISE * eased_rise)


func _build_screen_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "CombatFeedbackLayer"
	_overlay_layer.layer = 108
	add_child(_overlay_layer)
	_overlay_root = Control.new()
	_overlay_root.name = "CombatFeedbackRoot"
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay_root)


func _load_vfx_assets() -> void:
	_slash_texture = _load_texture("%s/slash_03.png" % VFX_ROOT)
	_spark_texture = _load_texture("%s/spark_04.png" % VFX_ROOT)
	_magic_texture = _load_texture("%s/magic_03.png" % VFX_ROOT)
	_flare_texture = _load_texture("%s/flare_01.png" % VFX_ROOT)
	_muzzle_texture = _load_texture("%s/muzzle_01.png" % VFX_ROOT)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _actor_fx_anchor(actor: Node) -> Vector2:
	if actor != null and actor.has_method("get_combat_fx_anchor_world"):
		return Vector2(actor.call("get_combat_fx_anchor_world"))
	if actor is Node2D:
		return (actor as Node2D).global_position + Vector2(0.0, -28.0)
	return Vector2.ZERO


func _damage_anchor(actor: Node) -> Vector2:
	if actor != null and actor.has_method("get_damage_number_anchor_world"):
		return Vector2(actor.call("get_damage_number_anchor_world"))
	if actor is Node2D:
		return (actor as Node2D).global_position + Vector2(0.0, -52.0)
	return Vector2.ZERO


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _current_action_profile(event: Dictionary) -> Dictionary:
	var action: Dictionary = {}
	if _battle_controller != null and _battle_controller.has_method("get_selected_action"):
		var raw_action = _battle_controller.call("get_selected_action")
		if raw_action is Dictionary:
			action = raw_action
	var power: int = maxi(1, int(action.get("power", 28)))
	var intensity: float = clampf(2.8 + float(power) / 16.0, 3.5, 7.2)
	var range_data = action.get("range", {})
	var max_range: int = 1
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
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and camera.has_method("shake"):
		camera.call("shake", clampf(intensity, 3.0, 9.5), clampf(duration, 0.16, 0.34))


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
