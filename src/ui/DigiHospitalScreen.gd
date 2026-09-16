extends "res://src/ui/HospitalScreen.gd"

# Presentation/input refinement for the Digi Hospital. Domain actions remain in
# HospitalScreen/OverworldState; this layer owns the final interaction polish.

var _pointer_patient_selection := false


func _build_header() -> void:
	super._build_header()
	var badge := _header.get_node_or_null("BitsBadge") as Panel
	if badge == null:
		return
	badge.clip_contents = false
	var bits_icon: TextureRect = null
	for child in badge.get_children():
		if child is TextureRect:
			bits_icon = child as TextureRect
			break
	if bits_icon == null:
		return
	bits_icon.name = "BitsIcon"
	bits_icon.texture = BITS_ICON
	bits_icon.position = Vector2(12, 8)
	bits_icon.size = Vector2(28, 28)
	bits_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bits_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bits_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bits_icon.modulate = Color.WHITE
	bits_icon.z_index = 4
	_bits_label.position = Vector2(46, 7)
	_bits_label.size = Vector2(108, 32)
	_bits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bits_label.z_index = 4


func _build_overview() -> void:
	super._build_overview()
	_overview_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_overview_header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _information_panel(parent: Node, node_name: String, accent: Color, minimum_height: float) -> PanelContainer:
	var panel := super._information_panel(parent, node_name, accent, minimum_height)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return panel


func _create_patient_card(instance: DigimonInstance) -> Button:
	var card := super._create_patient_card(instance)
	card.gui_input.connect(_on_patient_card_gui_input.bind(instance.id))
	return card


func _on_patient_card_gui_input(event: InputEvent, _id: String) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_pointer_patient_selection = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_pointer_patient_selection = true


func _confirm_instance(id: String) -> void:
	if not _cards.has(id):
		_pointer_patient_selection = false
		return

	var pointer_selection := _pointer_patient_selection
	_pointer_patient_selection = false
	_preview_id = id
	_notice = ""
	_refresh_card_highlights()
	_refresh_detail()

	if _visible_action_keys().is_empty():
		_confirmed_id = ""
		_interaction_mode = InteractionMode.EXPLORE
		_compact_detail = false
		_refresh_detail()
		_layout()
		return

	_confirmed_id = id
	_interaction_mode = InteractionMode.ACTIONS
	_compact_detail = _is_compact()
	_refresh_detail()
	_layout()

	# Mouse/touch users keep direct access to the patient list, so selecting a
	# different card never requires an intermediate click on the overview panel.
	# Keyboard/controller selection still transfers focus to the action column.
	if not pointer_selection:
		call_deferred("_focus_first_action")


func _on_overview_gui_input(_event: InputEvent) -> void:
	# The overview is no longer a hidden "back" target. Pointer users can switch
	# patients directly; keyboard/controller users use the explicit Back action.
	pass


func _apply_status_chip(label: Label, preview: Dictionary) -> void:
	var accent := _status_color(String(preview.get("status", "healthy")))
	label.text = _status_text(preview)
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", accent)
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))


func _create_action_button(key: String, title_text: String, subtitle_text: String, accent: Color, icon_kind: String) -> Button:
	var button := super._create_action_button(key, title_text, subtitle_text, accent, icon_kind)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.set_meta("action_accent", accent)
	button.set_meta("default_subtitle", subtitle_text)

	var icon := button.find_child("DigiProceduralIcon", true, false) as CanvasItem
	if icon == null:
		for child in button.find_children("*", "DigiProceduralIcon", true, false):
			icon = child as CanvasItem
			break
	if icon != null:
		icon.name = "ActionIcon"

	var row: HBoxContainer = null
	for child in button.find_children("*", "HBoxContainer", true, false):
		row = child as HBoxContainer
		break
	if row != null:
		var state := Label.new()
		state.name = "DisabledState"
		state.text = "UNAVAILABLE"
		state.visible = false
		state.size_flags_horizontal = Control.SIZE_SHRINK_END
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		state.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		state.add_theme_font_size_override("font_size", 11)
		state.add_theme_color_override("font_color", V2.MUTED)
		state.add_theme_stylebox_override("normal", V2.pill_style(V2.MUTED, false))
		V2.apply_heading(state)
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(state)
	return button


func _action_style(accent: Color, state: String) -> StyleBoxFlat:
	if state != "disabled":
		return super._action_style(accent, state)
	var style := V2.surface_style(
		Color(0.010, 0.020, 0.029, 0.98),
		Color(V2.SUBTLE.r, V2.SUBTLE.g, V2.SUBTLE.b, 0.72),
		10
	)
	style.set_border_width_all(2)
	style.border_blend = true
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	return style


func _update_action_visibility(preview: Dictionary) -> void:
	var status := String(preview.get("status", "unavailable"))
	var location := String(preview.get("location", ""))
	var party := _tab == "party" and location == PlayerCollection.LOCATION_PARTY
	var hospital := _tab == "hospital" and location == PlayerCollection.LOCATION_HOSPITAL
	var show_admit := party and bool(preview.get("can_admit", false))
	var show_recover := party and status in ["injured", "critical"] and int(preview.get("instant_cost", 0)) > 0
	var show_discharge := hospital and bool(preview.get("can_discharge", false))
	var visibility := {
		"admit": show_admit,
		"recover": show_recover,
		"discharge": show_discharge,
	}
	var action_mode := _interaction_mode == InteractionMode.ACTIONS and _confirmed_id == _preview_id
	for key in ["admit", "recover", "discharge"]:
		var button := _actions[key] as Button
		button.visible = bool(visibility[key])
		var allowed_key := "can_admit" if key == "admit" else ("can_recover_now" if key == "recover" else "can_discharge")
		var allowed := bool(preview.get(allowed_key, false))
		button.disabled = not action_mode or not allowed
		button.focus_mode = Control.FOCUS_ALL if button.visible and not button.disabled else Control.FOCUS_NONE
		_apply_action_state(key, button, action_mode, allowed, preview)


func _apply_action_state(key: String, button: Button, action_mode: bool, allowed: bool, preview: Dictionary) -> void:
	var title := button.find_child("Title", true, false) as Label
	var subtitle := button.find_child("Subtitle", true, false) as Label
	var state := button.find_child("DisabledState", true, false) as Label
	var icon := button.find_child("ActionIcon", true, false) as CanvasItem
	if subtitle != null:
		subtitle.text = String(button.get_meta("default_subtitle", subtitle.text))

	var unavailable := button.visible and action_mode and not allowed
	if state != null:
		state.visible = unavailable
	if unavailable:
		var insufficient_bits := key == "recover" and OverworldState.get_bits() < int(preview.get("instant_cost", 0))
		if state != null:
			state.text = "INSUFFICIENT BITS" if insufficient_bits else "UNAVAILABLE"
			state.add_theme_color_override("font_color", V2.AMBER if insufficient_bits else V2.MUTED)
			state.add_theme_stylebox_override("normal", V2.pill_style(V2.AMBER if insufficient_bits else V2.MUTED, false))
		if subtitle != null and insufficient_bits:
			subtitle.text = "Need %d more Bits" % maxi(0, int(preview.get("instant_cost", 0)) - OverworldState.get_bits())
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		if title != null:
			title.add_theme_color_override("font_color", V2.SUBTLE)
		if subtitle != null:
			subtitle.add_theme_color_override("font_color", V2.SUBTLE)
		if icon != null:
			icon.modulate = Color(0.45, 0.50, 0.55, 0.72)
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW
		if title != null:
			title.add_theme_color_override("font_color", V2.WHITE)
		if subtitle != null:
			subtitle.add_theme_color_override("font_color", V2.MUTED)
		if icon != null:
			icon.modulate = Color.WHITE


func _apply_density(compact: bool) -> void:
	super._apply_density(compact)
	_health_panel.custom_minimum_size.y = 94 if compact else 106
	_time_panel.custom_minimum_size.y = 50 if compact else 58
	_cost_panel.custom_minimum_size.y = 50 if compact else 58
	_overview_header.custom_minimum_size.y = 29 if compact else 34
	_overview_header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for button in _actions.values():
		var action := button as Button
		action.custom_minimum_size.y = 56 if compact else 64
		action.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
