extends Node2D
class_name BattleDigimon

const DigimonInstanceScript = preload("res://src/domain/digimon/DigimonInstance.gd")
const DigimonStatCalculatorScript = preload("res://src/domain/digimon/DigimonStatCalculator.gd")
const DirectionalSpriteContractScript = preload("res://src/presentation/DirectionalSpriteContract.gd")

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_marker: Polygon2D = $SelectionMarker
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var name_label: Label = $NameLabel
@onready var status_container: HBoxContainer = $StatusContainer

var digimon_instance = null
var species_data: Dictionary = {}
var is_player_controlled := false
var current_hp := 1
var current_sp := 0
var grid_position := Vector2i.ZERO
var size := Vector2i.ONE
var battle_state = null
var movement_type := "ground"
var footprint_shape := "single"
var occupied_cells: Array[Vector2i] = []
var _stat_calculator = DigimonStatCalculatorScript.new()
var _status_badges: Array[Label] = []
var _active_tweens: Array[Tween] = []
var _base_sprite_scale := Vector2.ONE
var _base_sprite_modulate := Color.WHITE
var _base_sprite_position := Vector2.ZERO
var _base_z_index := 0

const DAMAGE_FLASH_TIME := 0.28
const HEAL_FLASH_TIME := 0.30
const FLOATING_TEXT_TIME := 0.72


func _ready() -> void:
	if sprite != null:
		_base_sprite_scale = sprite.scale
		_base_sprite_modulate = sprite.modulate
		_base_sprite_position = sprite.position
		_base_z_index = sprite.z_index
	_apply_visuals()
	_refresh_hud()


func setup(instance, species: Dictionary, player_controlled: bool, start_grid: Vector2i) -> void:
	digimon_instance = instance
	species_data = species.duplicate(true)
	is_player_controlled = player_controlled
	grid_position = start_grid
	movement_type = String(species_data.get("movementType", "ground"))
	footprint_shape = String(species_data.get("footprint", "single"))
	if digimon_instance != null:
		var instance_footprint := String(digimon_instance.get("footprint_shape"))
		if not instance_footprint.is_empty():
			footprint_shape = instance_footprint
	var shape := String(footprint_shape).to_lower()
	if shape == "2x2" or shape == "large_square":
		size = Vector2i(2, 2)
	else:
		size = Vector2i.ONE
	if digimon_instance != null:
		current_hp = maxi(1, int(digimon_instance.get("current_hp")))
		current_sp = maxi(0, int(digimon_instance.get("current_sp")))
	else:
		current_hp = get_max_hp()
		current_sp = get_max_sp()
	_refresh_hud()


func set_battle_state(state) -> void:
	battle_state = state
	_refresh_hud()


func set_occupied_cells(cells: Array[Vector2i]) -> void:
	occupied_cells = cells.duplicate()


func get_occupied_cells() -> Array[Vector2i]:
	if not occupied_cells.is_empty():
		return occupied_cells.duplicate()
	var fallback: Array[Vector2i] = []
	for y: int in range(size.y):
		for x: int in range(size.x):
			fallback.append(grid_position + Vector2i(x, y))
	return fallback


func get_footprint_shape() -> String:
	return footprint_shape


func set_turn_active(active: bool) -> void:
	if selection_marker != null:
		selection_marker.visible = active


func get_instance_id_string() -> String:
	if digimon_instance == null:
		return ""
	return String(digimon_instance.get("instance_id"))


func get_species_seed() -> String:
	if digimon_instance == null:
		return ""
	return String(digimon_instance.get("species_seed"))


func get_display_name() -> String:
	if digimon_instance != null:
		var nickname := String(digimon_instance.get("nickname"))
		if not nickname.is_empty():
			return nickname
	return String(species_data.get("name", "Digimon"))


func get_level() -> int:
	if digimon_instance == null:
		return 1
	return int(digimon_instance.get("level"))


func get_rank() -> String:
	return String(species_data.get("rank", "Rookie"))


func get_combat_type() -> String:
	return String(species_data.get("type", "Data"))


func get_combat_element() -> String:
	return String(species_data.get("element", "neutral"))


func get_family() -> String:
	return String(species_data.get("family", "Nature Spirits"))


func get_max_hp() -> int:
	return maxi(1, int(get_final_stat("hp")))


func get_max_sp() -> int:
	return maxi(0, int(get_final_stat("sp")))


func get_current_hp() -> int:
	return current_hp


func get_current_sp() -> int:
	return current_sp


func get_final_mov() -> int:
	if digimon_instance != null:
		var mov_value = digimon_instance.get("final_mov")
		if mov_value != null:
			return maxi(1, int(mov_value))
	return maxi(1, int(species_data.get("MOV", 4)))


func get_movement_type() -> String:
	return movement_type


func get_final_stat(stat_name: String) -> int:
	if digimon_instance != null:
		return int(_stat_calculator.calculate_stat(digimon_instance, species_data, stat_name))
	return int(species_data.get(stat_name, 1))


func get_initiative() -> float:
	if battle_state != null and battle_state.has_method("get_initiative"):
		return float(battle_state.call("get_initiative"))
	return float(get_final_stat("speed"))


func get_statuses() -> Array:
	if battle_state != null and battle_state.has_method("get_statuses"):
		return battle_state.call("get_statuses")
	return []


func is_defeated() -> bool:
	return current_hp <= 0


func apply_damage(amount: int) -> int:
	if amount <= 0 or is_defeated():
		return 0
	var before := current_hp
	current_hp = maxi(0, current_hp - amount)
	var applied := before - current_hp
	if digimon_instance != null:
		digimon_instance.set("current_hp", current_hp)
	_refresh_hud()
	if applied > 0:
		play_damage_feedback(applied)
	return applied


func heal(amount: int) -> int:
	if amount <= 0 or is_defeated():
		return 0
	var before := current_hp
	current_hp = mini(get_max_hp(), current_hp + amount)
	var applied := current_hp - before
	if digimon_instance != null:
		digimon_instance.set("current_hp", current_hp)
	_refresh_hud()
	if applied > 0:
		play_heal_feedback(applied)
	return applied


func spend_sp(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_sp < amount:
		return false
	current_sp -= amount
	if digimon_instance != null:
		digimon_instance.set("current_sp", current_sp)
	_refresh_hud()
	return true


func restore_sp(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := current_sp
	current_sp = mini(get_max_sp(), current_sp + amount)
	var applied := current_sp - before
	if digimon_instance != null:
		digimon_instance.set("current_sp", current_sp)
	_refresh_hud()
	return applied


func refresh_from_state() -> void:
	_refresh_hud()


func play_damage_feedback(amount: int) -> void:
	if is_defeated():
		return
	_kill_feedback_tweens()
	if sprite != null:
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.25, 1.0), 0.06)
		tween.tween_property(sprite, "position:x", _base_sprite_position.x - 4.0, 0.04)
		tween.tween_property(sprite, "position:x", _base_sprite_position.x + 4.0, 0.04)
		tween.tween_property(sprite, "position:x", _base_sprite_position.x, 0.04)
		tween.parallel().tween_property(sprite, "modulate", _base_sprite_modulate, DAMAGE_FLASH_TIME)
	_spawn_floating_text("-%d" % amount, Color(1.0, 0.48, 0.38), 22)
	_spawn_burst(Color(1.0, 0.26, 0.18, 0.95), 18, 90.0, 0.48, 1.6)


func play_heal_feedback(amount: int) -> void:
	if is_defeated():
		return
	_kill_feedback_tweens()
	if sprite != null:
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "modulate", Color(0.45, 1.0, 0.67, 1.0), 0.08)
		tween.tween_property(sprite, "scale", _base_sprite_scale * 1.08, 0.10)
		tween.tween_property(sprite, "scale", _base_sprite_scale, 0.14)
		tween.parallel().tween_property(sprite, "modulate", _base_sprite_modulate, HEAL_FLASH_TIME)
	_spawn_floating_text("+%d" % amount, Color(0.48, 1.0, 0.68), 22)
	_spawn_burst(Color(0.34, 1.0, 0.60, 0.95), 16, 76.0, 0.62, 1.5)


func play_status_feedback(label_text: String, positive: bool) -> void:
	if is_defeated():
		return
	var tint := Color(0.42, 0.78, 1.0, 1.0) if positive else Color(0.92, 0.46, 1.0, 1.0)
	_spawn_floating_text(label_text, tint, 18)
	_spawn_burst(tint, 10, 54.0, 0.44, 1.25)


func play_defeat_feedback() -> void:
	_kill_feedback_tweens()
	if sprite != null:
		var tween := create_tween()
		_active_tweens.append(tween)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "modulate", Color(0.18, 0.18, 0.2, 0.0), 0.34)
		tween.parallel().tween_property(sprite, "position:y", _base_sprite_position.y + 10.0, 0.34)
	_spawn_burst(Color(0.58, 0.62, 0.72, 0.8), 12, 62.0, 0.40, 1.2)


func play_normal_attack_animation(target: Node) -> void:
	if target == null or sprite == null:
		return
	var original_position := sprite.position
	var target_direction := Vector2.RIGHT
	if target is Node2D:
		target_direction = (target.global_position - global_position).normalized()
	if target_direction.length_squared() < 0.01:
		target_direction = Vector2.RIGHT
	var lunge := target_direction * 10.0
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", original_position + lunge, 0.08)
	tween.tween_property(sprite, "position", original_position, 0.11)
	await tween.finished


func play_cast_animation(_action: Dictionary) -> void:
	if sprite == null:
		return
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate", Color(0.72, 0.92, 1.0, 1.0), 0.08)
	tween.tween_property(sprite, "scale", _base_sprite_scale * 1.08, 0.08)
	tween.tween_property(sprite, "scale", _base_sprite_scale, 0.09)
	tween.parallel().tween_property(sprite, "modulate", _base_sprite_modulate, 0.16)
	await tween.finished


func play_impact_animation() -> void:
	if sprite == null:
		return
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.78, 0.34, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", _base_sprite_modulate, 0.12)
	await tween.finished


func _apply_visuals() -> void:
	if sprite == null:
		return
	var texture_path := String(species_data.get("sprite", ""))
	if texture_path.is_empty():
		texture_path = String(species_data.get("fieldSprite", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var loaded = load(texture_path)
		if loaded is Texture2D:
			sprite.texture = loaded
	var frame_coords := DirectionalSpriteContractScript.frame_coords_from_species(species_data)
	if not frame_coords.is_empty():
		var contract := DirectionalSpriteContractScript.resolve_for_species(species_data)
		sprite.hframes = int(contract.get("hframes", 1))
		sprite.vframes = int(contract.get("vframes", 1))
		sprite.frame_coords = frame_coords[0]
	var requested_scale := float(species_data.get("battleScale", 1.0))
	var base_scale := Vector2(requested_scale, requested_scale)
	if size.x > 1 or size.y > 1:
		base_scale *= 1.32
	sprite.scale = base_scale
	_base_sprite_scale = sprite.scale
	_base_sprite_modulate = sprite.modulate
	_base_sprite_position = sprite.position
	_base_z_index = sprite.z_index


func _refresh_hud() -> void:
	if health_bar != null:
		health_bar.max_value = get_max_hp()
		health_bar.value = current_hp
	if health_label != null:
		health_label.text = "%d/%d" % [current_hp, get_max_hp()]
	if name_label != null:
		name_label.text = get_display_name()
	_refresh_status_badges()


func _refresh_status_badges() -> void:
	if status_container == null:
		return
	for badge: Label in _status_badges:
		if badge != null and is_instance_valid(badge):
			badge.queue_free()
	_status_badges.clear()
	for status_variant in get_statuses():
		if not (status_variant is Dictionary):
			continue
		var status := status_variant as Dictionary
		var badge := Label.new()
		badge.text = String(status.get("id", "status")).to_upper()
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96, 1.0))
		status_container.add_child(badge)
		_status_badges.append(badge)


func _kill_feedback_tweens() -> void:
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	if sprite != null:
		sprite.position = _base_sprite_position
		sprite.scale = _base_sprite_scale
		sprite.modulate = _base_sprite_modulate


func _sprite_visual_height() -> float:
	if sprite == null:
		return 48.0
	var rect: Rect2 = sprite.get_rect()
	return maxf(1.0, rect.size.y * absf(sprite.scale.y))


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
	particles.explosiveness = 1.0
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
