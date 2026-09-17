extends "res://src/ui/DigiWorkspaceProgressionMenu.gd"
class_name DigiSystemProgressionMenu

const SystemPanelScript = preload("res://src/ui/components/DigiSystemSettingsPanel.gd")

var _system_panel: DigiSystemSettingsPanel


func _build() -> void:
	super._build()
	_system_panel = SystemPanelScript.new() as DigiSystemSettingsPanel
	_system_panel.name = "SystemSettings"
	_system_panel.visible = false
	_menu_root.add_child(_system_panel)


func _input(event: InputEvent) -> void:
	if visible and _main_tab == "system" and _system_panel != null and _system_panel.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _set_main_tab(tab_id: String) -> void:
	super._set_main_tab(tab_id)
	if _main_tab == "system" and _system_panel != null:
		call_deferred("_focus_system_settings")


func _sync_main_tab_visibility() -> void:
	super._sync_main_tab_visibility()
	if _system_panel == null or _soon_label == null:
		return
	_system_panel.visible = _main_tab == "system"
	_soon_label.visible = _main_tab == "digipedia"


func _update_footer_hints() -> void:
	super._update_footer_hints()
	if _hint_bar != null and _main_tab == "system":
		_hint_bar.set_description("")


func _layout() -> void:
	super._layout()
	if _system_panel == null or _soon_label == null:
		return
	_system_panel.position = _soon_label.position
	_system_panel.size = _soon_label.size
	_system_panel.set_compact(_density_compact)
	_sync_main_tab_visibility()


func has_nested_view_open() -> bool:
	return _main_tab != "party" or super.has_nested_view_open()


func _focus_system_settings() -> void:
	if _main_tab == "system" and _system_panel != null and _system_panel.visible:
		_system_panel.focus_default()
