# External Central City assets

Central City can use two external isometric city packs:

- **Dystopian City Starter Pack** — Systemfehler: Ich?
  - Source: https://systemfehler-ich.itch.io/dystopian-city-starter-pack
  - Personal/commercial use and modification are allowed.
  - The author's page explicitly prohibits redistribution/resale of the original or modified asset files.
- **Future Assets Free - 2D City** — MØRI DAICHI
  - Source: https://morithedaichi.itch.io/future-assets-free
  - The author states the pack is free for commercial projects and does not require credit.

## Repository policy

Raw third-party files are **not committed** to this public repository.

`tools/setup_external_city_assets.sh` downloads the packs from their official itch.io pages into the ignored `assets/external/central_city/` staging directory. CI/build jobs run the same staging step before Godot import/export. This lets the game use the licensed assets without turning the source repository into an asset redistribution mirror.

The exported game may contain imported/packed versions as part of the game itself. Do not publish the staged source files separately or upload them as GitHub artifacts.

## Local setup

On Linux/macOS/WSL:

```bash
bash tools/setup_external_city_assets.sh
```

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup_external_city_assets.ps1
```

The setup scripts reuse the local `.cache/external-city-assets/` archives after the first download. Windows setup installs Pillow locally when necessary. Node.js LTS and Python 3 are required.


## Runtime preprocessing

The downloaded sources are never consumed directly by Godot. `tools/prepare_external_city_assets.py` creates an ignored optimized set under `assets/external/central_city/processed/`:

- Future Assets buildings are alpha-trimmed and downscaled to at most 480 px on their largest side.
- Only curated Dystopian sprite-sheet regions used by Central City are extracted.
- `manifest.json` records stable runtime asset names and processed dimensions.

This keeps the exported game much smaller than importing the original 96 MB Future source pack while preserving enough resolution for the 1280×720 campaign camera.
