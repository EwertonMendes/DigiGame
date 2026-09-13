extends "res://src/world/HubProgressionGameplay.gd"

const TrainingCenterScreenScript = preload("res://src/ui/TrainingCenterScreen.gd")
const TrainerActorScript = preload("res://src/world/HubActor.gd")
const TRAINER_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

var _trainer: HubActor = null
var _training_screen: TrainingCenterScreen = null
var _training_open := false

func _ready() -> void:
	super._ready()
	_build_training_specialist()
	_build_training_ui()
	call_deferred("_layout_ui")
	call_deferred("_refresh_interaction")

func _unhandled_input(event: InputEvent) -> void:
	if _training_open:
		return
	if not _digilab_open and not _menu_open and not _dialog_open and not _transitioning and _is_interact_event(event) and _trainer_has_interaction_priority():
		_open_training()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _build_training_specialist() -> void:
	var actors := get_node_or_null("Actors") as Node2D
	if actors == null:
		return
	_trainer = TrainerActorScript.new() as HubActor
	_trainer.name = "TrainingSpecialist"
	_trainer.configure(TRAINER_TEXTURE, false, self, "southwest")
	# Put the specialist close to the upper-left rim, clearly separated from both
	# DigiLab and the central Battle Operator. Vertical separation also keeps the
	# long TRAINING SPECIALIST label from ever touching the operator label.
	_trainer.position = _grid_to_world(Vector2(-5, -3))
	actors.add_child(_trainer)
	_blockers.append({"position": _trainer.position, "radius": 28.0})
	var sprite := _trainer.get_node_or_null("CharacterSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.74, 1.0, 0.88, 1.0)
	var label := Label.new()
	label.name = "RoleLabel"
	label.position = Vector2(-82, -86)
	label.size = Vector2(164, 24)
	label.text = "TRAINING SPECIALIST"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI.GREEN)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trainer.add_child(label)
	var glow := PointLight2D.new()
	glow.name = "TrainingGlow"
	glow.energy = 0.36
	glow.texture_scale = 1.1
	glow.color = UI.GREEN
	glow.position = Vector2(0, -38)
	_trainer.add_child(glow)

func _build_training_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrainingCenterUI"
	layer.layer = 94
	add_child(layer)
	_training_screen = TrainingCenterScreenScript.new() as TrainingCenterScreen
	_training_screen.name = "TrainingCenter"
	_training_screen.visible = false
	_training_screen.close_requested.connect(_close_training)
	layer.add_child(_training_screen)

func _open_training() -> void:
	if _training_open or _digilab_open or _menu_open or _dialog_open or _transitioning or _training_screen == null:
		return
	_training_open = true
	_release_touch_movement()
	if _player != null:
		_player.movement_enabled = false
		_player.velocity = Vector2.ZERO
		_player.set_facing("northwest")
	if _trainer != null:
		_trainer.set_facing("southeast")
	_training_screen.open_screen()
	_layout_ui()
	if OS.is_debug_build():
		print("[Hub] TRAINING_CENTER open")

func _close_training() -> void:
	if not _training_open:
		return
	_training_open = false
	if _training_screen != null:
		_training_screen.visible = false
	if _player != null:
		_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()
	if OS.is_debug_build():
		print("[Hub] TRAINING_CENTER close")

func _refresh_interaction() -> void:
	if _interaction_prompt == null:
		return
	if _training_open:
		_interaction_prompt.visible = false
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = true
		return
	if not _digilab_open and not _menu_open and not _dialog_open and _trainer_has_interaction_priority():
		var compact := UI.is_compact(get_viewport(), 760.0)
		_interaction_prompt.visible = not compact and not _transitioning
		_prompt_label.text = "E / ENTER   TRAIN DIGIMON"
		_objective_label.text = "SERVICE  -  Training Center"
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = _transitioning
		return
	super._refresh_interaction()

func _on_mobile_interact() -> void:
	if _training_open:
		return
	if _trainer_has_interaction_priority():
		_open_training()
		return
	super._on_mobile_interact()

func _trainer_has_interaction_priority() -> bool:
	if not _is_trainer_nearby():
		return false
	var trainer_distance := _player.position.distance_to(_trainer.position)
	var operator_distance := INF
	if _operator != null:
		operator_distance = _player.position.distance_to(_operator.position)
	var digilab_distance := INF
	if _digilab_terminal != null:
		digilab_distance = _player.position.distance_to(_digilab_terminal.position)
	return trainer_distance <= operator_distance and trainer_distance <= digilab_distance

func _is_trainer_nearby() -> bool:
	if _player == null or _trainer == null:
		return false
	return _player.position.distance_to(_trainer.position) <= _interaction_distance_for_current_device()

func _layout_ui() -> void:
	super._layout_ui()
	if not _training_open:
		return
	if _touch_menu_button != null:
		_touch_menu_button.visible = false
	if _touch_digilab_button != null:
		_touch_digilab_button.visible = false
	if _mobile_controls != null:
		_mobile_controls.visible = false
