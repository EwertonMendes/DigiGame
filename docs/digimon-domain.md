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

`BattleDigimon` wraps a persistent `DigimonInstance` with battle-only state such as current battle HP/MP, statuses, and temporary stat/MOV modifiers. Temporary effects never overwrite the species catalogue or permanent training.
