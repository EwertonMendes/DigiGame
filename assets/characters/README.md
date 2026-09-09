# Character Sprite Provenance

DigiGame contains legacy prototype character art from commercial Digimon games. These sprites are **not** open-source assets.

All runtime field sheets are stored directly in `assets/characters/` and use the same 12-frame directional layout: `down_left` (0-2), `down_right` (3-5), `up_left` (6-8), `up_right` (9-11).

Agumon, Gabumon, and Greymon come from Digimon World DS sheets prepared by `tools/fetch_character_assets.py`. Koromon, Tanemon, and Veemon are prepared by `tools/fetch_enemy_assets.py` from the exact With the Will / Photobucket source images supplied for this prototype:

- Koromon: `002_Koromon.png`, SHA-256 `dac126e72b5b96ebd018aef0e79bb1baba4caa2b493e21309dca8d25de4a7595`.
- Tanemon: `006_Tanemon.png`, SHA-256 `4f276334f6b6e5cb58348de9ad7e9cc00b9892929b37cc355fb2400a1124c44f`.
- Veemon: `026_V-mon.png`, SHA-256 `dbb4df0d4047e7268a6be5a382b898235ec5f46256a66f15c9f626464fd77c7d`.

The Photobucket images contain portraits, battle art, field sprites, a solid blue background, and watermark overlays. Extraction intentionally uses only clean field-sprite cells. Background is removed from the frame edges, then every sprite is bottom-centered in a fixed 32x32 cell so changing visible bounds cannot make animation frames jump. Where a source direction is partially obscured by watermarking, a clean pose is repeated or mirrored instead of retaining watermark pixels.

Rights to Digimon and the official game artwork remain with their relevant Digimon/Bandai Namco rights holders. No free-content license is claimed. These assets are suitable only for the current fan/prototype context and should be replaced by original or properly licensed artwork before commercial distribution.
