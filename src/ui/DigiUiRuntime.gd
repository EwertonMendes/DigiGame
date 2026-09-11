extends Node

# Runtime presentation layer for DigiGame UI.
#
# Kenney Fantasy UI Borders stays structurally faithful to the source artwork:
# normal surfaces use the original frame geometry tinted to the dark slate seen
# in Kenney's dark presentation, while focused/selected states reuse that same
# geometry in DigiGame orange. No glow, blur, gradients or satin decoration.

const UI = preload("res://src/ui/TacticalTheme.gd")
const FRAME_PATH := "res://assets/ui/kenney_fantasy_digi/frame_original.svg"
const BORDER_ONLY_PATH := "res://assets/ui/kenney_fantasy_digi/panel-border-000.png"

const STANDARD_PANELS := [
	"LocationPanel",
	"CommandRail",
	"ActiveUnitStatus",
	"TechniqueMenu",
	"ActionPreview",
	"BattleResult",
	"BattleDialog",
	"RetreatPanel",
	"RetreatResult",
]

# These surfaces only exist while the player is being actively prompted or is
# inspecting something, so an orange frame is meaningful rather than decorative.
const ACCENT_PANELS := [
	"InteractionPrompt",
	"RetreatAnnouncement",
	"DigimonContextCard",
]

const DIALOG_ANCESTORS := [
	"BattleDialog",
	"RetreatPanel",
	"RetreatResult",
	"BattleResult",
]

const FRAMED_BUTTON_NAMES := [
	"StartBattle",
	"CancelBattleDialog",
	"Cancel",
	"ConfirmFlee",
	"CancelFlee",
	"ReturnAfterRetreat",
	"ReturnToHub",
	"Talk",
]

var _frame_texture: Texture2D = null
var _border_only_texture: Texture2D = null
var _panel_dark_style: StyleBoxTexture = null
var _panel_accent_style: StyleBoxTexture = null
var _button_dark_style: StyleBoxTexture = null
var _button_accent_style: StyleBoxTexture = null
var _button_focus_overlay: StyleBoxTexture = null
var _button_disabled_style: StyleBoxTexture = null
var _tracked_panels: Dictionary = {}
var _restyle_elapsed := 0.0
var _skin_ready := false


func _ready() -> void:
	_load_skin_resources()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_decorate_existing_tree")
	set_process(true)


func _process(delta: float) -> void:
	if not _skin_ready or _tracked_panels.is_empty():
		return
	_restyle_elapsed += delta
	if _restyle_elapsed < 0.10:
		return
	_restyle_elapsed = 0.0
	var stale_ids: Array[int] = []
	for raw_id: Variant in _tracked_panels.keys():
		var instance_id := int(raw_id)
		var entry: Dictionary = _tracked_panels.get(instance_id, {}) as Dictionary
		var ref: WeakRef = entry.get("ref") as WeakRef
		var panel: Control = ref.get_ref() as Control if ref != null else null
		if panel == null or not is_instance_valid(panel):
			stale_ids.append(instance_id)
			continue
		var accented := bool(entry.get("accented", false))
		var desired: StyleBoxTexture = _panel_accent_style if accented else _panel_dark_style
		if panel.get_theme_stylebox("panel") != desired:
			panel.add_theme_stylebox_override("panel", desired)
	for instance_id: int in stale_ids:
		_tracked_panels.erase(instance_id)


func _load_skin_resources() -> void:
	_frame_texture = load(FRAME_PATH) as Texture2D
	_border_only_texture = load(BORDER_ONLY_PATH) as Texture2D
	_skin_ready = _frame_texture != null and _border_only_texture != null
	if not _skin_ready:
		push_warning("Kenney dark UI resources could not be loaded; keeping TacticalTheme fallbacks.")
		return

	# 12px preserves every original corner ornament outside the stretch region.
	# Panel content margins remain zero because each HUD owns its own layout.
	var margins := Vector4(12.0, 12.0, 12.0, 12.0)
	var panel_content := Vector4.ZERO
	_panel_dark_style = _nine_patch(_frame_texture, margins, panel_content, UI.FRAME_DARK)
	_panel_accent_style = _nine_patch(_frame_texture, margins, panel_content, UI.GOLD)
	_button_dark_style = _nine_patch(
		_frame_texture,
		margins,
		Vector4(16.0, 9.0, 16.0, 9.0),
		UI.FRAME_DARK
	)
	_button_accent_style = _nine_patch(
		_frame_texture,
		margins,
		Vector4(16.0, 9.0, 16.0, 9.0),
		UI.GOLD
	)
	# Focus is drawn as an overlay by Godot. Using Kenney's exact border-only PNG
	# avoids doubling the dark backing while still giving selected controls the
	# precise orange source silhouette requested for the game.
	_button_focus_overlay = _nine_patch(
		_border_only_texture,
		margins,
		Vector4.ZERO,
		UI.GOLD
	)
	_button_disabled_style = _nine_patch(
		_frame_texture,
		margins,
		Vector4(16.0, 9.0, 16.0, 9.0),
		Color(UI.FRAME_DARK.r, UI.FRAME_DARK.g, UI.FRAME_DARK.b, 0.42)
	)


func _decorate_existing_tree() -> void:
	if not _skin_ready:
		return
	var scene: Node = get_tree().current_scene
	if scene != null:
		_decorate_branch(scene)


func _decorate_branch(node: Node) -> void:
	_decorate_node(node)
	for child: Node in node.get_children():
		_decorate_branch(child)


func _on_node_added(node: Node) -> void:
	if _skin_ready:
		call_deferred("_decorate_node", node)


func _decorate_node(node: Node) -> void:
	if not _skin_ready or not is_instance_valid(node) or not node is Control:
		return
	var control: Control = node as Control
	if control.has_meta("digi_fantasy_skin_applied"):
		return

	if control is Panel or control is PanelContainer:
		var panel_name := String(control.name)
		if panel_name in ACCENT_PANELS:
			_style_panel(control, true)
			control.set_meta("digi_fantasy_skin_applied", true)
			return
		if panel_name in STANDARD_PANELS:
			_style_panel(control, false)
			control.set_meta("digi_fantasy_skin_applied", true)
			return

	if control is Button:
		var button := control as Button
		if _should_frame_button(button):
			_style_related_result_panel(button)
			_style_dialog_button(button)
			control.set_meta("digi_fantasy_skin_applied", true)


func _style_panel(control: Control, accented: bool) -> void:
	var style: StyleBoxTexture = _panel_accent_style if accented else _panel_dark_style
	control.add_theme_stylebox_override("panel", style)
	_tracked_panels[control.get_instance_id()] = {
		"ref": weakref(control),
		"accented": accented,
	}


func _should_frame_button(button: Button) -> bool:
	if String(button.name) in FRAMED_BUTTON_NAMES:
		return true
	var parent: Node = button.get_parent()
	while parent != null:
		if String(parent.name) in DIALOG_ANCESTORS:
			return true
		parent = parent.get_parent()
	return false


func _style_related_result_panel(button: Button) -> void:
	if String(button.name) != "ReturnToHub":
		return
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is Panel or parent is PanelContainer:
			var panel := parent as Control
			if not panel.has_meta("digi_fantasy_skin_applied"):
				_style_panel(panel, false)
				panel.set_meta("digi_fantasy_skin_applied", true)
			return
		parent = parent.get_parent()


func _style_dialog_button(button: Button) -> void:
	# Match Kenney's sample behavior: resting controls are dark and only the
	# hovered/focused/pressed control receives the bright border. DigiGame uses
	# orange instead of white for that selected-state frame.
	button.add_theme_stylebox_override("normal", _button_dark_style)
	button.add_theme_stylebox_override("hover", _button_accent_style)
	button.add_theme_stylebox_override("focus", _button_focus_overlay)
	button.add_theme_stylebox_override("pressed", _button_accent_style)
	button.add_theme_stylebox_override("hover_pressed", _button_accent_style)
	button.add_theme_stylebox_override("disabled", _button_disabled_style)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.44))
	button.add_theme_color_override("icon_normal_color", Color(0.90, 0.90, 0.92, 0.92))
	button.add_theme_color_override("icon_hover_color", UI.GOLD)
	button.add_theme_color_override("icon_focus_color", UI.GOLD)
	button.add_theme_color_override("icon_pressed_color", UI.GOLD)


func _nine_patch(texture: Texture2D, margins: Vector4, content: Vector4, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.set_texture_margin(SIDE_LEFT, margins.x)
	style.set_texture_margin(SIDE_TOP, margins.y)
	style.set_texture_margin(SIDE_RIGHT, margins.z)
	style.set_texture_margin(SIDE_BOTTOM, margins.w)
	style.set_content_margin(SIDE_LEFT, content.x)
	style.set_content_margin(SIDE_TOP, content.y)
	style.set_content_margin(SIDE_RIGHT, content.z)
	style.set_content_margin(SIDE_BOTTOM, content.w)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style
