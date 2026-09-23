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

The script requires Node/npm, `unzip`, and internet access.
