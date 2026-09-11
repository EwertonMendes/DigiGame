# Battle Retreat Rules

Retreat (`Flee`) is a tactical main action available in escapable encounters.

## Encounter policy

Every encounter can expose an `escapePolicy` with one of three modes:

- `allowed`: use the normal chance calculation.
- `forbidden`: story/important/boss encounters can explicitly lock retreat and provide a UI reason.
- `guaranteed`: special encounters can guarantee disengagement.

Until authored encounter definitions own this value, enemy battle metadata provides a safe default: `boss`, `story`, and `important` profiles forbid retreat; `wild`, `trained`, and `elite` encounters allow it. `EscapeBattleController.set_escape_policy()` is the extension point for mission data.

## Chance

Allowed encounters start at 50% and add:

- relative SPD modifier, clamped to -20%..+20%;
- distance from the acting Digimon to the nearest living enemy: +4% per clear tile after adjacency, capped at +16%;
- +15% after each failed retreat, capped at +30%.

Normal attempts are clamped to 20%..95%. The preview shown before confirmation uses the exact same resolver as the roll.

The player may move first and then attempt retreat, making repositioning a deliberate way to improve the odds.

## Failure and success

A failed retreat consumes the Digimon's main action, ends its turn, and sets total turn recovery to at least 120 CT. The progressive retry bonus applies to the next party attempt.

A successful retreat ends the encounter with `outcome = "escaped"`. Player HP/SP battle resources are committed, but Bits and Digi Data from that encounter are forfeited, including rewards from enemies defeated before escaping. This prevents partial-KO reward farming.

The battle result distinguishes `victory`, `defeat`, and `escaped`, so future mission logic can react without inferring intent from `victory = false`.
