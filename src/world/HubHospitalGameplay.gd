extends "res://src/world/HubTrainingGameplay.gd"

const HospitalScreenScript = preload("res://src/ui/DigiPremiumHospitalScreen.gd")
const HospitalActorScript = preload("res://src/world/HubActor.gd")
const HOSPITAL_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

var _hospital_npc: HubActor = null
var _hospital_screen: HospitalScreen = null
var _hospital_transition_surface: DigiUiTransitionSurface = null
var _hospital_open := false


func _ready() -> void:
	super._ready()
	_build_hospital_npc()
	_build_hospital_ui()
	call_deferred("_layout_ui")
	call_deferred("_refresh_interaction")


func _unhandled_input(event: InputEvent) -> void:
	if _hospital_open:
		return
	if not _training_open and not _digilab_open and not _menu_open and not _dialog_open and not _transitioning and _is_interact_event(event) and _hospital_has_interaction_priority():
		_open_hospital()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _build_hospital_npc() -> void:
	var actors := get_node_or_null("Actors") as Node2D
	if actors == null:
		return
	_hospital_npc = HospitalActorScript.new() as HubActor
	_hospital_npc.name = "HospitalSpecialist"
	_hospital_npc.configure(HOSPITAL_TEXTURE, false, self, "southwest")
	_hospital_npc.position = _grid_to_world(Vector2(4, -2))
	actors.add_child(_hospital_npc)
	_blockers.append({"position": _hospital_npc.position, "radius": 28.0})
	var sprite := _hospital_npc.get_node_or_null("CharacterSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.70, 1.0, 0.96, 1.0)
	var label := Label.new()
	label.name = "RoleLabel"
	label.position = Vector2(-72, -86)
	label.size = Vector2(144, 24)
	label.text = "DIGI HOSPITAL"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", V2.CYAN)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	V2.apply_heading(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hospital_npc.add_child(label)
	var glow := PointLight2D.new()
	glow.name = "HospitalGlow"
	glow.energy = 0.38
	glow.texture_scale = 1.12
	glow.color = V2.CYAN
	glow.position = Vector2(0, -38)
	_hospital_npc.add_child(glow)


func _build_hospital_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HospitalUI"
	layer.layer = 96
	add_child(layer)
	_hospital_screen = HospitalScreenScript.new() as HospitalScreen
	_hospital_screen.name = "Hospital"
	_hospital_screen.visible = false
	_hospital_screen.set_close_lifecycle_managed(true)
	_hospital_screen.close_requested.connect(_close_hospital)
	layer.add_child(_hospital_screen)
	_hospital_transition_surface = _hospital_screen.get_transition_surface()


func _open_hospital() -> void:
	if _hospital_open or _training_open or _digilab_open or _menu_open or _dialog_open or _transitioning or _hospital_screen == null or _hospital_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_open(_hospital_transition_surface, "hospital"):
		return
	_hospital_open = true
	_release_touch_movement()
	if _player != null:
		_player.movement_enabled = false
		_player.velocity = Vector2.ZERO
		_player.set_facing("northeast")
	if _hospital_npc != null:
		_hospital_npc.set_facing("southwest")
	_hospital_screen.open_screen()
	UiSfxDirector.play_open()
	_layout_ui()
	await DigiUiTransitionDirector.reveal_open()
	if OS.is_debug_build():
		print("[Hub] DIGI_HOSPITAL open")


func _close_hospital() -> void:
	if not _hospital_open or _hospital_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_close(_hospital_transition_surface, "hospital"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_hospital_open = false
	if _hospital_screen != null:
		_hospital_screen.finish_close()
	if _player != null:
		_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()
	DigiUiTransitionDirector.complete_close()
	if OS.is_debug_build():
		print("[Hub] DIGI_HOSPITAL close")


func _refresh_interaction() -> void:
	if _interaction_prompt == null:
		return
	if _hospital_open:
		_interaction_prompt.visible = false
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = true
		return
	if not _training_open and not _digilab_open and not _menu_open and not _dialog_open and _hospital_has_interaction_priority():
		var compact := UI.is_compact(get_viewport(), 760.0)
		_interaction_prompt.visible = not compact and not _transitioning
		_set_v2_interaction_action("OPEN HOSPITAL", "HOSPITAL")
		_objective_label.text = "SERVICE  -  Digi Hospital"
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = _transitioning
		return
	super._refresh_interaction()


func _on_mobile_interact() -> void:
	if _hospital_open:
		return
	if _hospital_has_interaction_priority():
		_open_hospital()
		return
	super._on_mobile_interact()


func _hospital_has_interaction_priority() -> bool:
	if not _is_hospital_nearby():
		return false
	var hospital_distance := _player.position.distance_to(_hospital_npc.position)
	var other_distances: Array[float] = []
	if _operator != null:
		other_distances.append(_player.position.distance_to(_operator.position))
	if _digilab_terminal != null:
		other_distances.append(_player.position.distance_to(_digilab_terminal.position))
	if _trainer != null:
		other_distances.append(_player.position.distance_to(_trainer.position))
	for distance: float in other_distances:
		if distance < hospital_distance:
			return false
	return true


func _is_hospital_nearby() -> bool:
	return _player != null and _hospital_npc != null and _player.position.distance_to(_hospital_npc.position) <= _interaction_distance_for_current_device()


func _layout_ui() -> void:
	super._layout_ui()
	if not _hospital_open:
		return
	if _touch_menu_button != null:
		_touch_menu_button.visible = false
	if _touch_digilab_button != null:
		_touch_digilab_button.visible = false
	if _mobile_controls != null:
		_mobile_controls.visible = false
