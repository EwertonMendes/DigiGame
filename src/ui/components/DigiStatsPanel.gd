extends PanelContainer
class_name DigiStatsPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const StatRowScript = preload("res://src/ui/components/DigiStatRow.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")

var _workspace_mode := false
var _compact_workspace := false
var _bounded_workspace := false


func set_workspace_mode(enabled: bool, compact: bool = false, bounded: bool = false) -> void:
	_workspace_mode = enabled
	_compact_workspace = compact
	_bounded_workspace = bounded


func configure(stats: Dictionary, current_hp: int = -1, current_sp: int = -1) -> DigiStatsPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.0 if _workspace_mode else 0.78
	custom_minimum_size.y = 0.0 if _workspace_mode else 228.0
	clip_contents = _bounded_workspace
	add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0) if _workspace_mode else V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	if not _workspace_mode:
		var header := SectionHeaderScript.new() as DigiSectionHeader
		header.configure("COMBAT STATS", "", V2.CYAN, "sword")
		body.add_child(header)

	var content := _margin(12 if _workspace_mode else 10, 10 if _workspace_mode else 8, 12 if _workspace_mode else 10, 12 if _workspace_mode else 8)
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _bounded_workspace else Control.SIZE_EXPAND_FILL
	body.add_child(content)
	var rows := VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if _bounded_workspace else Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5 if _workspace_mode else 2)
	content.add_child(rows)

	var max_hp := maxi(1, int(stats.get("hp", 0)))
	var max_sp := maxi(1, int(stats.get("sp", stats.get("mp", 0))))
	var hp_now := clampi(max_hp if current_hp < 0 else current_hp, 0, max_hp)
	var sp_now := clampi(max_sp if current_sp < 0 else current_sp, 0, max_sp)
	var hp_row := StatRowScript.new() as DigiStatRow
	hp_row.set_roomy(_workspace_mode, _compact_workspace, not _bounded_workspace)
	hp_row.configure("HP", hp_now, float(max_hp), "heart", V2.GREEN, true, "%d / %d" % [hp_now, max_hp])
	rows.add_child(hp_row)
	var sp_row := StatRowScript.new() as DigiStatRow
	sp_row.set_roomy(_workspace_mode, _compact_workspace, not _bounded_workspace)
	sp_row.configure("SP", sp_now, float(max_sp), "bolt", V2.BLUE, true, "%d / %d" % [sp_now, max_sp])
	rows.add_child(sp_row)
	rows.add_child(_separator())

	var entries := [
		["ATK", "atk", "sword", V2.ORANGE],
		["DEF", "def", "shield", V2.CYAN],
		["INT", "int", "spark", V2.PURPLE],
		["SPD", "speed", "speed", V2.AMBER],
		["MOV", "mov", "move", V2.MUTED],
	]
	for entry in entries:
		var value := int(stats.get(String(entry[1]), 0))
		var row := StatRowScript.new() as DigiStatRow
		row.set_roomy(_workspace_mode, _compact_workspace, not _bounded_workspace)
		row.configure(String(entry[0]), value, 1.0, String(entry[2]), entry[3] as Color, false, str(value))
		rows.add_child(row)
	return self


func _separator() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = V2.separator_color(0.36)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
