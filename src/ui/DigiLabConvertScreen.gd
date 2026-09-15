extends ProgressionDigiLabCreateScreen
class_name DigiLabConvertScreen

const PrimaryTabs = preload("res://src/ui/components/DigiLabPrimaryTabs.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")
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


func _refresh_detail() -> void:
	super._refresh_detail()
	if _lab_mode == "records" or _selected_name.is_empty() or _detail_body == null:
		return
	var species := _database.get_by_name(_selected_name)
	if species.is_empty():
		return
	var rank := String(species.get("rank", "Unknown"))
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	AttributeChip.replace_text_pill(_detail_body, attribute)
	AttributeChip.normalize_text_pill_height(_detail_body, rank.to_upper())
	AttributeChip.normalize_text_pill_height(_detail_body, attribute.to_upper())
	AttributeChip.normalize_text_pill_height(_detail_body, family.to_upper())


func _on_ascension_tab_selected(tab_id: String) -> void:
	if tab_id == "ascension":
		tab_requested.emit("ascension")
