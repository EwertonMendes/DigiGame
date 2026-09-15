extends ProgressionDigiLabCreateScreen
class_name DigiLabConvertScreen

const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")
const AssetIcons = preload("res://src/ui/components/DigiUiAssetIcons.gd")


func open_lab() -> void:
	super.open_lab()
	AssetIcons.apply_bits_icon(_header)
	_header.configure_tabs(PrimaryTabs.specs(), "convert")
	_header.set_active_tab("convert")
	_hint_bar.set_primary_tabs_enabled(true)
	var ascension_handler := Callable(self, "_on_ascension_tab_selected")
	if not _header.tab_selected.is_connected(ascension_handler):
		_header.tab_selected.connect(ascension_handler)


func _on_ascension_tab_selected(tab_id: String) -> void:
	if tab_id == "ascension":
		tab_requested.emit("ascension")
