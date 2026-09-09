# Skill: DigiGame Gameplay and Progression

Use this skill whenever implementing or modifying combat, roster, leveling, Digi Data, digivolution, degeneration, missions, hub progression, or game-design-facing UI.

## Before coding

1. Read `Plan.md`.
2. Identify which design rules are already finalized and which are listed as open questions.
3. Do not resolve an open design question by accident in low-level code. Prefer a configurable placeholder or ask for a decision when the choice materially affects the game.

## Hard rules

- Battle party maximum: three owned Digimon.
- Digivolution and degeneration never happen during combat.
- DigiLab is the place for digivolution and degeneration.
- Every digivolution or degeneration resets the unit to level 1.
- Evolution is a graph, not a single chain.
- Evolution always supports a level requirement and may support additional requirements.
- Link represents tactical cooperation, not transformation energy.
- Defeating enemy species grants species-specific Digi Data.
- At 100% data, that species becomes eligible for conversion into a new owned Digimon.
- Higher-rank species should grant less data per defeat.
- Hub NPC Digimon are separate entities from player-owned roster Digimon.
- No permanent death.

## Data-driven implementation guidance

Prefer definitions that can express content without changing combat code. Evolution edges should eventually resemble data such as:

- source species/form
- target species/form
- minimum level
- optional item requirements
- optional stat requirements
- optional battle/history requirements
- optional story flags

Digi Data rates should be defined by rank or species data, not in victory-screen conditionals.

Abilities should define target pattern, range, SP cost, power/effect, tags, and targeting restrictions in data whenever practical.

## Tactical design test

For every new combat mechanic, ask:

- Does position affect the decision?
- Can the player understand the outcome before committing?
- Does it create a meaningful tradeoff rather than a strictly dominant button?
- Can enemy AI use or respond to it?
- Does it interact cleanly with a three-unit team?
- Can Link benefit from or respond to it without becoming automatic?

## Scope discipline

Do not implement the complete future system while working on an unrelated task. Build the smallest vertical slice that leaves a clean extension point.
