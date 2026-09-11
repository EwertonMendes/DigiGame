extends Node

# Runtime presentation layer for DigiGame UI.
#
# The Kenney Fantasy UI Borders geometry is reserved for meaningful surfaces
# and dialog actions instead of being stamped on every Control. This keeps the
# identity visible while avoiding the crowding and edge collisions caused by
# the previous global sci-fi decorator.

const UI = preload("res://src/ui/TacticalTheme.gd")
const ASSET_ROOT := "res://assets/ui/kenney_fantasy_digi"
const PANEL_STANDARD_PATH := ASSET_ROOT + "/panel_standard.svg"
const PANEL_EMPHASIS_PATH := ASSET_ROOT + "/panel_emphasis.svg"
const BUTTON_NORMAL_PATH := ASSET_ROOT + "/button_normal.svg"
const BUTTON_HOVER_PATH := ASSET_ROOT + "/button_hover.svg"
const BUTTON_PRESSED_PATH := ASSET_ROOT + "/button_pressed.svg"

const STANDARD_PANELS := [
	"LocationPanel",
	"CommandRail",
	"ActiveUnitStatus",
	"TechniqueMenu",
	"ActionPreview",
	"BattleResult",
	"DigimonContextCard",
]

const EMPHASIS_PANELS := [
	"BattleDialog",
	"InteractionPrompt",
	"RetreatPanel",
	"RetreatAnnouncement",
	"RetreatResult",
	"BattleStartFrame",
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
	"ConfirmFlee",
	"CancelFlee",
	"ReturnAfterRetreat",
	"ReturnToHub",
	"Talk",
]

const FADE_IN_PANELS := [
	"BattleDialog",
	"TechniqueMenu",
	"RetreatPanel",
	"RetreatResult",
]

var _panel_standard: Texture2D = null
var _panel_emphasis: Texture2D = null
var _button_normal: Texture2D = null
var _button_hover: Texture2D = null
var _button_pressed: Texture2D = null
var _panel_standard_style: StyleBoxTexture = null
var _panel_emphasis_style: StyleBoxTexture = null
var _button_normal_style: StyleBoxTexture = null
var _button_hover_style: StyleBoxTexture = null
var _button_pressed_style: StyleBoxTexture = null
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
		var emphasis := bool(entry.get("emphasis", false))
		var desired: StyleBoxTexture = _panel_emphasis_style if emphasis else _panel_standard_style
		if panel.get_theme_stylebox("panel") != desired:
			panel.add_theme_stylebox_override("panel", desired)
	for instance_id: int in stale_ids:
		_tracked_panels.erase(instance_id)


func _load_skin_resources() -> void:
	_panel_standard = load(PANEL_STANDARD_PATH) as Texture2D
	_panel_emphasis = load(PANEL_EMPHASIS_PATH) as Texture2D
	_button_normal = load(BUTTON_NORMAL_PATH) as Texture2D
	_button_hover = load(BUTTON_HOVER_PATH) as Texture2D
	_button_pressed = load(BUTTON_PRESSED_PATH) as Texture2D
	_skin_ready = (
		_panel_standard != null
		and _panel_emphasis != null
		and _button_normal != null
		and _button_hover != null
		and _button_pressed != null
	)
	if not _skin_ready:
		push_warning("Digi fantasy UI skin could not be loaded; keeping TacticalTheme fallbacks.")
		return
	_panel_standard_style = _nine_patch(_panel_standard, Vector4(9.0, 9.0, 9.0, 9.0), Vector4(11.0, 11.0, 11.0, 11.0))
	_panel_emphasis_style = _nine_patch(_panel_emphasis, Vector4(10.0, 10.0, 10.0, 10.0), Vector4(14.0, 14.0, 14.0, 14.0))
	var button_margins := Vector4(9.0, 9.0, 9.0, 9.0)
	var button_content := Vector4(15.0, 8.0, 15.0, 8.0)
	_button_normal_style = _nine_patch(_button_normal, button_margins, button_content)
	_button_hover_style = _nine_patch(_button_hover, button_margins, button_content)
	_button_pressed_style = _nine_patch(_button_pressed, button_margins, button_content)


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
		if panel_name in EMPHASIS_PANELS:
			_style_panel(control, true)
			_install_fade_in(control)
			control.set_meta("digi_fantasy_skin_applied", true)
			return
		if panel_name in STANDARD_PANELS:
			_style_panel(control, false)
			if panel_name in FADE_IN_PANELS:
				_install_fade_in(control)
			control.set_meta("digi_fantasy_skin_applied", true)
			return

	if control is Button:
		var button := control as Button
		if _should_frame_button(button):
			_style_related_result_panel(button)
			_style_dialog_button(button)
			control.set_meta("digi_fantasy_skin_applied", true)


func _style_panel(control: Control, emphasis: bool) -> void:
	var style: StyleBoxTexture = _panel_emphasis_style if emphasis else _panel_standard_style
	control.add_theme_stylebox_override("panel", style)
	_tracked_panels[control.get_instance_id()] = {
		"ref": weakref(control),
		"emphasis": emphasis,
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


# The base battle result panel predates the naming convention and is an unnamed
# Panel. Discover it from its uniquely named return button so it receives the
# same treatment as retreat / hub dialogs without broadly skinning utilities.
func _style_related_result_panel(button: Button) -> void:
	if String(button.name) != "ReturnToHub":
		return
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is Panel or parent is PanelContainer:
			var panel := parent as Control
			if not panel.has_meta("digi_fantasy_skin_applied"):
				_style_panel(panel, true)
				_install_fade_in(panel)
				panel.set_meta("digi_fantasy_skin_applied", true)
			return
		parent = parent.get_parent()


func _style_dialog_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_normal_style)
	button.add_theme_stylebox_override("hover", _button_hover_style)
	button.add_theme_stylebox_override("focus", _button_hover_style)
	button.add_theme_stylebox_override("pressed", _button_pressed_style)
	button.add_theme_stylebox_override("hover_pressed", _button_pressed_style)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(UI.MUTED.r, UI.MUTED.g, UI.MUTED.b, 0.44))
	button.add_theme_color_override("icon_hover_color", UI.CYAN)
	button.add_theme_color_override("icon_focus_color", UI.CYAN)
	button.add_theme_color_override("icon_pressed_color", UI.GOLD)


func _nine_patch(texture: Texture2D, margins: Vector4, content: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
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


func _install_fade_in(control: Control) -> void:
	if control.has_meta("digi_fantasy_fade_installed"):
		return
	control.set_meta("digi_fantasy_fade_installed", true)
	control.visibility_changed.connect(_on_panel_visibility_changed.bind(control))
	if control.visible:
		call_deferred("_fade_panel_in", control)


func _on_panel_visibility_changed(control: Control) -> void:
	if is_instance_valid(control) and control.visible:
		_fade_panel_in(control)


func _fade_panel_in(control: Control) -> void:
	if not is_instance_valid(control) or not control.visible:
		return
	var target_alpha := control.modulate.a
	if target_alpha <= 0.01:
		target_alpha = 1.0
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", target_alpha, 0.14)
