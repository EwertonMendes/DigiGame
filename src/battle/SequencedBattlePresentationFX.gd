extends "res://src/battle/BattlePresentationFX.gd"


func wait_for_current_impact() -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout
