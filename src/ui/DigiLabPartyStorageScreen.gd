extends PartyStorageScreen
class_name DigiLabPartyStorageScreen

const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")


func open_screen() -> void:
	super.open_screen()
	_header.configure_tabs(PrimaryTabs.specs(), "party")
	_header.set_active_tab("party")
	_hint_bar.set_primary_tabs_enabled(true)
	var ascension_handler := Callable(self, "_on_ascension_tab_selected")
	if not _header.tab_selected.is_connected(ascension_handler):
		_header.tab_selected.connect(ascension_handler)


func _on_ascension_tab_selected(tab_id: String) -> void:
	if tab_id == "ascension":
		tab_requested.emit("ascension")


func get_selected_instance_id() -> String:
	return _selected_id
