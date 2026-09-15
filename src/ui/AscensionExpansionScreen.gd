extends Control
class_name AscensionExpansionScreen

signal close_requested

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const CLOSE_ICON := preload("res://assets/ui/icons/cancel.svg")

var _database: DigimonDatabase
var _balance = BalanceScript.new()
var _selected_id := ""
var _pending_donor_id := ""

var _frame: PanelContainer
var _menu_root: Control
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _status: Label
var _close: Button
var _confirmation: ConfirmationDialog
var _buttons: Array[Button] = []
var _button_ids: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	OverworldState.collection_changed.connect(_refresh)
	OverworldState.inventory_changed.connect(_on_inventory_changed)
	OverworldState.account_rewards_changed.connect(_on_account_rewards_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func open_screen() -> void:
	visible = true
	var collection := OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not collection.is_empty():
		_selected_id = collection[0].id
	_status.text = "Choose an individual. Ascension and size changes are permanent progression decisions."
	_refresh()
	_layout()
	call_deferred("_layout")
	call_deferred("_focus_selected")


func close_view() -> void:
	visible = false
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		close_view()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "AscensionExpansionPanel"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", MENU.screen_frame())
	add_child(_frame)
	_menu_root = Control.new()
	_menu_root.clip_contents = true
	_frame.add_child(_menu_root)

	var title := _label("ASCENSION / EXPANSION", 25, UI.TEXT, true)
	title.name = "Title"
	_menu_root.add_child(title)
	var subtitle := _label("Raise individual Tier, assimilate techniques and configure tactical size.", 11, UI.MUTED)
	subtitle.name = "Subtitle"
	_menu_root.add_child(subtitle)
	_status = _label("", 10, UI.CYAN, true)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_root.add_child(_status)
	_close = MENU.close_button(CLOSE_ICON, "Close Ascension / Expansion")
	_close.pressed.connect(close_view)
	_menu_root.add_child(_close)

	var collection_panel := PanelContainer.new()
	collection_panel.name = "CollectionPanel"
	collection_panel.add_theme_stylebox_override("panel", MENU.surface(UI.CYAN, 0.80, 10))
	_menu_root.add_child(collection_panel)
	var collection_margin := MENU.margin(10, 10, 10, 10)
	collection_panel.add_child(collection_margin)
	var collection_root := VBoxContainer.new()
	collection_root.add_theme_constant_override("separation", 7)
	collection_margin.add_child(collection_root)
	collection_root.add_child(_label("INDIVIDUALS", 11, UI.CYAN, true))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_root.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	_list_scroll.add_child(_list)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.add_theme_stylebox_override("panel", MENU.surface(UI.GOLD, 0.80, 10))
	_menu_root.add_child(detail_panel)
	var detail_margin := MENU.margin(12, 11, 12, 11)
	detail_panel.add_child(detail_margin)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 9)
	_detail_scroll.add_child(_detail)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Confirm Ascension"
	_confirmation.confirmed.connect(_confirm_promotion)
	add_child(_confirmation)


func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_list()
	_refresh_detail()


func _refresh_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	_button_ids.clear()
	var collection := OverworldState.get_collection_instances()
	if collection.is_empty():
		_list.add_child(_label("No Digimon in the collection.", 11, UI.MUTED))
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = collection[0].id
	for instance: DigimonInstance in collection:
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", "Unknown")))
		var size := "2×2" if instance.is_expanded() else "1×1"
		var button := MENU.action_button("%s\nLV %d  ·  TIER %s  ·  %s" % [name.to_upper(), instance.level, instance.tier, size], UI.GREEN if instance.id == _selected_id else UI.CYAN)
		button.custom_minimum_size.y = 62.0
		button.pressed.connect(_select.bind(instance.id))
		button.focus_entered.connect(_select.bind(instance.id))
		_list.add_child(button)
		_buttons.append(button)
		_button_ids.append(instance.id)


func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_detail.add_child(_label("Select a Digimon.", 13, UI.MUTED))
		return
	var species := _database.get_by_seed(instance.species_seed)
	var species_name := String(species.get("name", "Unknown"))
	var rank := String(species.get("rank", "Unknown"))
	var size := "2×2 ACTIVE" if instance.is_expanded() else "1×1 ACTIVE"
	_detail.add_child(_label(instance.get_display_name(species_name).to_upper(), 22, UI.TEXT, true))
	_detail.add_child(_label("%s  ·  TIER %s  ·  %s" % [rank.to_upper(), instance.tier, size], 11, UI.GOLD, true))
	_detail.add_child(_label("%d BITS  ·  %d CORES  ·  %d FRAGMENTS" % [
		OverworldState.get_bits(),
		OverworldState.get_item_count(_balance.expansion_string("coreItemId", "expansion_core")),
		OverworldState.get_item_count(_balance.expansion_string("fragmentItemId", "expansion_fragment")),
	], 10, UI.CYAN, true))

	_detail.add_child(_section("TIER ASCENSION", UI.PURPLE))
	_detail.add_child(_label("CURRENT BONUS  ·  %s" % _tier_bonus_copy(instance.tier), 10, UI.MUTED, true))
	var donors := OverworldState.get_tier_donors(instance.id)
	var donor_picker := OptionButton.new()
	donor_picker.name = "DonorPicker"
	donor_picker.add_item("No donor selected")
	donor_picker.set_item_metadata(0, "")
	for donor: DigimonInstance in donors:
		var donor_species := _database.get_by_seed(donor.species_seed)
		var donor_name := donor.get_display_name(String(donor_species.get("name", "Unknown")))
		donor_picker.add_item("%s · %s" % [donor_name, donor.id.substr(0, mini(8, donor.id.length()))])
		donor_picker.set_item_metadata(donor_picker.item_count - 1, donor.id)
	donor_picker.item_selected.connect(_on_donor_selected.bind(donor_picker))
	_detail.add_child(donor_picker)
	var initial_preview := OverworldState.get_tier_promotion_preview(instance.id)
	var next_tier := String(initial_preview.get("target_tier", ""))
	if next_tier.is_empty():
		_detail.add_child(_label("Maximum Tier reached.", 11, UI.GREEN, true))
	else:
		var fusion_copy := "Exact-species reserve donor required" if bool(initial_preview.get("fusion_required", false)) else "No donor required"
		_detail.add_child(_label("NEXT %s  ·  %d BITS  ·  %s+  ·  %s" % [
			next_tier,
			int(initial_preview.get("bits_cost", 0)),
			String(initial_preview.get("minimum_rank", "Fresh")),
			fusion_copy,
		], 11, UI.TEXT, true))
		_detail.add_child(_label("NEXT BONUS  ·  %s" % _tier_bonus_copy(next_tier), 10, UI.PURPLE.lightened(0.18), true))
	var promote := MENU.action_button("ASCEND TO %s" % (next_tier if not next_tier.is_empty() else "MAX"), UI.PURPLE)
	promote.name = "PromoteButton"
	promote.disabled = next_tier.is_empty()
	promote.pressed.connect(_request_promotion.bind(donor_picker))
	_detail.add_child(promote)

	_detail.add_child(_section("EXPANSION", UI.ORANGE))
	_detail.add_child(_label("Tier S eligibility · permanent Core unlock · free DigiLab size switching.", 10, UI.MUTED))
	if not instance.expansion_unlocked:
		var unlock := MENU.action_button("USE EXPANSION CORE", UI.ORANGE)
		unlock.disabled = _balance.tier_index(instance.tier) < _balance.tier_index(_balance.expansion_string("requiredTier", "S")) or OverworldState.get_item_count(_balance.expansion_string("coreItemId", "expansion_core")) < 1
		unlock.pressed.connect(_unlock_expansion)
		_detail.add_child(unlock)
	else:
		var toggle := MENU.action_button("SWITCH TO %s" % ("1×1" if instance.is_expanded() else "2×2"), UI.ORANGE)
		toggle.pressed.connect(_toggle_expansion.bind(not instance.is_expanded()))
		_detail.add_child(toggle)
		_detail.add_child(_label("2×2 grants +20% max HP and ignores normal forced movement. It does not change damage, defense, SP, SPD or MOV.", 10, UI.MUTED))

	var craft := MENU.action_button("CRAFT CORE · 5 FRAGMENTS + 50,000 BITS", UI.CYAN)
	craft.pressed.connect(_craft_core)
	_detail.add_child(craft)


func _tier_bonus_copy(tier: String) -> String:
	var primary := _balance.tier_stat_multiplier(tier, "hp")
	var secondary := _balance.tier_stat_multiplier(tier, "speed")
	return "HP/ATK/DEF/INT ×%.3f  ·  SP/SPD ×%.3f  ·  MOV unchanged" % [primary, secondary]


func _select(instance_id: String) -> void:
	if instance_id == _selected_id:
		return
	_selected_id = instance_id
	_status.text = "Selected individual changed."
	_refresh()


func _on_donor_selected(index: int, picker: OptionButton) -> void:
	_pending_donor_id = String(picker.get_item_metadata(index))


func _request_promotion(picker: OptionButton) -> void:
	var donor_id := String(picker.get_item_metadata(picker.selected))
	var preview := OverworldState.get_tier_promotion_preview(_selected_id, donor_id)
	if not bool(preview.get("success", false)):
		_status.text = _reason_text(String(preview.get("reason", "invalid")))
		return
	_pending_donor_id = donor_id
	var target := OverworldState.get_instance_by_id(_selected_id)
	var target_species := _database.get_by_seed(target.species_seed)
	var copy := "Ascend %s to Tier %s for %d Bits?" % [
		target.get_display_name(String(target_species.get("name", "Digimon"))),
		String(preview.get("target_tier", "")),
		int(preview.get("bits_cost", 0)),
	]
	if bool(preview.get("fusion_required", false)):
		var donor := OverworldState.get_instance_by_id(donor_id)
		var donor_species := _database.get_by_seed(donor.species_seed)
		copy += "\n\nThis permanently consumes %s (%s)." % [donor.get_display_name(String(donor_species.get("name", "Digimon"))), donor.id]
	_confirmation.dialog_text = copy
	_confirmation.popup_centered(Vector2i(520, 230))


func _confirm_promotion() -> void:
	var result := OverworldState.promote_digimon_tier(_selected_id, _pending_donor_id)
	_status.text = "Ascension complete: Tier %s." % String(result.get("new_tier", "")) if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_pending_donor_id = ""
	_refresh()


func _unlock_expansion() -> void:
	var result := OverworldState.unlock_digimon_expansion(_selected_id)
	_status.text = "Expansion permanently unlocked." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _toggle_expansion(expanded: bool) -> void:
	var result := OverworldState.set_digimon_expanded(_selected_id, expanded)
	_status.text = "Battle size changed to %s." % ("2×2" if expanded else "1×1") if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _craft_core() -> void:
	var result := OverworldState.craft_expansion_core()
	_status.text = "Expansion Core crafted." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_refresh()


func _reason_text(reason: String) -> String:
	var reasons := {
		"maximum_tier": "This individual is already Tier SSS.",
		"rank_too_low": "The current species rank does not meet this Tier requirement.",
		"insufficient_bits": "Not enough Bits.",
		"donor_required": "Select the exact individual that will be consumed.",
		"donor_in_active_party": "The donor must be in Storage.",
		"donor_species_mismatch": "The donor must be the same current species.",
		"donor_has_equipment": "Remove all donor equipment first.",
		"tier_too_low": "Tier S is required to unlock Expansion.",
		"core_required": "An Expansion Core is required.",
		"insufficient_fragments": "Five Expansion Fragments are required.",
		"expansion_locked": "Unlock Expansion for this individual first.",
	}
	return String(reasons.get(reason, "The operation could not be completed (%s)." % reason))


func _focus_selected() -> void:
	for index in range(_button_ids.size()):
		if _button_ids[index] == _selected_id:
			_buttons[index].grab_focus()
			return


func _on_inventory_changed(_inventory: Dictionary) -> void:
	_refresh()


func _on_account_rewards_changed(_bits: int, _data: Dictionary) -> void:
	_refresh()


func _layout() -> void:
	if _frame == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	var compact := UI.is_compact(get_viewport(), 820.0)
	var edge := 10.0 if compact else 20.0
	var width := minf(1120.0, maxf(1.0, physical.x - edge * 2.0))
	var height := minf(700.0, maxf(1.0, physical.y - edge * 2.0))
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_menu_root.size = Vector2(width, height)
	var title := _menu_root.get_node("Title") as Control
	var subtitle := _menu_root.get_node("Subtitle") as Control
	var collection_panel := _menu_root.get_node("CollectionPanel") as Control
	var detail_panel := _menu_root.get_node("DetailPanel") as Control
	title.position = Vector2(24, 13)
	title.size = Vector2(width - 100, 32)
	subtitle.position = Vector2(24, 43)
	subtitle.size = Vector2(width - 100, 22)
	_status.position = Vector2(24, 66)
	_status.size = Vector2(width - 100, 38)
	_close.position = Vector2(width - 68, 14)
	_close.size = Vector2(44, 44)
	if compact:
		collection_panel.position = Vector2(18, 108)
		collection_panel.size = Vector2(width - 36, 176)
		detail_panel.position = Vector2(18, 294)
		detail_panel.size = Vector2(width - 36, height - 312)
	else:
		collection_panel.position = Vector2(20, 108)
		collection_panel.size = Vector2(300, height - 128)
		detail_panel.position = Vector2(336, 108)
		detail_panel.size = Vector2(width - 356, height - 128)


func _section(text: String, color: Color) -> Label:
	return _label(text, 12, color, true)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if size >= 13 else 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label
