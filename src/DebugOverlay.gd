extends CanvasLayer

@onready var debug_button: Button = $Root/DebugButton
@onready var zoom_out_button: Button = $Root/ZoomOutButton
@onready var zoom_in_button: Button = $Root/ZoomInButton
@onready var center_button: Button = $Root/CenterButton

var _camera: Camera2D

func _ready() -> void:
	_camera = get_tree().root.get_node_or_null("Main/DigimonController/MainCamera") as Camera2D
	debug_button.button_pressed = GlobalVariables.DebugMode
	debug_button.toggled.connect(_on_debug_toggled)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	center_button.pressed.connect(_on_center_pressed)
	_refresh_label()

func _on_debug_toggled(enabled: bool) -> void:
	GlobalVariables.DebugMode = enabled
	_refresh_label()

func _on_zoom_out_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_out"):
		_camera.call("zoom_out")

func _on_zoom_in_pressed() -> void:
	if _camera != null and _camera.has_method("zoom_in"):
		_camera.call("zoom_in")

func _on_center_pressed() -> void:
	if _camera != null and _camera.has_method("reset_view"):
		_camera.call("reset_view")

func _refresh_label() -> void:
	debug_button.text = "DEBUG: ON" if GlobalVariables.DebugMode else "DEBUG: OFF"
