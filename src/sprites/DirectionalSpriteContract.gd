extends RefCounted
class_name DirectionalSpriteContract

## Canonical contract shared by battle actors, overworld followers, and previews.
## Every directional_12 strip contains idle, step A, and step B for each facing.

const FRAME_BASE := {
	"down_left": 0,
	"down_right": 3,
	"up_left": 6,
	"up_right": 9,
}
const PHASE_COUNT := 3
const WALK_PHASES: Array[int] = [0, 1, 0, 2]


static func has_direction(direction: String) -> bool:
	return FRAME_BASE.has(direction)


static func idle_frame(direction: String) -> int:
	return int(FRAME_BASE.get(direction, FRAME_BASE["up_right"]))


static func phase_frame(direction: String, phase: int) -> int:
	return idle_frame(direction) + clampi(phase, 0, PHASE_COUNT - 1)


static func walk_frame(direction: String, sequence_index: int) -> int:
	var normalized_index := posmod(sequence_index, WALK_PHASES.size())
	return phase_frame(direction, WALK_PHASES[normalized_index])

