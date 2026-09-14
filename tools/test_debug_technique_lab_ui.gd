extends Node

const ToolkitScript = preload("res://src/debug/DeveloperToolkitWithSkills.gd")
const ProgressionToolsScript = preload("res://src/debug/DebugProgressionTools.gd")
const StateToolsScript = preload("res://src/debug/DebugStateTools.gd")
const RosterToolsScript = preload("res://src/debug/DebugRosterTools.gd")
const TechniqueToolsScript = preload("res://src/debug/DebugTechniqueTools.gd")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	var party := OverworldState.get_active_instances()
	assert(not party.is_empty(), "Technique lab UI regression requires the normal starter party")
	var selected: DigimonInstance = party[0]

	# The production toolkit deliberately stays unavailable in headless builds.
	# Build only the Skills workspace here while keeping the real project
	# autoloads/state available, exactly like the other toolkit regression.
	var toolkit = ToolkitScript.new()
	add_child(toolkit)
	await get_tree().process_frame
	toolkit._progression = ProgressionToolsScript.new() as DebugProgressionTools
	toolkit._state = StateToolsScript.new() as DebugStateTools
	toolkit._roster = RosterToolsScript.new() as DebugRosterTools
	toolkit._techniques = TechniqueToolsScript.new() as DebugTechniqueTools
	toolkit._skill_catalog = toolkit._techniques.catalog(true)
	toolkit._selected_id = selected.id
	toolkit._status = Label.new()
	toolkit.add_child(toolkit._status)

	var tabs := TabContainer.new()
	toolkit._tabs = tabs
	toolkit.add_child(tabs)
	toolkit._build_skills_tab(tabs)
	toolkit._refresh_skill_lab()

	assert(tabs.get_tab_count() == 1 and tabs.get_tab_title(0) == "SKILLS", "Technique lab must register as a real Developer Toolkit tab")
	assert(toolkit._skill_target_select != null, "Technique lab must expose an explicit target Digimon selector")
	assert(toolkit._skill_target_select.item_count == OverworldState.get_collection_instances().size(), "Target selector must expose every owned Digimon")
	assert(String(toolkit._skill_target_select.get_item_metadata(toolkit._skill_target_select.selected)) == selected.id, "Target selector must track the currently selected Digimon")
	assert(toolkit._skill_list != null and toolkit._skill_list.get_child_count() > 0, "Technique lab must render catalog rows")
	assert(toolkit._skill_details != null and not toolkit._skill_details.text.is_empty(), "Technique lab must render selected-technique details")
	assert(toolkit._skill_results_summary.text.contains("matching"), "Technique lab must expose paginated result counts")

	toolkit._skill_search.text = "pepper"
	toolkit._reset_skill_results()
	assert(not toolkit._skill_results_summary.text.begins_with("0 matching"), "Technique search must find canonical catalog entries")
	toolkit._reset_skill_filters()

	var unlearned_id := ""
	for action: Dictionary in toolkit._skill_catalog:
		var candidate := String(action.get("id", ""))
		if String(action.get("availability", "ready")) == "ready" and not selected.learned_skills.has(candidate):
			unlearned_id = candidate
			break
	assert(not unlearned_id.is_empty(), "Technique lab UI regression requires an unlearned technique")
	toolkit._selected_skill_id = unlearned_id
	toolkit._refresh_skill_details()
	assert(not toolkit._skill_learn_button.disabled, "An unlearned selected technique must always expose an enabled Teach action")
	assert(toolkit._skill_learn_button.text == "TEACH TO %s" % toolkit._progression.display_name(selected).to_upper(), "Teach action must clearly name the target Digimon")
	toolkit._toggle_selected_skill_learned()
	assert(selected.learned_skills.has(unlearned_id), "Technique lab Teach button must mutate the selected real Digimon")
	assert(toolkit._skill_learn_button.text == "REMOVE SKILL FROM %s" % toolkit._progression.display_name(selected).to_upper(), "Learned catalog entries must expose an explicit remove action")
	toolkit._set_selected_skill_mastery(DigimonInstance.MAX_SKILL_MASTERY_POINTS)
	assert(selected.get_skill_mastery_grade(unlearned_id) == "mastered", "Technique lab mastery controls must reach Mastered")

	print("debug technique lab UI regression passed")
	get_tree().quit()
