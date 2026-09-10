extends RefCounted
class_name DigimonProgression

const MAX_LEVEL := 99
const MAX_POTENTIAL := 100
const BASE_XP := 18.0
const LEVEL_EXPONENT := 1.60
const RANK_XP_MULTIPLIER := {
	"Fresh": 0.65,
	"In-Training": 0.80,
	"Rookie": 1.00,
	"Champion": 1.15,
	"Ultimate": 1.35,
	"Mega": 1.60,
	"Ultra": 1.80,
	"Armor": 1.10,
	"Hybrid": 1.30,
}


func exp_to_next_level(instance: DigimonInstance, species: Dictionary) -> int:
	if instance == null or instance.level >= MAX_LEVEL:
		return 0
	var rank := String(species.get("rank", "Rookie"))
	var rank_multiplier := float(RANK_XP_MULTIPLIER.get(rank, 1.0))
	return maxi(1, int(round(BASE_XP * pow(float(instance.level), LEVEL_EXPONENT) * rank_multiplier)))


func add_experience(instance: DigimonInstance, species: Dictionary, amount: int) -> int:
	if instance == null or amount <= 0 or instance.level >= MAX_LEVEL:
		return 0
	instance.exp += amount
	var levels_gained := 0
	while instance.level < MAX_LEVEL:
		var required := exp_to_next_level(instance, species)
		if required <= 0 or instance.exp < required:
			break
		instance.exp -= required
		instance.level += 1
		levels_gained += 1
	if instance.level >= MAX_LEVEL:
		instance.level = MAX_LEVEL
		instance.exp = 0
	return levels_gained


func potential_gain_for_digivolution(level_before_reset: int) -> int:
	return 2 + maxi(0, level_before_reset) / 10


func potential_gain_for_degeneration(level_before_reset: int) -> int:
	return 4 + maxi(0, level_before_reset) / 10


func add_potential(instance: DigimonInstance, amount: int) -> int:
	if instance == null or amount <= 0:
		return 0
	var before := instance.potential
	instance.potential = clampi(instance.potential + amount, 0, MAX_POTENTIAL)
	return instance.potential - before
