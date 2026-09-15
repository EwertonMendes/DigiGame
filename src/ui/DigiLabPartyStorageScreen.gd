extends PartyStorageScreen
class_name DigiLabPartyStorageScreen

const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")


func open_screen() -> void:
	super.open_screen()
	_header.configure_tabs(PrimaryTabs.specs(), "party")
	_header.set_active_tab("party")
	_hint_bar.set_primary_tabs_enabled(true)


func _on_top_tab_selected(tab_id: String) -> void:
	if tab_id != "party":
		tab_requested.emit(tab_id)


func get_selected_instance_id() -> String:
	return _selected_id
