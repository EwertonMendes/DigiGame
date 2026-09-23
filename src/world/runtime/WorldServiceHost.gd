extends Node
class_name WorldServiceHost

signal service_state_changed(open: bool, service_id: String)

const DigimonMenuScript = preload("res://src/ui/DigiSystemProgressionMenu.gd")
const DigiLabScript = preload("res://src/ui/DigiLabHubScreen.gd")
const TrainingScript = preload("res://src/ui/TrainingCenterScreen.gd")
const HospitalScript = preload("res://src/ui/DigiPremiumHospitalScreen.gd")

var _player: HubActor = null
var _menu: DigimonCollectionMenu = null
var _digilab: DigiLabHubScreen = null
var _training: TrainingCenterScreen = null
var _hospital: HospitalScreen = null
var _active_service := ""


func configure(player: HubActor) -> void:
	_player = player


func _ready() -> void:
	_build_services()


func is_open() -> bool:
	return not _active_service.is_empty()


func open_main_menu() -> void:
	if is_open() or _menu == null:
		return
	var surface := _menu.call("get_transition_surface") as DigiUiTransitionSurface
	if surface == null or not DigiUiTransitionDirector.begin_open(surface, "digimon"):
		return
	_active_service = "menu"
	_set_player_locked(true)
	_menu.open_menu()
	UiSfxDirector.play_open()
	service_state_changed.emit(true, _active_service)
	await DigiUiTransitionDirector.reveal_open()


func open_service(service_id: String) -> void:
	if is_open():
		return
	match service_id:
		"digilab":
			await _open_digilab()
		"training":
			await _open_training()
		"hospital":
			await _open_hospital()


func _build_services() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldServices"
	layer.layer = 95
	add_child(layer)

	_menu = DigimonMenuScript.new() as DigimonCollectionMenu
	_menu.name = "DigimonMenu"
	_menu.visible = false
	_menu.close_requested.connect(_close_menu)
	layer.add_child(_menu)

	_digilab = DigiLabScript.new() as DigiLabHubScreen
	_digilab.name = "DigiLab"
	_digilab.visible = false
	_digilab.close_requested.connect(_close_digilab)
	layer.add_child(_digilab)

	_training = TrainingScript.new() as TrainingCenterScreen
	_training.name = "TrainingCenter"
	_training.visible = false
	_training.set_close_lifecycle_managed(true)
	_training.close_requested.connect(_close_training)
	layer.add_child(_training)

	_hospital = HospitalScript.new() as HospitalScreen
	_hospital.name = "Hospital"
	_hospital.visible = false
	_hospital.set_close_lifecycle_managed(true)
	_hospital.close_requested.connect(_close_hospital)
	layer.add_child(_hospital)


func _open_digilab() -> void:
	var surface := _digilab.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_open(surface, "digilab"):
		return
	_active_service = "digilab"
	_set_player_locked(true)
	_digilab.open_lab()
	UiSfxDirector.play_open()
	service_state_changed.emit(true, _active_service)
	await DigiUiTransitionDirector.reveal_open()


func _open_training() -> void:
	var surface := _training.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_open(surface, "training"):
		return
	_active_service = "training"
	_set_player_locked(true)
	_training.open_screen()
	UiSfxDirector.play_open()
	service_state_changed.emit(true, _active_service)
	await DigiUiTransitionDirector.reveal_open()


func _open_hospital() -> void:
	var surface := _hospital.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_open(surface, "hospital"):
		return
	_active_service = "hospital"
	_set_player_locked(true)
	_hospital.open_screen()
	UiSfxDirector.play_open()
	service_state_changed.emit(true, _active_service)
	await DigiUiTransitionDirector.reveal_open()


func _close_menu() -> void:
	if _active_service != "menu":
		return
	var surface := _menu.call("get_transition_surface") as DigiUiTransitionSurface
	if surface == null or not DigiUiTransitionDirector.begin_close(surface, "digimon"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_menu.visible = false
	_finish_close()


func _close_digilab() -> void:
	if _active_service != "digilab":
		return
	var surface := _digilab.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_close(surface, "digilab"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_digilab.finish_close()
	_finish_close()


func _close_training() -> void:
	if _active_service != "training":
		return
	var surface := _training.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_close(surface, "training"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_training.finish_close()
	_finish_close()


func _close_hospital() -> void:
	if _active_service != "hospital":
		return
	var surface := _hospital.get_transition_surface()
	if surface == null or not DigiUiTransitionDirector.begin_close(surface, "hospital"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_hospital.finish_close()
	_finish_close()


func _finish_close() -> void:
	var closed_id := _active_service
	_active_service = ""
	_set_player_locked(false)
	DigiUiTransitionDirector.complete_close()
	service_state_changed.emit(false, closed_id)


func _set_player_locked(locked: bool) -> void:
	if _player == null:
		return
	_player.movement_enabled = not locked
	_player.velocity = Vector2.ZERO
	_player.set_touch_direction(Vector2.ZERO)
