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
var _panel_style_cache: Dictionary = {}
var _button_style_cache: Dictionary = {}
var _restyle_elapsed := 0.0
var _transition_active := false
var _transition: Node = null


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind_transition_lifecycle")
	call_deferred("_decorate_existing_tree")
	set_process(true)


func _process(delta: float) -> void:
	if _transition_active:
		if _transition == null or not is_instance_valid(_transition):
			_resume_after_transition()
		elif _transition.has_method("is_transitioning") and not bool(_transition.call("is_transitioning")):
			_resume_after_transition()
		return

	_restyle_elapsed += delta
	if _restyle_elapsed < 0.12:
		return
	_restyle_elapsed = 0.0
	_restyle_tracked_panels()
	_restyle_tracked_buttons()


func _bind_transition_lifecycle() -> void:
	var transition := get_tree().root.get_node_or_null("DigitalSceneTransition")
	if transition == null:
		return
	_transition = transition

	var started_callback := Callable(self, "_on_transition_started")
	if transition.has_signal("transition_started") and not transition.is_connected("transition_started", started_callback):
		transition.connect("transition_started", started_callback)

	var finished_callback := Callable(self, "_on_transition_finished")
	if transition.has_signal("transition_finished") and not transition.is_connected("transition_finished", finished_callback):
		transition.connect("transition_finished", finished_callback)

	if transition.has_method("is_transitioning") and bool(transition.call("is_transitioning")):
		_suspend_for_transition()


func _on_transition_started(_scene_path: String, _context: String) -> void:
	_suspend_for_transition()


func _on_transition_finished(_scene_path: String, _context: String) -> void:
	_resume_after_transition()


func _suspend_for_transition() -> void:
	_transition_active = true
	_restyle_elapsed = 0.0
	# Styles already applied to the outgoing scene remain on those Controls. Drop
	# only the runtime tracking so no compatibility work touches Nodes while the
	# SceneTree is being torn down and the destination scene is being instantiated.
	_tracked_panels.clear()
	_tracked_buttons.clear()


func _resume_after_transition() -> void:
	if not _transition_active:
		return
	_transition_active = false
	_restyle_elapsed = 0.0
	_tracked_panels.clear()
	_tracked_buttons.clear()
	# The transition cover is gone now, so decorate the stable destination tree in
	# one pass instead of reacting to each Node while scene replacement is active.
	call_deferred("_decorate_existing_tree")


func _decorate_existing_tree() -> void:
	if _transition_active:
		return
	var scene: Node = get_tree().current_scene
	if scene != null:
		_decorate_branch(scene)


func _decorate_branch(node: Node) -> void:
	if _transition_active or node == null or not is_instance_valid(node):
		return
	_decorate_node(node)
	for child: Node in node.get_children():
		_decorate_branch(child)


func _on_node_added(node: Node) -> void:
	if _transition_active:
		return
	# Never defer a raw Object reference: nodes may be freed before the message
	# queue runs. Resolve by instance id only when the deferred call executes.
	call_deferred("_decorate_instance_id", node.get_instance_id())


func _decorate_instance_id(instance_id: int) -> void:
	if _transition_active:
		return
	var candidate := instance_from_id(instance_id)
	if candidate is Node:
		_decorate_node(candidate as Node)


func _decorate_node(node: Node) -> void:
	if _transition_active or not is_instance_valid(node) or not node is Control:
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
	var cache_key := "accented" if accented else "standard"
	var style := _panel_style_cache.get(cache_key) as StyleBoxFlat
	if style == null:
		var accent := V2.AMBER if accented else V2.BORDER
		var border_alpha := 0.72 if accented else 0.52
		style = V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.97),
			Color(accent.r, accent.g, accent.b, border_alpha),
			V2.CARD_RADIUS,
			Vector4.ZERO,
			0.12
		)
		_panel_style_cache[cache_key] = style
	if control.get_theme_stylebox("panel") != style:
		control.add_theme_stylebox_override("panel", style)


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
	var accent_key := _button_accent_key(button)
	var accent := _accent_for_key(accent_key)

	if not button.has_meta("digi_ui_v2_runtime_initialized"):
		button.set_meta("digi_ui_v2_runtime_initialized", true)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, V2.TOUCH_TARGET)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_color_override("font_color", V2.TEXT)
		button.add_theme_color_override("font_hover_color", V2.WHITE)
		button.add_theme_color_override("font_focus_color", V2.WHITE)
		button.add_theme_color_override("font_pressed_color", V2.WHITE)
		button.add_theme_color_override("font_disabled_color", Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.46))
		V2.apply_heading(button)

	_ensure_button_style(button, "normal", accent_key, accent, "normal")
	_ensure_button_style(button, "hover", accent_key, accent, "hover")
	_ensure_button_style(button, "focus", accent_key, accent, "focus")
	_ensure_button_style(button, "pressed", accent_key, accent, "pressed")
	_ensure_button_style(button, "hover_pressed", accent_key, accent, "pressed")
	_ensure_button_style(button, "disabled", accent_key, accent, "disabled")


func _ensure_button_style(
	button: Button,
	theme_state: String,
	accent_key: String,
	accent: Color,
	visual_state: String
) -> void:
	var cache_key := "%s:%s" % [accent_key, visual_state]
	var style := _button_style_cache.get(cache_key) as StyleBoxFlat
	if style == null:
		style = V2.button_style(accent, visual_state)
		_button_style_cache[cache_key] = style
	if button.get_theme_stylebox(theme_state) != style:
		button.add_theme_stylebox_override(theme_state, style)


func _button_accent_key(button: Button) -> String:
	var node_name := String(button.name)
	if node_name in ["CancelBattleDialog", "CancelFlee", "CancelEvolutionTransition", "Cancel"]:
		return "muted"
	if node_name == "ConfirmFlee":
		return "red"
	if node_name == "ConfirmEvolutionTransition":
		return "green"
	if node_name == "StartBattle" or node_name == "Talk":
		return "amber"
	return "cyan"


func _accent_for_key(accent_key: String) -> Color:
	match accent_key:
		"muted":
			return V2.MUTED
		"red":
			return V2.RED
		"green":
			return V2.GREEN
		"amber":
			return V2.AMBER
		_:
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
