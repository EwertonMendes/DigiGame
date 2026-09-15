extends Control
class_name DigiLabHubScreen

signal close_requested

const CreateScreenScript = preload("res://src/ui/DigiLabConvertScreen.gd")
const PartyStorageScript = preload("res://src/ui/DigiIconPartyStorageScreen.gd")
const AscensionExpansionScript = preload("res://src/ui/DigiIconAscensionExpansionScreen.gd")

var _create_screen: DigiLabConvertScreen
var _party_screen: DigiLabPartyStorageScreen
var _ascension_screen: AscensionExpansionScreen
var _active_tab := "convert"
var _pending_ascension_instance_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	_create_screen = CreateScreenScript.new() as DigiLabConvertScreen
	_create_screen.name = "ConvertDigiData"
	_create_screen.visible = false
	_create_screen.close_requested.connect(close_view)
	_create_screen.tab_requested.connect(_switch_tab)
	add_child(_create_screen)

	_party_screen = PartyStorageScript.new() as DigiLabPartyStorageScreen
	_party_screen.name = "PartyStorage"
	_party_screen.visible = false
	_party_screen.close_requested.connect(close_view)
	_party_screen.tab_requested.connect(_switch_tab)
	_party_screen.ascension_requested.connect(_open_ascension)
	add_child(_party_screen)

	_ascension_screen = AscensionExpansionScript.new() as AscensionExpansionScreen
	_ascension_screen.name = "AscensionExpansion"
	_ascension_screen.visible = false
	_ascension_screen.close_requested.connect(close_view)
	_ascension_screen.tab_requested.connect(_switch_tab)
	add_child(_ascension_screen)


func open_lab() -> void:
	visible = true
	_switch_tab(_active_tab, true)


func close_view() -> void:
	_pending_ascension_instance_id = ""
	_hide_screens()
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func _switch_tab(tab_id: String, force: bool = false) -> void:
	var next_tab := tab_id if tab_id in ["convert", "party", "ascension"] else "convert"
	if next_tab == "ascension" and _pending_ascension_instance_id.is_empty() and _active_tab == "party" and _party_screen != null:
		_pending_ascension_instance_id = _party_screen.get_selected_instance_id()
	elif next_tab != "ascension":
		_pending_ascension_instance_id = ""
	if not force and next_tab == _active_tab:
		return
	_active_tab = next_tab
	_hide_screens()
	if visible:
		_open_active_workspace()


func _open_active_workspace() -> void:
	match _active_tab:
		"party":
			_party_screen.open_screen()
		"ascension":
			var preferred_id := _pending_ascension_instance_id
			_pending_ascension_instance_id = ""
			_ascension_screen.open_screen(preferred_id)
		_:
			_create_screen.open_lab()


func _open_ascension() -> void:
	if not visible or _ascension_screen == null:
		return
	if _party_screen != null:
		_pending_ascension_instance_id = _party_screen.get_selected_instance_id()
	_switch_tab("ascension", true)


func _hide_screens() -> void:
	if _create_screen != null:
		_create_screen.visible = false
	if _party_screen != null:
		_party_screen.visible = false
	if _ascension_screen != null:
		_ascension_screen.visible = false
