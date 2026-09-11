extends RefCounted
class_name ExperienceCalculator

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _balance = BalanceScript.new()


func reward_for_enemy(recipient_level: int, enemy_level: int, enemy_species: Dictionary, profile: String = "wild") -> int:
	var recipient := maxi(1, recipient_level)
	var enemy := maxi(1, enemy_level)
	var base := _balance.experience_number("rewardBase", 14.0)
	var exponent := _balance.experience_number("rewardLevelExponent", 1.12)
	var rank := String(enemy_species.get("rank", "Rookie"))
	var rank_multiplier := _balance.experience_rank_multiplier("enemyRankRewardMultiplier", rank, 1.0)
	var profile_multiplier := _balance.experience_rank_multiplier("encounterProfileMultiplier", profile.to_lower(), 1.0)
	var difference := enemy - recipient
	var difference_multiplier := 1.0
	if difference > 0:
		difference_multiplier = minf(
			_balance.experience_number("maxAboveMultiplier", 1.6),
			1.0 + float(difference) * _balance.experience_number("perLevelAbove", 0.08)
		)
	elif difference < 0:
		difference_multiplier = maxf(
			_balance.experience_number("minimumBelowMultiplier", 0.1),
			1.0 - float(-difference) * _balance.experience_number("perLevelBelow", 0.12)
		)
	var reward := base * pow(float(enemy), exponent) * rank_multiplier * profile_multiplier * difference_multiplier
	return maxi(1, int(round(reward)))
