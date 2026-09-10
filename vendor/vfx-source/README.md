# Vendored combat VFX sources

These archives are kept locally so the curated runtime atlases can be rebuilt without network access. Normal game startup and normal Web CI use only the generated atlases under `assets/vfx/library/atlas/`.

| Pack | Author | License | Upstream | SHA-256 |
| --- | --- | --- | --- | --- |
| Pixel Art Spells | DevWizard | CC0 1.0 | https://opengameart.org/content/pixel-art-spells | `bf6e751559942aad40a50359ab5ae8f9750054546de0b21b4519d39904e163cb` |
| Pixel Magic Effects | Foozle / commissioned from lordfitoi | CC0 1.0 | https://foozlecc.itch.io/pixel-magic-sprite-effects | `0c04ab8ee856988b55885a92305d5382459cc855b2a6361c417bb11606f41e9a` |
| PVFX Foundry 0.7.0 | nerijs | CC0 1.0 | https://nerijs.itch.io/pvfx-foundry | `a2a26a2c162ff9d58037c921d6c568d7fa944cfb166e25eef68f908046c29add` |
| Nature - Magic Effect | Cethiel | CC0 1.0 | https://opengameart.org/content/nature-magic-effect | `46f44a30d38b65d55ed1101ce8dc8907e31043958abaf9e2b1894508438815f8` |

All four packs explicitly permit reuse and modification through Creative Commons Zero. Attribution is therefore not required, but the source record is intentionally retained for provenance and maintainability.

## Rebuilding

Install Pillow and run:

```bash
python tools/build_vfx_library.py
```

The builder deterministically regenerates four local atlases and `database/vfx-library.json`. Do not add runtime HTTP downloads for these assets.
