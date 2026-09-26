extends RefCounted
class_name DigiLabWorkspaceChrome

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const Shared = preload("res://src/ui/components/DigiWorkspaceChrome.gd")

const HEADER_HEIGHT := Shared.HEADER_HEIGHT
const COMPACT_HEADER_HEIGHT := Shared.COMPACT_HEADER_HEIGHT
const FOOTER_HEIGHT := Shared.FOOTER_HEIGHT
const EDGE := Shared.EDGE
const COMPACT_EDGE := Shared.COMPACT_EDGE
const GAP := Shared.GAP
const TOP_GAP := Shared.TOP_GAP
const COMPACT_TOP_GAP := Shared.COMPACT_TOP_GAP
const BOTTOM_GAP := Shared.BOTTOM_GAP
const COMPACT_WIDTH := Shared.COMPACT_WIDTH
const COMPACT_HEIGHT := Shared.COMPACT_HEIGHT
const LOW_HEIGHT := Shared.LOW_HEIGHT
const ROSTER_RATIO := Shared.ROSTER_RATIO
const ROSTER_MIN := Shared.ROSTER_MIN
const ROSTER_MAX := Shared.ROSTER_MAX


static func is_compact(viewport: Viewport) -> bool:
	return Shared.is_compact(viewport)


static func page_capacity(viewport: Viewport, desktop: int = 3, compact: int = 3, low_height: int = 2) -> int:
	return Shared.page_capacity(viewport, desktop, compact, low_height)


static func configure_header(header: DigiModalHeader) -> void:
	if header == null:
		return
	header.set_workspace_mode(true)
	header.set_workspace_full_label_tabs(true)
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
	Shared.install_background(host, background, frame)


static func style_workspace_panel(panel: PanelContainer, accent: Color = V2.CYAN) -> void:
	Shared.style_workspace_panel(panel, accent)


static func disable_scroll(scroll: ScrollContainer) -> void:
	Shared.disable_scroll(scroll)


static func edge_for(compact: bool) -> float:
	return Shared.edge_for(compact)


static func header_height(compact: bool) -> float:
	return Shared.header_height(compact)


static func top_gap(compact: bool) -> float:
	return Shared.top_gap(compact)
