extends CanvasLayer

@onready var debug_button: Button = $Root/DebugButton

func _ready() -> void:
	debug_button.button_pressed = GlobalVariables.DebugMode
	debug_button.toggled.connect(_on_debug_toggled)
	_refresh_label()

func _on_debug_toggled(enabled: bool) -> void:
	GlobalVariables.DebugMode = enabled
	_refresh_label()

func _refresh_label() -> void:
	debug_button.text = "DEBUG: ON" if GlobalVariables.DebugMode else "DEBUG: OFF"
