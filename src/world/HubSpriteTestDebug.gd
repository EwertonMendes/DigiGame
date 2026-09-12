extends Node
class_name HubSpriteTestDebug

const UI = preload("res://src/ui/TacticalTheme.gd")
const SpriteTestLabScript = preload("res://src/ui/DigimonSpriteTestLab.gd")

var _layer: CanvasLayer
var _button: Button
var _lab: DigimonSpriteTestLab
var _open := false


func _ready() -> void:
	call_deferred("_build_debug_ui")


func _build_debug_ui() -> void:
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.name = "SpriteTestDebugUI"
	_layer.layer = 80
	add_child(_layer)

	_button = Button.new()
	_button.name = "SpriteTestButton"
	_button.text = "SPRITE TEST"
	_button.tooltip_text = "Temporary developer tool for validating Digimon field sprites."
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.add_theme_font_size_override("font_size", 12)
	_button.add_theme_color_override("font_color", UI.TEXT)
	_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_button.add_theme_stylebox_override("normal", UI.action_style(UI.PURPLE, "normal"))
	_button.add_theme_stylebox_override("hover", UI.action_style(UI.PURPLE, "hover"))
	_button.add_theme_stylebox_override("pressed", UI.action_style(UI.PURPLE, "pressed"))
	_button.pressed.connect(_open_lab)
	_layer.add_child(_button)

	_lab = SpriteTestLabScript.new() as DigimonSpriteTestLab
	_lab.name = "DigimonSpriteTestLab"
	_lab.close_requested.connect(_close_lab)
	_layer.add_child(_lab)

	get_viewport().size_changed.connect(_layout_button)
	_layout_button()


func _open_lab() -> void:
	if _open or _lab == null:
		return
	var hub := get_parent()
	if bool(hub.get("_transitioning")) or bool(hub.get("_dialog_open")):
		return
	_open = true
	_button.visible = false
	var player = hub.get("_player")
	if player != null:
		player.set("movement_enabled", false)
		player.set("velocity", Vector2.ZERO)
	_lab.open_lab()


func _close_lab() -> void:
	if not _open:
		return
	_open = false
	var hub := get_parent()
	var player = hub.get("_player")
	if player != null:
		var can_move := not bool(hub.get("_transitioning")) and not bool(hub.get("_dialog_open"))
		player.set("movement_enabled", can_move)
	_button.visible = true
	_layout_button()


func _layout_button() -> void:
	if _button == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var scale_factor := UI.ui_scale(viewport_obj)
	_button.scale = Vector2.ONE * scale_factor
	_button.size = Vector2(142.0, 40.0)
	_button.position = Vector2(maxf(12.0, physical.x - 160.0), 18.0) * scale_factor
