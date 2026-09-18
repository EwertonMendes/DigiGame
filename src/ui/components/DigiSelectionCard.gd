extends Button
class_name DigiSelectionCard

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

const REGULAR_HEIGHT := 66.0
const COMPACT_HEIGHT := 56.0

var _title_text := ""
var _subtitle_text := ""
var _status_text := ""
var _icon_kind := "info"
var _semantic_accent := V2.CYAN
var _selected := false
var _focused := false
var _hovered := false
var _compact := false
var _built := false
var _last_disabled := false
var _selection_surface: Panel = null


func configure(
	title: String,
	subtitle: String,
	status: String,
	icon_kind: String,
	semantic_accent: Color
) -> DigiSelectionCard:
	_title_text = title
	_subtitle_text = subtitle
	_status_text = status
	_icon_kind = icon_kind
	_semantic_accent = semantic_accent
	if _built:
		_refresh_content_state()
	return self


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	if _built:
		_sync_selection_surface()


func is_selected() -> bool:
	return _selected


func set_compact(compact: bool) -> void:
	if _compact == compact:
		return
	_compact = compact
	custom_minimum_size.y = COMPACT_HEIGHT if compact else REGULAR_HEIGHT
	if _built:
		_rebuild_content()


func set_interactive(interactive: bool) -> void:
	disabled = not interactive
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	_last_disabled = disabled
	if _built:
		_apply_styles()
		_refresh_content_state()
		_sync_selection_surface()
		_sync_selection_surface()


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(180.0, COMPACT_HEIGHT if _compact else REGULAR_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false
	_last_disabled = disabled
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(true)
	_apply_styles()
	_rebuild_content()
	_built = true
	_sync_selection_surface()


func _process(_delta: float) -> void:
	if _built and disabled != _last_disabled:
		_last_disabled = disabled
		_apply_styles()
		_refresh_content_state()


func _apply_styles() -> void:
	var stable: StyleBoxFlat
	if disabled:
		stable = V2.hospital_button_style(V2.CYAN, "disabled")
	elif _focused or _hovered:
		# Navigation preview uses the approved service-button surface. Because
		# hover, pressed and hover_pressed all point at this same object, a click
		# cannot introduce a transient colour/border frame.
		stable = V2.hospital_button_style(V2.CYAN, "focus")
	else:
		stable = V2.workspace_panel_style(V2.CYAN, false)

	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, stable)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", V2.hospital_button_style(V2.CYAN, "disabled"))
	add_theme_color_override("font_color", V2.TEXT)
	add_theme_color_override("font_disabled_color", V2.SUBTLE)


func _sync_selection_surface() -> void:
	if _selection_surface == null:
		return
	# Committed selection is a dedicated visual layer, not a Button interaction
	# state. It therefore remains pixel-stable while the parent moves through
	# hover/focus/pressed and gives the same persistent bright cyan treatment as
	# the selected Digimon roster surface.
	_selection_surface.visible = _selected


func _on_focus_entered() -> void:
	_focused = true
	if _built:
		_apply_styles()


func _on_focus_exited() -> void:
	_focused = false
	if _built:
		_apply_styles()


func _on_mouse_entered() -> void:
	_hovered = true
	if _built:
		_apply_styles()


func _on_mouse_exited() -> void:
	_hovered = false
	if _built:
		_apply_styles()


func _refresh_content_state() -> void:
	var icon := find_child("SelectionIcon", true, false) as DigiProceduralIcon
	if icon != null:
		icon.custom_minimum_size = Vector2(27.0, 27.0) if _compact else Vector2(31.0, 31.0)
		icon.configure(_icon_kind, _semantic_accent if not disabled else V2.SUBTLE, 1.8)

	var title := find_child("SelectionTitle", true, false) as Label
	if title != null:
		title.text = _title_text
		title.add_theme_font_size_override("font_size", 12 if _compact else 14)
		title.add_theme_color_override("font_color", V2.WHITE if not disabled else V2.SUBTLE)

	var subtitle := find_child("SelectionSubtitle", true, false) as Label
	if subtitle != null:
		subtitle.text = _subtitle_text
		subtitle.add_theme_font_size_override("font_size", 9 if _compact else 10)
		subtitle.add_theme_color_override("font_color", V2.MUTED if not disabled else V2.SUBTLE)

	var badge := find_child("SelectionStatus", true, false) as Label
	if badge != null:
		badge.text = _status_text
		badge.visible = not badge.text.is_empty()
		badge.custom_minimum_size = Vector2(78.0 if _compact else 92.0, 28.0)
		badge.add_theme_font_size_override("font_size", 8 if _compact else 9)
		badge.add_theme_color_override(
			"font_color",
			_semantic_accent if not disabled else V2.SUBTLE
		)
		badge.add_theme_stylebox_override(
			"normal",
			V2.pill_style(_semantic_accent, not disabled)
		)

	tooltip_text = "%s — %s" % [_title_text, _subtitle_text]


func _rebuild_content() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_selection_surface = Panel.new()
	_selection_surface.name = "SelectionCommittedSurface"
	_selection_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_surface.add_theme_stylebox_override(
		"panel",
		V2.hospital_panel_style(V2.CYAN, true)
	)
	add_child(_selection_surface)
	_sync_selection_surface()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_top", 6 if _compact else 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6 if _compact else 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := IconScript.new() as DigiProceduralIcon
	icon.name = "SelectionIcon"
	icon.custom_minimum_size = Vector2(27.0, 27.0) if _compact else Vector2(31.0, 31.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(_icon_kind, _semantic_accent if not disabled else V2.SUBTLE, 1.8)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.name = "SelectionCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var title := Label.new()
	title.name = "SelectionTitle"
	title.text = _title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 12 if _compact else 14)
	title.add_theme_color_override("font_color", V2.WHITE if not disabled else V2.SUBTLE)
	V2.apply_heading(title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SelectionSubtitle"
	subtitle.text = _subtitle_text
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.add_theme_font_size_override("font_size", 9 if _compact else 10)
	subtitle.add_theme_color_override("font_color", V2.MUTED if not disabled else V2.SUBTLE)
	V2.apply_body(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(subtitle)

	var badge := Label.new()
	badge.name = "SelectionStatus"
	badge.text = _status_text
	badge.visible = not badge.text.is_empty()
	badge.custom_minimum_size = Vector2(78.0 if _compact else 92.0, 28.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8 if _compact else 9)
	badge.add_theme_color_override(
		"font_color",
		_semantic_accent if not disabled else V2.SUBTLE
	)
	badge.add_theme_stylebox_override(
		"normal",
		V2.pill_style(_semantic_accent, not disabled)
	)
	V2.apply_heading(badge)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

	_refresh_content_state()
