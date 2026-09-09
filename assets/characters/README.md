# Character Sprite Provenance

DigiGame contains legacy prototype character art from commercial Digimon games. These sprites are **not** open-source assets.

All runtime character sheets now use the same directional frame order: `down_left` (0-2), `down_right` (3-5), `up_left` (6-8), `up_right` (9-11).

Agumon, Gabumon, and Greymon come from Digimon World DS sheets prepared by `tools/fetch_character_assets.py`.

Koromon and Tanemon are prepared by `tools/fetch_enemy_assets.py` from the With the Will / Photobucket source images used by this prototype:

- Koromon: `002_Koromon.png`, SHA-256 `dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595`.
- Tanemon: `006_Tanemon.png`, SHA-256 `4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f`.

For those baby Digimon, extraction clears both edge-connected background blue and any remaining source-blue pixels trapped inside the sprite component. Koromon's source-facing convention is opposite Tanemon's, so its left/right assignments are explicitly swapped when the runtime sheet is built.

Veemon uses the exact user-supplied transparent source sheet from the September 9, 2026 sprite correction pass (source SHA-256 `fa75ac1c90c4f5ed199a83b36c2a31b0833fd9d2edec101b7008cca08824cc55`). The twelve field poses were taken directly from that sheet: the second source row provides the two front-facing diagonals and the first source row provides the two back-facing diagonals, three animation frames per direction.

Because that Veemon sheet is laid out differently from the other source sheets, its runtime PNG is a dedicated 480x40 strip with twelve fixed 40x40 cells. Every pose uses one global scale, a shared ground baseline, and body-centered horizontal anchoring. This prevents the visible character from jumping when frames change while preserving the original pose proportions. The committed `assets/characters/veemon.png` is authoritative and `tools/fetch_enemy_assets.py` intentionally does not overwrite it.

Rights to Digimon and the official game artwork remain with their relevant Digimon/Bandai Namco rights holders. No free-content license is claimed. These assets are suitable only for the current fan/prototype context and should be replaced by original or properly licensed artwork before commercial distribution.
