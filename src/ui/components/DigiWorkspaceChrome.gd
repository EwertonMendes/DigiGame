extends RefCounted
class_name DigiWorkspaceChrome

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


static func metrics(viewport: Viewport) -> Dictionary:
	var physical := V2.physical_window_size(viewport)
	var compact := is_compact(viewport)
	var header_h := header_height(compact)
	var edge := edge_for(compact)
	var top_gap_value := top_gap(compact)
	var body_top := header_h + top_gap_value
	var body_bottom := physical.y - FOOTER_HEIGHT - BOTTOM_GAP
	return {
		"physical": physical,
		"scale": V2.ui_scale(viewport),
		"compact": compact,
		"header_h": header_h,
		"edge": edge,
		"top_gap": top_gap_value,
		"body_top": body_top,
		"body_bottom": body_bottom,
		"body_h": maxf(0.0, body_bottom - body_top),
	}


static func install_background(host: Control, background: Control, frame: PanelContainer) -> void:
	if host == null or background == null or frame == null or background.get_parent() != host:
		return
	host.move_child(background, frame.get_index())
	frame.add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))


static func style_workspace_panel(panel: PanelContainer, accent: Color = V2.CYAN) -> void:
	if panel != null:
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
