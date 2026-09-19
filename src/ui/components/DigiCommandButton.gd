extends Button
class_name DigiCommandButton

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const Style = preload("res://src/ui/components/DigiCommandButtonStyle.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

const REGULAR_HEIGHT := 84.0
const COMPACT_HEIGHT := 72.0
const MINIMAL_HEIGHT := 54.0
const MINIMAL_COMPACT_HEIGHT := 50.0
const REGULAR_SUBTITLE_HEIGHT := 28.0
const COMPACT_SUBTITLE_HEIGHT := 24.0

var _accent := V2.CYAN
var _icon_kind := "info"
var _title_text := "ACTION"
var _subtitle_text := ""
var _status_text := ""
var _content_built := false
var _compact := false
var _minimal := false
var _last_disabled := false


func configure(title: String, subtitle: String, status: String, icon_kind: String, accent: Color) -> DigiCommandButton:
	_title_text = title
	_subtitle_text = subtitle
	_status_text = status
	_icon_kind = icon_kind
	_accent = accent
	if _content_built:
		_rebuild_content()
		_apply_styles()
	return self


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0.0 if _minimal else 180.0, _button_height())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false
	_last_disabled = disabled
	set_process(true)
	_apply_styles()
	_rebuild_content()
	_content_built = true


func _process(_delta: float) -> void:
	# `disabled` is a built-in Button property and can be changed by any screen.
	# Mirror that state into the icon/copy only when it actually changes so the
	# shared component always has a complete disabled treatment, not just a dim
	# background supplied by the theme.
	if _content_built and disabled != _last_disabled:
		_last_disabled = disabled
		_rebuild_content()


func set_compact(compact: bool) -> void:
	_compact = compact
	custom_minimum_size = Vector2(0.0 if _minimal else 180.0, _button_height())
	if _content_built:
		_rebuild_content()


func set_minimal(minimal: bool) -> void:
	_minimal = minimal
	custom_minimum_size = Vector2(0.0 if minimal else 180.0, _button_height())
	if _content_built:
		_rebuild_content()


func _button_height() -> float:
	if _minimal:
		return MINIMAL_COMPACT_HEIGHT if _compact else MINIMAL_HEIGHT
	return COMPACT_HEIGHT if _compact else REGULAR_HEIGHT


func set_interactive(interactive: bool) -> void:
	disabled = not interactive
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	_last_disabled = disabled
	if _content_built:
		_rebuild_content()


func _apply_styles() -> void:
	add_theme_stylebox_override("normal", Style.style(_accent, "normal"))
	add_theme_stylebox_override("hover", Style.style(_accent, "hover"))
	add_theme_stylebox_override("focus", Style.style(_accent, "focus"))
	add_theme_stylebox_override("pressed", Style.style(_accent, "pressed"))
	add_theme_stylebox_override("hover_pressed", Style.style(_accent, "pressed"))
	add_theme_stylebox_override("disabled", Style.style(_accent, "disabled"))
	add_theme_color_override("font_color", V2.TEXT)
	add_theme_color_override("font_disabled_color", V2.SUBTLE)


func _rebuild_content() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10 if _minimal else 14)
	margin.add_theme_constant_override("margin_top", 5 if _minimal else (6 if _compact else 7))
	margin.add_theme_constant_override("margin_right", 10 if _minimal else 14)
	margin.add_theme_constant_override("margin_bottom", 5 if _minimal else (6 if _compact else 7))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7 if _minimal else (10 if _compact else 11))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := IconScript.new() as DigiProceduralIcon
	icon.name = "CommandIcon"
	icon.custom_minimum_size = (
		Vector2(24.0, 24.0)
		if _minimal
		else (Vector2(30.0, 30.0) if _compact else Vector2(34.0, 34.0))
	)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(_icon_kind, _accent if not disabled else V2.SUBTLE, 1.9)
	icon.modulate = Color.WHITE if not disabled else Color(0.70, 0.74, 0.78, 0.60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	if _minimal:
		var minimal_title := Label.new()
		minimal_title.name = "CommandTitle"
		minimal_title.text = _title_text
		minimal_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		minimal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		minimal_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Do not enable ellipsis on the minimal title without an explicit width:
		# Label then reports a zero horizontal minimum and HBoxContainer is free to
		# collapse it completely, which is why only the icons were visible.
		# The compact command names are intentionally short enough to use their
		# natural measured width beside the icon.
		minimal_title.add_theme_font_size_override("font_size", 10 if _compact else 11)
		minimal_title.add_theme_color_override("font_color", V2.WHITE if not disabled else V2.SUBTLE)
		V2.apply_heading(minimal_title)
		minimal_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(minimal_title)
		tooltip_text = "%s — %s" % [_title_text, _subtitle_text] if not _subtitle_text.is_empty() else _title_text
		if not _status_text.is_empty():
			tooltip_text += "\n%s" % _status_text
		return

	# Treat command copy as one flexible column. Title, description and metadata
	# each receive the full remaining width instead of competing horizontally.
	# This makes ordinary command text readable by default while keeping bounded
	# ellipsis on every label as a final safeguard for exceptional content.
	var copy := VBoxContainer.new()
	copy.name = "CommandCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2 if _compact else 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var title := Label.new()
	title.name = "CommandTitle"
	title.text = _title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 13 if _compact else 14)
	title.add_theme_color_override("font_color", V2.WHITE if not disabled else V2.SUBTLE)
	V2.apply_heading(title)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "CommandSubtitle"
	subtitle.text = _subtitle_text
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.custom_minimum_size.y = COMPACT_SUBTITLE_HEIGHT if _compact else REGULAR_SUBTITLE_HEIGHT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.max_lines_visible = 2
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle.add_theme_font_size_override("font_size", 9 if _compact else 10)
	subtitle.add_theme_color_override("font_color", V2.MUTED if not disabled else V2.SUBTLE)
	V2.apply_body(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(subtitle)

	if not _status_text.is_empty():
		var status := Label.new()
		status.name = "CommandStatus"
		status.text = _status_text
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		status.add_theme_font_size_override("font_size", 8 if _compact else 9)
		status.add_theme_color_override("font_color", _accent if not disabled else V2.SUBTLE)
		V2.apply_heading(status)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(status)

	tooltip_text = "%s — %s" % [_title_text, _subtitle_text]
	if not _status_text.is_empty():
		tooltip_text += "\n%s" % _status_text
