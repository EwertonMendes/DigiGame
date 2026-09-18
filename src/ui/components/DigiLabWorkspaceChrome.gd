extends RefCounted
class_name DigiLabWorkspaceChrome

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

const HEADER_HEIGHT := 86.0
const COMPACT_HEADER_HEIGHT := 72.0
const FOOTER_HEIGHT := 54.0
const EDGE := 24.0
const COMPACT_EDGE := 10.0
const GAP := 12.0
const TOP_GAP := 16.0
const COMPACT_TOP_GAP := 12.0
const BOTTOM_GAP := 12.0
const COMPACT_WIDTH := 980.0
const COMPACT_HEIGHT := 600.0
const LOW_HEIGHT := 560.0
const ROSTER_RATIO := 0.255
const ROSTER_MIN := 290.0
const ROSTER_MAX := 430.0


static func is_compact(viewport: Viewport) -> bool:
	var physical := V2.physical_window_size(viewport)
	return physical.x < COMPACT_WIDTH or physical.y < COMPACT_HEIGHT


static func page_capacity(viewport: Viewport, desktop: int = 3, compact: int = 3, low_height: int = 2) -> int:
	var physical := V2.physical_window_size(viewport)
	if physical.y < LOW_HEIGHT:
		return maxi(1, low_height)
	if is_compact(viewport):
		return maxi(1, compact)
	return maxi(1, desktop)


static func configure_header(header: DigiModalHeader) -> void:
	if header == null:
		return
	header.set_workspace_mode(true)
	header.configure("DIGI LAB", "Reconstruction & Progression", OverworldState.get_bits(), true)


static func configure_hints(
	hints: DigiInputHintBar,
	description: String,
	secondary_label: String = "",
	pagination: bool = false
) -> void:
	if hints == null:
		return
	hints.set_description(description)
	hints.set_primary_tabs_enabled(true)
	hints.set_secondary_tabs_enabled(not secondary_label.is_empty())
	if not secondary_label.is_empty():
		hints.set_secondary_tabs_label(secondary_label)
	hints.set_pagination_enabled(pagination)
	hints.set_scroll_hint_enabled(false)
	hints.set_hide_hints_on_touch(true)


static func install_background(host: Control, background: Control, frame: PanelContainer) -> void:
	if host == null or background == null or frame == null:
		return
	if background.get_parent() != host:
		return

	# Base DigiLab screens paint an opaque full-screen frame. Workspace screens
	# render their dedicated backdrop between the legacy input-blocking backdrop
	# and the frame, then make only the frame surface transparent. Child panels
	# keep their own opacity, so readability is preserved without hiding the art.
	var frame_index := frame.get_index()
	host.move_child(background, frame_index)
	frame.add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	)


static func style_workspace_panel(panel: PanelContainer, accent: Color = V2.CYAN) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(accent))


static func disable_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false


static func edge_for(compact: bool) -> float:
	return COMPACT_EDGE if compact else EDGE


static func header_height(compact: bool) -> float:
	return COMPACT_HEADER_HEIGHT if compact else HEADER_HEIGHT


static func top_gap(compact: bool) -> float:
	return COMPACT_TOP_GAP if compact else TOP_GAP
