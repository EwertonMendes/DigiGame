extends "res://src/ui/HospitalScreen.gd"

# Presentation/input refinement for the Digi Hospital. Domain actions remain in
# HospitalScreen/OverworldState; this layer owns the final interaction polish.

const CommandButtonStyle = preload("res://src/ui/components/DigiCommandButtonStyle.gd")
const PATIENT_CARD_HEIGHT := 132.0
const PATIENT_STATUS_TOP_GAP := 4
const ANALOG_NAV_PRESS_THRESHOLD := 0.62
const ANALOG_NAV_RELEASE_THRESHOLD := 0.34
const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.25
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")

var _pointer_patient_selection := false
var _analog_nav_state := 0
var _left_trigger_down := false
var _right_trigger_down := false
var _right_analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate


func open_screen() -> void:
	_analog_nav_state = 0
	_left_trigger_down = false
	_right_trigger_down = false
	_right_analog_gate.reset()
	super.open_screen()


func _input(event: InputEvent) -> void:
	if not visible or _confirmation.visible:
		super._input(event)
		return

	# Joypad motion needs explicit edge handling. Letting generic ui_up/ui_down
	# consume every axis-motion event makes a held stick race through the roster.
	# We intentionally require the stick to cross the press threshold and return
	# through the release threshold before another move is accepted.
	if event is InputEventJoypadMotion:
		_handle_joypad_motion(event as InputEventJoypadMotion)
		return

	# Both the patient list and the action list are vertical. Horizontal arrows /
	# D-pad directions are therefore inert instead of behaving like duplicate up
	# and down inputs.
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		return

	super._input(event)


func _handle_joypad_motion(event: InputEventJoypadMotion) -> void:
	match event.axis:
		JOY_AXIS_LEFT_Y:
			_handle_analog_vertical(event.axis_value)
		JOY_AXIS_RIGHT_Y:
			var step := _right_analog_gate.vertical_step(event.axis_value)
			if step != 0:
				if _interaction_mode == InteractionMode.ACTIONS:
					_move_action_focus(step)
				else:
					_move_preview(step)
		JOY_AXIS_TRIGGER_LEFT:
			_handle_page_trigger(event.axis_value, -1, true)
		JOY_AXIS_TRIGGER_RIGHT:
			_handle_page_trigger(event.axis_value, 1, false)
		_:
			# Other axes do not navigate this screen. In particular, horizontal
			# left-stick motion and the right stick must not move vertical lists.
			pass
	get_viewport().set_input_as_handled()


func _handle_analog_vertical(value: float) -> void:
	if absf(value) <= ANALOG_NAV_RELEASE_THRESHOLD:
		_analog_nav_state = 0
		return

	var direction := 0
	if value <= -ANALOG_NAV_PRESS_THRESHOLD:
		direction = -1
	elif value >= ANALOG_NAV_PRESS_THRESHOLD:
		direction = 1
	if direction == 0 or direction == _analog_nav_state:
		return

	_analog_nav_state = direction
	if _interaction_mode == InteractionMode.ACTIONS:
		_move_action_focus(direction)
	else:
		_move_preview(direction)
	get_viewport().set_input_as_handled()


func _handle_page_trigger(value: float, direction: int, left_trigger: bool) -> void:
	var was_down := _left_trigger_down if left_trigger else _right_trigger_down
	if not was_down and value >= TRIGGER_PRESS_THRESHOLD:
		if left_trigger:
			_left_trigger_down = true
		else:
			_right_trigger_down = true
		_turn_page(direction)
		get_viewport().set_input_as_handled()
		return

	if was_down and value <= TRIGGER_RELEASE_THRESHOLD:
		if left_trigger:
			_left_trigger_down = false
		else:
			_right_trigger_down = false


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


func _build_hero() -> void:
	super._build_hero()
	var meta := _hero.find_child("PatientMeta", true, false) as HBoxContainer
	if meta == null or _hero_status == null:
		return

	# Rank and level stay visible before the health-state chip on the same line.
	# Give the metadata label an authored minimum width so the expanding spacer
	# can never collapse it away when the row is laid out.
	_hero_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hero_info.custom_minimum_size = Vector2(190, 28)
	_hero_info.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Health state belongs to the same semantic line as rank/level/tier. Keeping
	# it here also frees the portrait area from a dedicated status row.
	var previous_parent := _hero_status.get_parent()
	if previous_parent != null:
		previous_parent.remove_child(_hero_status)
	meta.add_child(_hero_status)
	meta.move_child(_hero_status, _hero_info.get_index() + 1)
	meta.add_theme_constant_override("separation", 10)
	_hero_status.custom_minimum_size = Vector2(0, 28)
	_hero_status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hero_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_status.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	var spacer := Control.new()
	spacer.name = "PatientMetaSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(spacer)
	meta.move_child(spacer, _hero_status.get_index() + 1)

	# The tier artwork already communicates the tier. Hiding the redundant caption
	# and location keeps Rank · Level · Status · Tier on one clean responsive row.
	for child in meta.get_children():
		if child is Label and child != _hero_info and child != _hero_status:
			var label := child as Label
			if label.text == "Tier":
				label.visible = false
	_hero_location.visible = false


func _build_overview() -> void:
	super._build_overview()
	_overview_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_overview_header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _build_footer() -> void:
	super._build_footer()
	_footer.set_pagination_enabled(false)


func _information_panel(parent: Node, node_name: String, accent: Color, minimum_height: float) -> PanelContainer:
	var panel := super._information_panel(parent, node_name, accent, minimum_height)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return panel


func _rebuild_cards() -> void:
	super._rebuild_cards()

	# Re-assert the authored slot sizing only after the buttons are parented into
	# the VBox. This keeps one/two-card pages from receiving spare vertical space,
	# prevents the third card from colliding with the pager/footer, and leaves the
	# unused part of the roster deliberately empty.
	_card_area.alignment = BoxContainer.ALIGNMENT_BEGIN
	_card_area.clip_contents = true
	for card in _card_order:
		card.custom_minimum_size.y = PATIENT_CARD_HEIGHT
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.size_flags_stretch_ratio = 0.0

	if _footer != null:
		_footer.set_pagination_enabled(_current_roster().size() > _page_capacity())


func _create_patient_card(instance: DigimonInstance) -> Button:
	var card := super._create_patient_card(instance)
	# Pages are designed around three authored cards. The slightly taller slot
	# keeps the status chip completely inside the card while still fitting three
	# patients comfortably above the pager.
	card.custom_minimum_size.y = PATIENT_CARD_HEIGHT
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.size_flags_stretch_ratio = 0.0
	card.gui_input.connect(_on_patient_card_gui_input.bind(instance.id))

	# The status chip needs breathing space after the HP bar. A margin container
	# expresses that spacing structurally while keeping the card content grouped.
	var info := card.find_child("CardInfo", true, false) as VBoxContainer
	var status := card.find_child("Status", true, false) as Label
	if info != null and status != null and status.get_parent() == info:
		var status_index := status.get_index()
		info.remove_child(status)
		var status_spacing := MarginContainer.new()
		status_spacing.name = "StatusSpacing"
		status_spacing.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		status_spacing.add_theme_constant_override("margin_top", PATIENT_STATUS_TOP_GAP)
		status_spacing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(status_spacing)
		info.move_child(status_spacing, status_index)
		status_spacing.add_child(status)
		status.custom_minimum_size.y = 25
	return card


func _refresh_detail() -> void:
	super._refresh_detail()

	# Keep rank and level explicitly authored in this refined metadata row rather
	# than relying on the legacy separator string from the base screen.
	var instance := OverworldState.get_instance_by_id(_preview_id)
	if instance != null and _hero_info != null:
		var species := _database.get_by_seed(instance.species_seed)
		var rank := String(species.get("rank", "Unknown")).strip_edges()
		if rank.is_empty():
			rank = "Unknown"
		_hero_info.visible = true
		_hero_info.text = "%s   ·   LV. %d" % [rank.to_upper(), instance.level]
		_hero_info.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Instant Recovery is a Party decision. Once a Digimon is admitted, the paid
	# instant-recovery option is no longer relevant to the Hospital-side summary.
	if _cost_panel != null:
		_cost_panel.visible = _tab == "party"


func _move_preview(direction: int) -> void:
	# Navigation is intentionally page-local. Moving beyond either edge wraps to
	# the opposite edge of the same visible page; LT/RT are the only controller
	# inputs that change pages.
	if _card_order.is_empty():
		return

	var current := -1
	for i in range(_card_order.size()):
		if String(_card_order[i].get_meta("instance_id", "")) == _preview_id:
			current = i
			break
	if current < 0:
		current = 0

	var next := current + direction
	if next < 0:
		next = _card_order.size() - 1
	elif next >= _card_order.size():
		next = 0
	if next == current:
		return

	_preview_id = String(_card_order[next].get_meta("instance_id", ""))
	_notice = ""
	_refresh_card_highlights()
	_refresh_detail()
	call_deferred("_focus_preview_card")


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


func _status_color(status: String) -> Color:
	match status:
		"injured": return V2.AMBER
		"critical": return V2.RED
		"recovering": return V2.CYAN
		"ready", "healthy": return V2.GREEN
		_: return V2.MUTED


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
	# Centralised, reusable command styling keeps action buttons visibly distinct
	# from informational cards without duplicating state-specific paint logic.
	return CommandButtonStyle.style(accent, state)


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
	var disabled_visual := button.visible and button.disabled
	if state != null:
		state.visible = unavailable
	if disabled_visual:
		var insufficient_bits := unavailable and key == "recover" and OverworldState.get_bits() < int(preview.get("instant_cost", 0))
		if state != null and unavailable:
			state.text = "INSUFFICIENT BITS" if insufficient_bits else "UNAVAILABLE"
			state.add_theme_color_override("font_color", V2.AMBER if insufficient_bits else V2.MUTED)
			state.add_theme_stylebox_override("normal", V2.pill_style(V2.AMBER if insufficient_bits else V2.MUTED, false))
		if subtitle != null and insufficient_bits:
			subtitle.text = "Need %d more Bits" % maxi(0, int(preview.get("instant_cost", 0)) - OverworldState.get_bits())
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if unavailable else Control.CURSOR_ARROW
		if title != null:
			title.add_theme_color_override("font_color", V2.SUBTLE)
		if subtitle != null:
			subtitle.add_theme_color_override("font_color", V2.SUBTLE)
		if icon != null:
			icon.modulate = Color(0.45, 0.50, 0.55, 0.72)
	else:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if title != null:
			title.add_theme_color_override("font_color", V2.WHITE)
		if subtitle != null:
			subtitle.add_theme_color_override("font_color", V2.MUTED)
		if icon != null:
			icon.modulate = Color.WHITE


func _apply_density(compact: bool) -> void:
	super._apply_density(compact)
	_health_panel.custom_minimum_size.y = 110 if compact else 120
	_time_panel.custom_minimum_size.y = 50 if compact else 58
	_cost_panel.custom_minimum_size.y = 50 if compact else 58
	_overview_header.custom_minimum_size.y = 29 if compact else 34
	_overview_header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for button in _actions.values():
		var action := button as Button
		action.custom_minimum_size.y = 56 if compact else 64
		action.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
