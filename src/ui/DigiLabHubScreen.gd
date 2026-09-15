extends Control
class_name DigiLabHubScreen

signal close_requested

const CreateScreenScript = preload("res://src/ui/ProgressionDigiLabCreateScreen.gd")
const PartyStorageScript = preload("res://src/ui/PartyStorageScreen.gd")

var _create_screen: DigiLabScreen
var _party_screen: PartyStorageScreen
var _active_tab := "convert"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	_create_screen = CreateScreenScript.new() as DigiLabScreen
	_create_screen.name = "ConvertDigiData"
	_create_screen.visible = false
	_create_screen.close_requested.connect(close_view)
	_create_screen.tab_requested.connect(_switch_tab)
	add_child(_create_screen)

	_party_screen = PartyStorageScript.new() as PartyStorageScreen
	_party_screen.name = "PartyStorage"
	_party_screen.visible = false
	_party_screen.close_requested.connect(close_view)
	_party_screen.tab_requested.connect(_switch_tab)
	add_child(_party_screen)


func open_lab() -> void:
	visible = true
	_switch_tab(_active_tab, true)


func close_view() -> void:
	_hide_screens()
	visible = false
	close_requested.emit()


func is_open() -> bool:
	return visible


func _switch_tab(tab_id: String, force: bool = false) -> void:
	var next_tab := tab_id if tab_id in ["convert", "party"] else "convert"
	if not force and next_tab == _active_tab:
		return
	_active_tab = next_tab
	_hide_screens()
	if not visible:
		return
	if _active_tab == "party":
		_party_screen.open_screen()
	else:
		_create_screen.open_lab()


func _hide_screens() -> void:
	if _create_screen != null:
		_create_screen.visible = false
	if _party_screen != null:
		_party_screen.visible = false
