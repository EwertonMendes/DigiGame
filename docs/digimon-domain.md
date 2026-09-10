# Digimon Domain Model

DigiGame separates species metadata, persistent individual progression, and battle-only state.

## Species catalogue

`database/base-digimon-list.json` is the canonical catalogue of Digimon species. `seed` identifies a species and never identifies an individual Digimon.

Every species record includes tactical movement metadata:

- `MOV`: natural movement range for that species/form.
- `movementType`: terrain interaction category (`ground`, `flying`, `aquatic`, `amphibious`, `hover`, etc.).

Species base stats (`hp`, `mp`, `atk`, `def`, `speed`) are growth inputs, not saved individual values.

## Digimon instance

Every generated Digimon receives its own UUID. The same individual keeps that UUID through Digivolution and Degeneration.

Persistent instance state includes:

- `id`
- `speciesSeed`
- `level` / `exp`
- `potential`
- small individual `aptitudes` (-3..+3%)
- permanent `training`
- learned skills / equipment
- current persistent resources
- evolution history

Digivolution changes `speciesSeed`, resets level and EXP to 1/0, increases Potential, and preserves identity/training/history.

## Stat calculation

Normal battle stats are calculated from:

`species base × level growth × aptitude × training`

The initial balance coefficients live in `DigimonStatCalculator.gd` and are intentionally centralized so combat tuning does not leak into UI or battle controllers.

`SPD` and `MOV` are independent. Movement is calculated as:

`species MOV + individual mobility training + temporary battle modifiers`

MOV has a hard battle cap of 8 in the initial ruleset.

## Potential and training

Potential ranges from 0 to 100 and represents the individual's long-term development capacity. Potential does not directly increase stats.

Training capacity:

`10 + floor(Potential / 2)`

Normal stat training consumes one capacity point per point, with an initial cap of 30 points per stat. Each point currently contributes +0.4% to that stat.

Mobility training is deliberately expensive because one tile of tactical movement is highly valuable:

- Mobility I: Potential 20, costs 20 capacity, MOV +1.
- Mobility II: Potential 70, costs another 30 capacity, MOV +1.

## Potential gain

Digivolution: `2 + floor(level / 10)`

Degeneration: `4 + floor(level / 10)`

Degeneration intentionally gives more Potential to reward cycling through forms and exploring evolution routes.

## Generation

`DigimonFactory` is the only intended entry point for creating new individual Digimon.

Player/DigiLab creation can use scan completion to grant a small starting Potential bonus (100% = 0, 125% = 1, 150% = 2, 175% = 3, 200% = 5). This only saves development time; it does not change the final Potential ceiling.

Enemy generation uses the same instance model. Encounter profiles (`wild`, `trained`, `elite`, `boss`) change level/training/potential rather than secretly changing the species base stats.

## Battle state

`BattleDigimon` wraps a persistent `DigimonInstance` with battle-only state such as current battle HP/MP, statuses, temporary stat/MOV modifiers, and CT initiative. Temporary effects never overwrite the species catalogue or permanent training.

## Speed-based turn timeline

Turns are scheduled by `TurnScheduler.gd`, not by scene order. Each battle actor charges CT toward a ready threshold of 100 using its current final SPD:

`initiative rate = SPD ^ 0.5`

The square-root curve deliberately compresses large SPD gaps so faster Digimon receive earlier and potentially more frequent turns without raw SPD scaling the turn count linearly.

When nobody is ready, the scheduler advances virtual battle time only as far as necessary for the next actor to reach CT 100. Player decision time never advances the timeline, so combat remains fully turn-based.

After acting, the current default recovery cost is 100 CT. The scheduler API already supports variable recovery costs, initiative delay/advance, and direct CT changes so future skills such as Haste, Slow, Delay, Quick, or heavy attacks can alter the visible timeline without replacing the scheduler.

Ties are deterministic: higher accumulated CT wins first, then higher final SPD, then the actor's stable individual UUID.

The Turn Order HUD shows the current actor plus a simulated preview of upcoming turns. This preview is read-only and uses the same scheduler rules as the real battle state. Desktop shows a longer queue, while compact/touch layouts show fewer slots. Timeline portraits can focus the camera without changing selection or turn ownership.
