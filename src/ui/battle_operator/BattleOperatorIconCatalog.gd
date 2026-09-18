extends RefCounted
class_name BattleOperatorIconCatalog

const ICON_ROOT := "res://assets/ui/icons/battle_operator/"

const SECTION_PROGRAM := preload("res://assets/ui/icons/battle_operator/section_program.svg")
const SECTION_BATTLEFIELD := preload("res://assets/ui/icons/battle_operator/section_battlefield.svg")
const SECTION_SIMULATION := preload("res://assets/ui/icons/battle_operator/section_simulation.svg")

const PROGRAM_BASIC := preload("res://assets/ui/icons/battle_operator/program_basic.svg")
const PROGRAM_FRESH := preload("res://assets/ui/icons/battle_operator/program_fresh.svg")
const PROGRAM_IN_TRAINING := preload("res://assets/ui/icons/battle_operator/program_in_training.svg")
const PROGRAM_ROOKIE := preload("res://assets/ui/icons/battle_operator/program_rookie.svg")
const PROGRAM_CHAMPION := preload("res://assets/ui/icons/battle_operator/program_champion.svg")
const PROGRAM_ULTIMATE := preload("res://assets/ui/icons/battle_operator/program_ultimate.svg")
const PROGRAM_MEGA := preload("res://assets/ui/icons/battle_operator/program_mega.svg")

const FIELD_TRAINING_CLEARING := preload("res://assets/ui/icons/battle_operator/field_training_clearing.svg")
const FIELD_TWIN_GROVE := preload("res://assets/ui/icons/battle_operator/field_twin_grove.svg")
const FIELD_FOREST_CROSSING := preload("res://assets/ui/icons/battle_operator/field_forest_crossing.svg")
const FIELD_BROKEN_CLEARING := preload("res://assets/ui/icons/battle_operator/field_broken_clearing.svg")
const FIELD_GRAND_DIGITAL_FIELD := preload("res://assets/ui/icons/battle_operator/field_grand_digital_field.svg")

const ACTION_START_SIMULATION := preload("res://assets/ui/icons/battle_operator/action_start_simulation.svg")


static func section_icon(section_id: String) -> Texture2D:
	match section_id:
		"program":
			return SECTION_PROGRAM
		"battlefield":
			return SECTION_BATTLEFIELD
		"simulation":
			return SECTION_SIMULATION
	return null


static func program_icon(program_id: String) -> Texture2D:
	match program_id:
		"basic":
			return PROGRAM_BASIC
		"random_fresh":
			return PROGRAM_FRESH
		"random_baby":
			return PROGRAM_IN_TRAINING
		"random_rookie":
			return PROGRAM_ROOKIE
		"random_champion":
			return PROGRAM_CHAMPION
		"random_ultimate":
			return PROGRAM_ULTIMATE
		"random_mega":
			return PROGRAM_MEGA
	return null


static func battlefield_icon(battlefield_id: String) -> Texture2D:
	match battlefield_id:
		"training_clearing":
			return FIELD_TRAINING_CLEARING
		"twin_grove":
			return FIELD_TWIN_GROVE
		"forest_crossing":
			return FIELD_FOREST_CROSSING
		"broken_clearing":
			return FIELD_BROKEN_CLEARING
		"grand_digital_field":
			return FIELD_GRAND_DIGITAL_FIELD
	return null


static func action_icon(action_id: String) -> Texture2D:
	if action_id == "start_simulation":
		return ACTION_START_SIMULATION
	return null


static func all_operator_textures() -> Array[Texture2D]:
	return [
		SECTION_PROGRAM,
		SECTION_BATTLEFIELD,
		SECTION_SIMULATION,
		PROGRAM_BASIC,
		PROGRAM_FRESH,
		PROGRAM_IN_TRAINING,
		PROGRAM_ROOKIE,
		PROGRAM_CHAMPION,
		PROGRAM_ULTIMATE,
		PROGRAM_MEGA,
		FIELD_TRAINING_CLEARING,
		FIELD_TWIN_GROVE,
		FIELD_FOREST_CROSSING,
		FIELD_BROKEN_CLEARING,
		FIELD_GRAND_DIGITAL_FIELD,
		ACTION_START_SIMULATION,
	]
