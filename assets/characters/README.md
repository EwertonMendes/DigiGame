# Character Sprite Provenance

DigiGame currently contains legacy prototype character art from commercial Digimon games. These sprites are **not** treated as open-source assets.

## Directional field sprites

Agumon, Gabumon, and Greymon currently use official **Digimon World DS** field sprite sheets sourced through The Spriters Resource. The original full sheets are not committed by this workflow. `tools/fetch_character_assets.py` downloads the pinned/source-identified sheets during CI and creates normalized directional PNGs for the game.

Every generated runtime sheet contains 12 frames in this order:

1. `down_left` — 3 frames
2. `down_right` — 3 frames
3. `up_left` — 3 frames
4. `up_right` — 3 frames

The mapping follows extraction specs from `netraular/DigimonWorldSpriteManager`, pinned repository revision `06b3c4df09dc5eeaccee511d731f37947b1c8259`:

- Agumon: The Spriters Resource sheet `48418`; extraction spec `009.extract.json`.
- Gabumon: The Spriters Resource sheet `41249`; extraction spec `021.extract.json`.
- Greymon: The Spriters Resource sheet `48406`; extraction spec `073.extract.json`.

For source sheets whose spec only provides left-facing diagonals, the right-facing frames are mirrored exactly as declared by the extraction spec. Background removal is performed per frame using border-connected segmentation rather than a global color key, so transparent field sprites do not retain rectangular source backgrounds or erase similarly colored interior sprite pixels.

Rights to Digimon and the official game artwork remain with their relevant Digimon/Bandai Namco rights holders. No free-content license is claimed. These assets are appropriate only for the current fan/prototype context; an original or properly licensed art pass should replace them before any commercial distribution.
