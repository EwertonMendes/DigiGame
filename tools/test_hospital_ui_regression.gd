extends Node

const HospitalScreenScript = preload("res://src/ui/HospitalScreen.gd")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)

	var hospital := HospitalScreenScript.new() as HospitalScreen
	add_child(hospital)
	hospital.open_screen()
	await _frames(3)

	assert(hospital.visible, "Digi Hospital must open for the UI regression")
	assert(not hospital.is_action_mode_active(), "Digi Hospital must open in exploration mode")

	var tabs := hospital.get("_tab_buttons") as Dictionary
	var close_button := hospital.get("_close_button") as Button
	var page_back := hospital.get("_page_back") as Button
	var page_next := hospital.get("_page_next") as Button
	assert((tabs["party"] as Button).focus_mode == Control.FOCUS_NONE, "Party tab must stay out of D-pad focus navigation")
	assert((tabs["hospital"] as Button).focus_mode == Control.FOCUS_NONE, "Hospital tab must stay out of D-pad focus navigation")
	assert(close_button.focus_mode == Control.FOCUS_NONE, "Close X must stay out of D-pad focus navigation")
	assert(page_back.focus_mode == Control.FOCUS_NONE and page_next.focus_mode == Control.FOCUS_NONE, "Pagination arrows must stay out of D-pad focus navigation")

	var cards := hospital.get("_cards") as Dictionary
	assert(not cards.is_empty() and cards.size() <= 3, "Party patients must use paged cards without scrolling")
	for raw_card in cards.values():
		var card := raw_card as Button
		assert(card != null and card.focus_mode == Control.FOCUS_ALL, "Patient cards must be focusable content")
		var walk := card.find_child("WalkPreview", true, false) as DigimonWalkPreview
		assert(walk != null, "Every patient card must use the shared DS field-sprite preview")
		var field_sprite := walk.get_node_or_null("FieldSprite") as Sprite2D
		assert(field_sprite != null and field_sprite.texture != null, "Patient DS preview must resolve a packaged Digimon sprite")
		assert(card.find_child("Name", true, false) is Label, "Patient card must expose a dedicated name label")
		assert(card.find_child("Level", true, false) is Label, "Patient card must expose a dedicated level label")
		assert(card.find_child("Health", true, false) is Label, "Patient card must expose a dedicated HP label")
		assert(card.find_child("HpBar", true, false) is ProgressBar, "Patient card must expose a dedicated HP bar")
		assert(card.find_child("Status", true, false) is Label, "Patient card must expose a dedicated status chip")

	var tier_icon := hospital.get("_hero_tier_icon") as DigiTierIcon
	var hp_arrow := hospital.get("_health_arrow") as TextureRect
	var bits_badge := hospital.get("_header").get_node("BitsBadge") as Panel
	var bits_icon: TextureRect = null
	for child in bits_badge.get_children():
		if child is TextureRect:
			bits_icon = child as TextureRect
			break
	assert(tier_icon != null and tier_icon.texture != null, "Patient details must reuse the shared Tier artwork")
	assert(hp_arrow != null and hp_arrow.texture != null, "Health transition must use the packaged arrow asset")
	assert(bits_icon != null and bits_icon.texture != null, "Hospital header must use the packaged Bits icon")

	var party := OverworldState.get_active_instances()
	assert(not party.is_empty(), "Hospital UI regression requires a starter Party")
	var patient := party[0]
	var original_hp := patient.current_hp
	var preview := OverworldState.get_hospital_preview(patient.id)
	var max_hp := int(preview.get("max_hp", 1))
	patient.current_hp = maxi(0, max_hp - maxi(1, int(round(float(max_hp) * 0.25))))
	OverworldState.notify_collection_changed()
	await _frames(2)

	cards = hospital.get("_cards") as Dictionary
	assert(cards.has(patient.id), "Injured Party member must remain a treatment candidate")
	hospital.call("_preview_instance", patient.id)
	await _frames(1)

	var actions := hospital.get("_actions") as Dictionary
	var admit := actions["admit"] as Button
	var recover := actions["recover"] as Button
	var discharge := actions["discharge"] as Button
	assert(admit.visible and recover.visible, "Injured Party Digimon must expose Admit and Recover Now")
	assert(not discharge.visible, "Party Digimon must never expose Discharge")
	assert(admit.disabled and recover.disabled, "Treatment actions must not be interactive during exploration")
	assert(admit.focus_mode == Control.FOCUS_NONE and recover.focus_mode == Control.FOCUS_NONE, "Exploration mode must keep treatment actions out of focus navigation")

	var first_card := cards[patient.id] as Button
	first_card.grab_focus()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	hospital.call("_input", down)
	await _frames(2)
	var explored_focus := get_viewport().gui_get_focus_owner()
	assert(explored_focus is Button and (hospital.get("_cards") as Dictionary).values().has(explored_focus), "D-pad exploration must remain exclusively on patient cards")
	assert(explored_focus != tabs["party"] and explored_focus != tabs["hospital"] and explored_focus != close_button, "D-pad must never route to tabs or the close X")

	# Return to the injured patient and confirm it explicitly. Preview/highlight and
	# action selection are intentionally separate states.
	hospital.call("_preview_instance", patient.id)
	hospital.call("_confirm_instance", patient.id)
	await _frames(2)
	assert(hospital.is_action_mode_active(), "Confirming a patient must enter action mode")
	assert(not admit.disabled and admit.focus_mode == Control.FOCUS_ALL, "Valid Admit action must become interactive only after confirmation")
	assert(get_viewport().gui_get_focus_owner() == admit, "Action mode must focus the first valid treatment action")

	var focused_before_refresh := get_viewport().gui_get_focus_owner()
	hospital.call("_refresh_live")
	await _frames(1)
	assert(get_viewport().gui_get_focus_owner() == focused_before_refresh, "Live recovery/status refresh must not steal action focus")

	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	hospital.call("_input", back)
	await _frames(2)
	assert(hospital.visible and not hospital.is_action_mode_active(), "Back from actions must return to exploration without closing the Hospital")
	assert(get_viewport().gui_get_focus_owner() == (hospital.get("_cards") as Dictionary)[patient.id], "Back from actions must restore focus to the same patient card")

	# Dedicated shoulder buttons change tabs; tabs themselves remain out of the
	# directional focus path.
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	hospital.call("_input", rb)
	await _frames(2)
	assert(String(hospital.get("_tab")) == "hospital", "RB must switch to the Hospital tab")
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	hospital.call("_input", lb)
	await _frames(2)
	assert(String(hospital.get("_tab")) == "party", "LB must switch back to the Party tab")

	# Admit through the production service so the Hospital tab can verify that its
	# presentation does not expose Party-only actions.
	var admission := OverworldState.admit_to_hospital(patient.id)
	assert(bool(admission.get("success", false)), "UI regression must be able to admit the injured test patient")
	await _frames(2)
	hospital.call("_switch_tab", "hospital")
	await _frames(2)
	actions = hospital.get("_actions") as Dictionary
	admit = actions["admit"] as Button
	recover = actions["recover"] as Button
	discharge = actions["discharge"] as Button
	assert(not admit.visible and not recover.visible, "Hospital patients must hide Party-only Admit and Recover Now actions")
	assert(not discharge.visible, "Recovering patient must not expose Discharge before treatment completes")

	# Mark the same admitted patient ready without changing the service rules.
	patient.current_hp = max_hp
	assert(patient.complete_hospital_recovery(int(Time.get_unix_time_from_system())), "Test patient must retain a valid hospital recovery interval")
	OverworldState.notify_collection_changed()
	await _frames(2)
	assert(not admit.visible and not recover.visible, "Ready Hospital patient must still hide Party-only actions")
	assert(discharge.visible, "Ready Hospital patient must expose Discharge")

	# Shared hint bar must follow the last meaningful input type. Hospital opts out
	# of scroll hints and hides all control legends for touch.
	var footer := hospital.get("_footer") as DigiInputHintBar
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	footer.call("_input", touch)
	assert(footer.is_touch_mode(), "Touch input must become the active Hospital input mode")
	assert((footer.call("_menu_hints") as Array).is_empty(), "Touch mode must hide Hospital control hints")
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_ENTER
	keyboard.pressed = true
	footer.call("_input", keyboard)
	var keyboard_hints := footer.call("_menu_hints") as Array
	assert(not keyboard_hints.is_empty() and _hint_keys(keyboard_hints).has("TAB"), "Keyboard/mouse mode must expose its own Hospital commands")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_A
	controller.pressed = true
	footer.call("_input", controller)
	var controller_keys := _hint_keys(footer.call("_menu_hints") as Array)
	assert(controller_keys.has("LB/RB") and controller_keys.has("D-PAD") and controller_keys.has("A") and controller_keys.has("B"), "Controller hints must expose tabs, navigation, select and back")
	assert(not controller_keys.has("RS"), "Hospital footer must not advertise scrolling")

	var cleanup := OverworldState.discharge_from_hospital(patient.id)
	assert(bool(cleanup.get("success", false)), "Ready test patient must discharge cleanly")
	patient.current_hp = original_hp
	OverworldState.notify_collection_changed()
	await _frames(2)

	# Once already back in exploration, Back closes the screen.
	hospital.call("_switch_tab", "party")
	await _frames(1)
	hospital.call("_input", back)
	await _frames(2)
	assert(not hospital.visible, "Back from the patient list must close the Digi Hospital")

	hospital.queue_free()
	await _frames(4)
	OverworldState.set_persistence_enabled(true)
	print("hospital ui regression passed")
	get_tree().quit()


func _hint_keys(hints: Array) -> Array[String]:
	var result: Array[String] = []
	for hint in hints:
		result.append(String((hint as Dictionary).get("key", "")))
	return result


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
