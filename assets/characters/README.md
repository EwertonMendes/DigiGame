# Character Sprite Provenance

DigiGame contains legacy prototype character art from commercial Digimon games. These sprites are **not** open-source assets.

The normalized runtime sheets used by the current battle scene are committed to the repository. A clean checkout therefore does not have to contact sprite-hosting sites before the game can run. The old fetch/preparation scripts remain only as optional provenance/reproduction tools and are no longer part of normal Web CI.

Agumon, Gabumon, and Greymon come from Digimon World DS sheets prepared by `tools/fetch_character_assets.py` and use the normalized 12-frame directional runtime layout: `down_left` (0-2), `down_right` (3-5), `up_left` (6-8), `up_right` (9-11). Their committed runtime sheets are `assets/characters/agumon.png`, `assets/characters/gabumon.png`, and `assets/characters/greymon.png`.

Koromon and Tanemon were prepared by `tools/fetch_enemy_assets.py` from the With the Will / Photobucket source images used by this prototype and their normalized runtime sheets are also committed:

- Koromon source: `002_Koromon.png`, SHA-256 `dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595`.
- Tanemon source: `006_Tanemon.png`, SHA-256 `4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f`.

For those baby Digimon, extraction clears both edge-connected background blue and any remaining source-blue pixels trapped inside the sprite component. Koromon's source-facing convention is opposite Tanemon's, so its left/right assignments are explicitly swapped when the runtime sheet is built.

Veemon uses the latest transparent spritesheet supplied directly by the project owner in the September 9, 2026 correction pass. The current runtime file is `assets/characters/veemon/field.png` and uses the `spaced_9_32` runtime layout: nine 32x32 cells separated by one transparent spacer column. It must not be sliced with `Sprite2D.hframes = 9`; the runtime crops each exact 32x32 cell at a 33-pixel stride. The right-facing variants are horizontal mirrors of the corresponding supplied left-facing walk frames.

MetalGreymon uses the Digimon World DS sheet listed as asset `48322` on The Spriters Resource, with the project owner's With the Will / historical Photobucket link as the original reference. The exact downloaded source used for the September 12, 2026 extraction is 395x432 and has SHA-256 `2f370926a0585787dfbae2b575509f8698a80539c8a68c87d3586b1d99a05665`. `tools/fetch_metalgreymon_field.py` extracts only the three clean alpha-backed field-walk components, preserving their pixels without color-key background removal, and writes `assets/characters/metalgreymon/field.png` as a 12-cell `directional_12` sheet. The source only contains one isometric walk direction plus its horizontal mirror; because it contains no distinct rear-facing field cycle, the normalized `up_left`/`up_right` groups intentionally reuse the matching horizontal walk cycles rather than fabricating non-source artwork.

`tools/validate_runtime_assets.py` verifies all battle-critical committed character sheets together with the terrain, VFX, and UI fonts without making network requests.

Rights to Digimon and the official game artwork remain with their relevant Digimon/Bandai Namco rights holders. No free-content license is claimed. These assets are suitable only for the current fan/prototype context and should be replaced by original or properly licensed artwork before commercial distribution.
