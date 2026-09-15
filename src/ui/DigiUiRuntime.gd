extends Node

# Compatibility layer for player-facing UI that predates Digi UI V2.
#
# New screens/components should use DigiUiTheme directly. This runtime only
# normalizes the remaining named legacy HUD surfaces so old flows do not keep a
# second visual language while they are migrated incrementally.

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

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
	"EvolutionTransitionPanel",
	"AreaTitleCard",
]

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
	"EvolutionTransitionPanel",
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
	"ConfirmEvolutionTransition",
	"CancelEvolutionTransition",
]

var _tracked_panels: Dictionary = {}
var _tracked_buttons: Dictionary = {}
var _restyle_elapsed := 0.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_decorate_existing_tree")
	set_process(true)


func _process(delta: float) -> void:
	_restyle_elapsed += delta
	if _restyle_elapsed < 0.12:
		return
	_restyle_elapsed = 0.0
	_restyle_tracked_panels()
	_restyle_tracked_buttons()


func _decorate_existing_tree() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		_decorate_branch(scene)


func _decorate_branch(node: Node) -> void:
	_decorate_node(node)
	for child: Node in node.get_children():
		_decorate_branch(child)


func _on_node_added(node: Node) -> void:
	call_deferred("_decorate_node", node)


func _decorate_node(node: Node) -> void:
	if not is_instance_valid(node) or not node is Control:
		return
	var control := node as Control
	if control.has_meta("digi_ui_v2_component"):
		return

	if control is Panel or control is PanelContainer:
		var panel_name := String(control.name)
		if panel_name in ACCENT_PANELS:
			_track_panel(control, true)
			return
		if panel_name in STANDARD_PANELS:
			_track_panel(control, false)
			return

	if control is Button:
		var button := control as Button
		if _should_style_button(button):
			_track_button(button)
			return

	if control is Label and _has_named_ancestor(control, STANDARD_PANELS + ACCENT_PANELS):
		_style_legacy_label(control as Label)


func _track_panel(control: Control, accented: bool) -> void:
	control.set_meta("digi_ui_v2_runtime", true)
	_tracked_panels[control.get_instance_id()] = {
		"ref": weakref(control),
		"accented": accented,
	}
	_style_panel(control, accented)


func _track_button(button: Button) -> void:
	button.set_meta("digi_ui_v2_runtime", true)
	_tracked_buttons[button.get_instance_id()] = weakref(button)
	_style_button(button)


func _restyle_tracked_panels() -> void:
	var stale: Array[int] = []
	for raw_id: Variant in _tracked_panels.keys():
		var instance_id := int(raw_id)
		var entry := _tracked_panels.get(instance_id, {}) as Dictionary
		var ref := entry.get("ref") as WeakRef
		var panel := ref.get_ref() as Control if ref != null else null
		if panel == null or not is_instance_valid(panel):
			stale.append(instance_id)
			continue
		_style_panel(panel, bool(entry.get("accented", false)))
	for instance_id: int in stale:
		_tracked_panels.erase(instance_id)


func _restyle_tracked_buttons() -> void:
	var stale: Array[int] = []
	for raw_id: Variant in _tracked_buttons.keys():
		var instance_id := int(raw_id)
		var ref := _tracked_buttons.get(instance_id) as WeakRef
		var button := ref.get_ref() as Button if ref != null else null
		if button == null or not is_instance_valid(button):
			stale.append(instance_id)
			continue
		_style_button(button)
	for instance_id: int in stale:
		_tracked_buttons.erase(instance_id)


func _style_panel(control: Control, accented: bool) -> void:
	var accent := V2.AMBER if accented else V2.BORDER
	var border_alpha := 0.72 if accented else 0.52
	control.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.97),
			Color(accent.r, accent.g, accent.b, border_alpha),
			V2.CARD_RADIUS,
			Vector4.ZERO,
			0.12
		)
	)


func _should_style_button(button: Button) -> bool:
	if String(button.name) in FRAMED_BUTTON_NAMES:
		return true
	var parent: Node = button.get_parent()
	while parent != null:
		if String(parent.name) in DIALOG_ANCESTORS:
			return true
		if parent.has_meta("digi_ui_v2_component"):
			return false
		parent = parent.get_parent()
	return false


func _style_button(button: Button) -> void:
	var accent := _button_accent(button)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, V2.TOUCH_TARGET)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.46))
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed"))
	button.add_theme_stylebox_override("hover_pressed", V2.button_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled"))
	V2.apply_heading(button)


func _button_accent(button: Button) -> Color:
	var node_name := String(button.name)
	if node_name in ["CancelBattleDialog", "CancelFlee", "CancelEvolutionTransition", "Cancel"]:
		return V2.MUTED
	if node_name == "ConfirmFlee":
		return V2.RED
	if node_name == "ConfirmEvolutionTransition":
		return V2.GREEN
	if node_name == "StartBattle" or node_name == "Talk":
		return V2.AMBER
	return V2.CYAN


func _style_legacy_label(label: Label) -> void:
	var label_name := String(label.name).to_lower()
	if "title" in label_name or label_name == "operation":
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	if label.get_theme_color("font_color").get_luminance() < 0.34:
		label.add_theme_color_override("font_color", V2.TEXT)


func _has_named_ancestor(control: Control, names: Array) -> bool:
	var parent: Node = control.get_parent()
	while parent != null:
		if String(parent.name) in names:
			return true
		if parent.has_meta("digi_ui_v2_component"):
			return false
		parent = parent.get_parent()
	return false
