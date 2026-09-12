extends "res://src/ui/DigimonRosterMenu.gd"
class_name DigimonProgressionMenu

const ProgressionUI = preload("res://src/ui/TacticalTheme.gd")
const EvolutionConstellationScript = preload("res://src/ui/EvolutionConstellation.gd")
const DigiLabScreenScript = preload("res://src/ui/DigiLabScreen.gd")

var _digilab_button: Button
var _constellation: EvolutionConstellation
var _digilab: DigiLabScreen


func _build() -> void:
	super._build()
	_digilab_button = _button("DIGILAB", ProgressionUI.CYAN)
	_digilab_button.name = "OpenDigiLab"
	_digilab_button.pressed.connect(_open_digilab)
	add_child(_digilab_button)

	_constellation = EvolutionConstellationScript.new() as EvolutionConstellation
	_constellation.name = "EvolutionConstellation"
	_constellation.visible = false
	_constellation.close_requested.connect(_close_constellation)
	_constellation.evolution_applied.connect(_on_evolution_state_changed)
	add_child(_constellation)

	_digilab = DigiLabScreenScript.new() as DigiLabScreen
	_digilab.name = "DigiLabScreen"
	_digilab.visible = false
	_digilab.close_requested.connect(_close_digilab)
	_digilab.reconstructed.connect(_on_reconstructed)
	add_child(_digilab)


func open_menu() -> void:
	if _constellation != null:
		_constellation.visible = false
	if _digilab != null:
		_digilab.visible = false
	super.open_menu()


func has_nested_view_open() -> bool:
	return (_constellation != null and _constellation.is_open()) or (_digilab != null and _digilab.is_open())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _constellation != null and _constellation.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_close_constellation()
			get_viewport().set_input_as_handled()
		return
	if _digilab != null and _digilab.is_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
			_close_digilab()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _build_evolution_card(instance: DigimonInstance) -> Control:
	var card := _section_card("EVOLUTION CONSTELLATION", ProgressionUI.PURPLE)
	var body := card.get_meta("body") as VBoxContainer
	var evolutions: Array[Dictionary] = _progression.get_evolution_routes(instance)
	var degenerations: Array[Dictionary] = _progression.get_degeneration_routes(instance)
	var ready_evolutions := 0
	var ready_degenerations := 0
	for route: Dictionary in evolutions:
		if bool(route.get("unlocked", false)):
			ready_evolutions += 1
	for route: Dictionary in degenerations:
		if bool(route.get("unlocked", false)):
			ready_degenerations += 1

	var summary := _wrapped_value(
		"Explore the complete connected evolution graph, inspect future forms and requirements, plan a route, then Digivolve or Degenerate directly from the constellation.",
		ProgressionUI.MUTED
	)
	body.add_child(summary)
	body.add_child(_label("%d direct evolution routes · %d ready    |    %d degeneration routes · %d ready" % [
		evolutions.size(), ready_evolutions, degenerations.size(), ready_degenerations
	], 10, ProgressionUI.CYAN, true))

	if not instance.evolution_goal_seed.is_empty():
		var goal_species := _database.get_by_seed(instance.evolution_goal_seed)
		if not goal_species.is_empty():
			body.add_child(_subheading("EVOLUTION GOAL", ProgressionUI.PURPLE))
			body.add_child(_label(String(goal_species.get("name", "Unknown")).to_upper(), 13, ProgressionUI.PURPLE.lightened(0.16), true))

	var open_button := _button("OPEN EVOLUTION CONSTELLATION", ProgressionUI.PURPLE)
	open_button.custom_minimum_size.y = 44.0
	open_button.pressed.connect(_open_constellation.bind(instance.id))
	body.add_child(open_button)
	return card


func _open_constellation(instance_id: String) -> void:
	if _constellation == null:
		return
	var instance := OverworldState.get_instance_by_id(instance_id)
	if instance == null:
		return
	_constellation.open_for(instance)
	_digilab_button.visible = false


func _close_constellation() -> void:
	if _constellation != null:
		_constellation.visible = false
	_digilab_button.visible = true
	_refresh_roster()
	if not _buttons.is_empty():
		_buttons[clampi(_selected_index, 0, _buttons.size() - 1)].grab_focus()


func _open_digilab() -> void:
	if _digilab == null:
		return
	_digilab.open_lab()
	_digilab_button.visible = false


func _close_digilab() -> void:
	if _digilab != null:
		_digilab.visible = false
	_digilab_button.visible = true
	_refresh_roster()
	if not _buttons.is_empty():
		_buttons[clampi(_selected_index, 0, _buttons.size() - 1)].grab_focus()


func _on_evolution_state_changed(_instance: DigimonInstance) -> void:
	OverworldState.notify_roster_changed()
	_refresh_roster()


func _on_reconstructed(instance: DigimonInstance) -> void:
	if instance == null:
		return
	_refresh_roster()


func _layout() -> void:
	super._layout()
	if _digilab_button == null or _panel == null:
		return
	var physical := ProgressionUI.physical_window_size(get_viewport())
	var scale_factor := ProgressionUI.ui_scale(get_viewport())
	var compact := ProgressionUI.is_compact(get_viewport(), 840.0)
	var edge := 12.0 if compact else 18.0
	var width := minf(1240.0, physical.x - edge * 2.0)
	var height := minf(760.0, physical.y - edge * 2.0)
	var origin := Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_digilab_button.scale = Vector2.ONE * scale_factor
	_digilab_button.position = origin + Vector2(width - 218.0, 14.0) * scale_factor
	_digilab_button.size = Vector2(96.0, 40.0)
	_digilab_button.visible = not has_nested_view_open()
	if width >= 650.0:
		_account.position = origin + Vector2(width - 460.0, 21.0) * scale_factor
		_account.size = Vector2(220.0, 26.0)
		_account.visible = true
	else:
		_account.visible = false
