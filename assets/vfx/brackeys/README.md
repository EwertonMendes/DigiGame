# Brackeys VFX Bundle

Vendored game-ready source assets from the **Brackeys VFX Bundle** for DigiGame.

- Upstream project: https://github.com/Brackeys/vfx-in-godot
- Bundle page: https://brackeysgames.itch.io/brackeys-vfx-bundle
- Pinned upstream commit: `23b58f272b828b0a894ed7ef72fbf9033ee9d177`
- License: **CC0 1.0 / public domain** (commercial use and modification permitted; attribution not required)
- Upstream authors credited by Brackeys: Kenney, Picster, Thomas Iché and CodeManu

The complete raw bundle is kept under this directory in its original category layout:

- `flipbooks/` — animated flipbook textures
- `particles/` — particle textures/masks
- `predrawn/` — pre-drawn animated VFX spritesheets

Upstream `.import` files and `.DS_Store` metadata are intentionally not vendored. Godot generates fresh import metadata for DigiGame's final `res://assets/vfx/brackeys/...` paths.

Do not download these assets at runtime. They are committed so Web/Desktop/Mobile builds remain deterministic and offline-safe.
