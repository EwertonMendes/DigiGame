extends "res://src/Player.gd"

const BattleDigimonScript = preload("res://src/battle/BattleDigimon.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")

const ATTACK_LUNGE_TIME := 0.10
const ATTACK_RETURN_TIME := 0.16
const HIT_RECOIL_TIME := 0.055
const HIT_RETURN_TIME := 0.13
const FLOATING_TEXT_TIME := 0.72

var digimon_instance: DigimonInstance = null
var battle_state: BattleDigimon = null
var species_data: Dictionary = {}
var _stat_calculator = StatCalculatorScript.new()
var _attack_tween: Tween = null
var _hit_tween: Tween = null
var _knockout_started := false


func bind_digimon_instance(instance: DigimonInstance, species: Dictionary, player_controlled: bool) -> void:
	digimon_instance = instance
	species_data = species.duplicate(true)
	is_player_controlled = player_controlled
	digimon_key = String(species_data.get("name", "")).to_lower()
	battle_state = BattleDigimonScript.new(instance, "player" if player_controlled else "enemy")


func get_digimon_instance_id() -> String:
	return digimon_instance.id if digimon_instance != null else ""


func get_species_seed() -> String:
	return digimon_instance.species_seed if digimon_instance != null else ""


func get_display_name() -> String:
	var species_name := String(species_data.get("name", digimon_key.capitalize()))
	if digimon_instance == null:
		return species_name
	return digimon_instance.get_display_name(species_name)


func get_level() -> int:
	return digimon_instance.level if digimon_instance != null else 1


func get_potential() -> int:
	return digimon_instance.potential if digimon_instance != null else 0


func get_final_stat(stat_key: String) -> int:
	if digimon_instance == null:
		return 0
	if battle_state != null:
		return battle_state.get_stat(_stat_calculator, species_data, stat_key)
	return _stat_calculator.get_stat(digimon_instance, species_data, stat_key)


func get_final_mov() -> int:
	if digimon_instance == null:
		return 4
	if battle_state != null:
		return battle_state.get_mov(_stat_calculator, species_data)
	return _stat_calculator.get_mov(digimon_instance, species_data)


func get_movement_type() -> String:
	return String(species_data.get("movementType", "ground"))


func get_combat_type() -> String:
	return String(species_data.get("type", species_data.get("attribute", "Free")))


func get_combat_element() -> String:
	return String(species_data.get("element", "neutral"))


func get_family() -> String:
	return String(species_data.get("family", species_data.get("species", "Unknown")))


func get_current_hp() -> int:
	return battle_state.current_hp if battle_state != null else 0


func get_current_sp() -> int:
	return battle_state.current_mp if battle_state != null else 0


func spend_sp(amount: int) -> bool:
	return battle_state != null and battle_state.spend_sp(amount)


func take_damage(amount: int) -> int:
	return battle_state.take_damage(amount) if battle_state != null else 0


func heal(amount: int) -> int:
	return battle_state.heal(amount, get_final_stat("hp")) if battle_state != null else 0


func get_equipped_skill_ids() -> Array[String]:
	if digimon_instance == null:
		return []
	return digimon_instance.equipped_skills.duplicate()


func get_learned_skill_ids() -> Array[String]:
	if digimon_instance == null:
		return []
	return digimon_instance.learned_skills.duplicate()


func get_statuses() -> Array[Dictionary]:
	return battle_state.get_statuses() if battle_state != null else []


func get_initiative() -> float:
	return battle_state.initiative if battle_state != null else 0.0


func set_initiative(value: float) -> void:
	if battle_state != null:
		battle_state.set_initiative(value)


func consume_initiative(recovery_cost: float) -> void:
	if battle_state != null:
		battle_state.consume_initiative(recovery_cost)


func is_available_for_turn() -> bool:
	return battle_state != null and not battle_state.is_knocked_out()


func is_pointer_over(world_position: Vector2) -> bool:
	if not visible or not is_available_for_turn():
		return false
	return super.is_pointer_over(world_position)


func play_attack_animation(target: Node, intensity: float = 4.0, ranged: bool = false) -> void:
	if target == null or not is_instance_valid(target) or not visible:
		return
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	var origin: Vector2 = global_position
	var direction: Vector2 = target.global_position - origin
	if direction.length_squared() < 1.0:
		return
	face_toward_world_position(target.global_position)
	var normalized: Vector2 = direction.normalized()
	var lunge_distance: float
	if ranged:
		lunge_distance = clampf(8.0 + intensity * 1.25, 12.0, 18.0)
	else:
		lunge_distance = minf(direction.length() * 0.48, clampf(28.0 + intensity * 4.0, 34.0, 58.0))
	var strike_position: Vector2 = origin + normalized * lunge_distance
	_attack_tween = create_tween()
	_attack_tween.set_trans(Tween.TRANS_QUAD)
	_attack_tween.set_ease(Tween.EASE_IN)
	_attack_tween.tween_property(self, "global_position", strike_position, ATTACK_LUNGE_TIME)
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(self, "global_position", origin, ATTACK_RETURN_TIME)


func play_hit_reaction(source: Node, intensity: float = 4.0) -> void:
	if sprite == null or not visible:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	var base_position: Vector2 = sprite.position
	var base_scale: Vector2 = sprite.scale
	var recoil_direction: Vector2 = Vector2.RIGHT
	if source != null and is_instance_valid(source):
		var delta: Vector2 = global_position - source.global_position
		if delta.length_squared() > 1.0:
			recoil_direction = delta.normalized()
	var recoil: Vector2 = recoil_direction * clampf(3.0 + intensity * 0.65, 5.0, 9.0)
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_QUAD)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(sprite, "position", base_position + recoil, HIT_RECOIL_TIME)
	_hit_tween.parallel().tween_property(sprite, "scale", base_scale * Vector2(1.08, 0.93), HIT_RECOIL_TIME)
	_hit_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.58, 0.52, 1.0), HIT_RECOIL_TIME)
	_hit_tween.set_ease(Tween.EASE_IN_OUT)
	_hit_tween.tween_property(sprite, "position", base_position, HIT_RETURN_TIME)
	_hit_tween.parallel().tween_property(sprite, "scale", base_scale, HIT_RETURN_TIME)
	_hit_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, HIT_RETURN_TIME)


func show_damage_number(amount: int, critical: bool = false) -> void:
	var damage: int = maxi(0, amount)
	var text: String = "CRIT  %d" % damage if critical else "%d" % damage
	var color: Color = Color(1.0, 0.82, 0.20, 1.0) if critical else Color(1.0, 0.96, 0.90, 1.0)
	_spawn_floating_text(text, color, 31 if critical else 25)


func show_miss_feedback() -> void:
	_spawn_floating_text("MISS", Color(0.70, 0.90, 1.0, 1.0), 23)


func emit_hit_particles(element_color: Color, critical: bool = false, intensity: float = 4.0) -> void:
	var amount: int = 24 if critical else int(clampf(10.0 + intensity * 2.0, 14.0, 22.0))
	_spawn_burst(element_color, amount, 78.0 + intensity * 10.0, 0.38, 2.1 if critical else 1.55)
	if critical:
		_spawn_burst(Color(1.0, 0.92, 0.48, 1.0), 12, 145.0, 0.28, 2.4)


func play_knockout_animation() -> void:
	if _knockout_started or not visible:
		return
	_knockout_started = true
	set_tactical_selected(false)
	set_debug_selected(false)
	modulate = Color.WHITE
	if sprite == null:
		visible = false
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	var base_position: Vector2 = sprite.position
	var base_scale: Vector2 = sprite.scale
	var defeat_color: Color = Color(0.30, 0.92, 1.0, 1.0) if is_player_controlled else Color(1.0, 0.34, 0.45, 1.0)
	_spawn_burst(defeat_color, 30, 128.0, 0.58, 2.0)
	_spawn_burst(Color(0.86, 0.96, 1.0, 1.0), 18, 88.0, 0.72, 1.35)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale * Vector2(1.13, 0.90), 0.09)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.68, 0.72, 1.0), 0.09)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", base_scale * 0.48, 0.42)
	tween.parallel().tween_property(sprite, "position", base_position + Vector2(0.0, -18.0), 0.42)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.42)
	await tween.finished
	visible = false
	modulate = Color.WHITE
	sprite.position = base_position
	sprite.scale = base_scale
	sprite.modulate = Color.WHITE


func _spawn_floating_text(text_value: String, color: Color, font_size: int) -> void:
	if not visible:
		return
	var label: Label = Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-72.0, -88.0)
	label.size = Vector2(144.0, 44.0)
	label.z_index = 80
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.035, 0.96))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 38.0, FLOATING_TEXT_TIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.30).set_delay(0.38)
	tween.tween_callback(label.queue_free)


func _spawn_burst(color: Color, amount: int, velocity: float, lifetime: float, particle_scale: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.amount = maxi(1, amount)
	particles.lifetime = maxf(0.1, lifetime)
	particles.one_shot = true
	particles.explosiveness_ratio = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = velocity * 0.62
	particles.initial_velocity_max = velocity
	particles.gravity = Vector2(0.0, 145.0)
	particles.angular_velocity_min = -220.0
	particles.angular_velocity_max = 220.0
	particles.scale_amount_min = particle_scale * 0.55
	particles.scale_amount_max = particle_scale
	particles.color = color
	particles.z_index = 75
	parent_node.add_child(particles)
	particles.global_position = global_position + Vector2(0.0, -30.0)
	particles.emitting = true
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime + 0.45)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func get_instance_snapshot() -> Dictionary:
	if digimon_instance == null:
		return {}
	var snapshot := digimon_instance.to_dict()
	snapshot["speciesName"] = String(species_data.get("name", ""))
	snapshot["rank"] = String(species_data.get("rank", ""))
	snapshot["type"] = get_combat_type()
	snapshot["element"] = get_combat_element()
	snapshot["family"] = get_family()
	snapshot["MOV"] = get_final_mov()
	snapshot["movementType"] = get_movement_type()
	snapshot["stats"] = _stat_calculator.get_all_stats(digimon_instance, species_data)
	snapshot["battleSpeed"] = get_final_stat("speed")
	snapshot["initiative"] = get_initiative()
	snapshot["currentHp"] = get_current_hp()
	snapshot["currentSp"] = get_current_sp()
	snapshot["statuses"] = get_statuses()
	return snapshot
