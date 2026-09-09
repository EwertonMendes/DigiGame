# DigiGame Agent Guide

This repository is designed to be safely developed by AI coding agents through GitHub without requiring a local Godot installation.

## Project mission

DigiGame is a single-player isometric tactical RPG inspired by the progression style of the Nintendo DS Digimon Story games. The final game should combine a compact story campaign, meaningful roster progression, branching digivolution and degeneration, tactical battles with teams of up to three player Digimon, and a growing hub populated by useful NPC Digimon.

`Plan.md` is the product and game-design source of truth. Read it before changing gameplay systems.

## Technical baseline

- Engine: Godot 4.7.x.
- Runtime language: GDScript only.
- Renderer: GL Compatibility.
- Web and desktop builds must use the same gameplay code path.
- Web export is a first-class target, not a secondary port.
- Never add C# runtime code. The project was intentionally migrated away from Godot C# so the Web build remains supported.
- Repository documentation, code comments, identifiers intended to be readable prose, commit messages, and agent-authored content must use United States English.
- Keep gameplay data data-driven where practical. Prefer Resources, dictionaries, configuration files, and small reusable systems over hard-coded one-off behavior.

## Required agent workflow

1. Read `AGENTS.md`, `Plan.md`, and the relevant skill under `.agents/skills/`.
2. Work on a focused feature or fix branch unless the user explicitly requests a direct change to `master`.
3. Make the smallest coherent change that satisfies the task.
4. Preserve Web compatibility.
5. Run the GitHub Actions Web workflow for every meaningful runtime change.
6. Inspect failed job logs instead of guessing.
7. For visual changes, inspect the generated browser screenshot artifact before considering the work complete.
8. Do not merge a runtime change while the Web build or browser smoke test is failing.
9. After merge to `master`, verify the GitHub Pages deployment when the task affects the playable build.

## Game-design invariants

The following rules are intentional and must not be silently changed:

- The player fields at most three owned Digimon in a battle.
- Digivolution and degeneration never occur during combat.
- Digivolution and degeneration are performed in the DigiLab outside battle.
- A Digimon resets to level 1 every time it digivolves or degenerates.
- Digivolution paths can branch. A species may have multiple possible next forms and multiple valid previous forms.
- Level is a standard evolution requirement. Additional requirements may include items, attributes, battle history, or other explicit conditions.
- Combat should reward positioning, movement, range, area patterns, terrain interaction, status effects, forced movement, and team composition.
- The Link system rewards coordinated positioning and actions between allied Digimon. Link is not an in-combat evolution resource.
- New owned Digimon are primarily acquired through Digi Data. Defeating a species grants data for that species; at 100%, the player may convert the data into a new Digimon.
- Digi Data gain is rank-dependent: basic forms grant more data per defeat and high-rank forms, especially Mega, grant less.
- Hub Digimon are NPCs and are separate from the player's owned roster.
- Story maps should be intentionally designed. Procedural generation is appropriate for optional or repeatable content, not as a substitute for authored story encounters.
- There is no permanent death for the player's Digimon.

If a requested implementation conflicts with an invariant, surface the conflict before changing the rule.

## Architecture expectations

Keep systems separated by responsibility. As the project grows, prefer this direction:

- `src/combat/`: turn flow, actions, targeting, movement, damage, status, Link.
- `src/digimon/`: owned Digimon state, species definitions, stats, moves, growth.
- `src/digivolution/`: evolution graph, requirements, DigiLab operations.
- `src/collection/`: Digi Data, conversion, roster storage.
- `src/world/`: maps, missions, sectors, encounters, hub progression.
- `src/ui/`: battle UI, DigiLab, roster, mission selection, HUD.
- `assets/resources/`: data resources rather than behavior.
- `scenes/`: composition and presentation.

Do not perform a large folder migration just to match this target layout. Move toward it incrementally when implementing the corresponding systems.

## Asset policy

- Prefer original assets, CC0 assets, or assets with an explicit license that permits redistribution and the intended use.
- Record third-party asset name, author/source, license, source URL, pinned version/commit when possible, and the files actually used.
- Never assume that an image found online is safe to redistribute.
- Keep reproducible third-party downloads pinned and integrity-checked when the binary asset is fetched in CI.
- Do not introduce new ripped proprietary Digimon art or other unlicensed copyrighted game assets as part of autonomous agent work.
- Existing legacy prototype assets may remain unless the user asks to replace them.

See `.agents/skills/asset-licensing/SKILL.md` before adding external art.

## Definition of done for runtime work

Runtime work is complete only when:

- Godot imports the project without script parse errors.
- The Web export succeeds.
- Chromium starts the exported game without browser runtime errors.
- Responsive canvas checks pass.
- Visual work has a reviewed screenshot artifact.
- The change does not knowingly violate `Plan.md`.
- Third-party asset provenance is recorded when applicable.

## Skills

- `.agents/skills/digigame-gameplay/SKILL.md`: gameplay and progression rules.
- `.agents/skills/godot-web-ci/SKILL.md`: Godot/Web implementation and GitHub Actions workflow.
- `.agents/skills/visual-validation/SKILL.md`: visual and responsive validation.
- `.agents/skills/asset-licensing/SKILL.md`: external asset selection and provenance.
