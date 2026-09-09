# Character Sprite Provenance

DigiGame contains legacy prototype character art from commercial Digimon games. These sprites are **not** open-source assets.

Agumon, Gabumon, and Greymon come from Digimon World DS sheets prepared by `tools/fetch_character_assets.py` and use the normalized 12-frame directional runtime layout: `down_left` (0-2), `down_right` (3-5), `up_left` (6-8), `up_right` (9-11).

Koromon and Tanemon are prepared by `tools/fetch_enemy_assets.py` from the With the Will / Photobucket source images used by this prototype:

- Koromon: `002_Koromon.png`, SHA-256 `dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595`.
- Tanemon: `006_Tanemon.png`, SHA-256 `4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f`.

For those baby Digimon, extraction clears both edge-connected background blue and any remaining source-blue pixels trapped inside the sprite component. Koromon's source-facing convention is opposite Tanemon's, so its left/right assignments are explicitly swapped when the runtime sheet is built.

Veemon uses the exact transparent 296x32 spritesheet supplied by the project owner in the latest September 9, 2026 correction pass, SHA-256 `45f0399371098105fe07afb6e3c1ed97172f02d1d25856036c90c9ad31ddb1c7`. The file is committed directly as `assets/characters/veemon.png` and is authoritative; `tools/fetch_enemy_assets.py` intentionally does not overwrite it.

That Veemon file contains nine 32x32 cells separated by one transparent spacer column, so its width is 296 pixels rather than 288. It must **not** be sliced with `Sprite2D.hframes = 9`, because equal subdivision would cut at fractional boundaries and shift the visible sprite between frames. Veemon therefore uses the `spaced_9_32` runtime layout, which crops each exact 32x32 cell at a 33-pixel stride. The right-facing variants are horizontal mirrors of the corresponding supplied left-facing walk frames.

Rights to Digimon and the official game artwork remain with their relevant Digimon/Bandai Namco rights holders. No free-content license is claimed. These assets are suitable only for the current fan/prototype context and should be replaced by original or properly licensed artwork before commercial distribution.
