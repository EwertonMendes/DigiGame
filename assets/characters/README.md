# Character Sprite Provenance

DigiGame currently contains legacy prototype character art from commercial Digimon games. These sprites are **not** treated as open-source assets.

## Gabumon

- Character: Gabumon
- Game: Digimon World DS (Nintendo DS)
- Source sheet: The Spriters Resource, asset 41249
- Source page: https://www.spriters-resource.com/ds_dsi/dgmnworldds/asset/41249/
- Source sheet dimensions: 412x203 PNG
- Extraction layout reference: `netraular/DigimonWorldSpriteManager`, `specs/digimon/021.extract.json`, pinned repository revision `06b3c4df09dc5eeaccee511d731f37947b1c8259`
- Rights: official Digimon game art; rights remain with the relevant Digimon/Bandai Namco rights holders. No free-content license is claimed.
- Repository behavior: the original full sprite sheet is not committed. `tools/fetch_character_assets.py` downloads the requested sheet during CI and creates the nine-frame prototype field sheet used by the game.

The current Gabumon integration is intended to match the already-existing legacy Digimon World DS prototype sprites. A future original/licensed art pass should replace proprietary legacy character art if DigiGame moves beyond fan/prototype use.
