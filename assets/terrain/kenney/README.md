# Kenney Isometric Landscape — Selected CC0 Assets

This directory is populated by `tools/fetch_cc0_assets.py` during CI.

Asset pack: **Isometric Landscape**  
Author: **Kenney Vleugels / Kenney**  
License: **Creative Commons Zero (CC0 1.0)**  
Official site: https://kenney.nl/  
License URL: https://creativecommons.org/publicdomain/zero/1.0/

The pack's included license states that the graphics may be used in personal and commercial projects and that credit is appreciated but not mandatory.

For reproducible remote builds, the selected files are downloaded from the public `ETdoFresh/kenney.nl` mirror pinned to commit:

`45df48c4d45f8716216b1a9e22df0b69cd9f5932`

Selected source files for the first visual prototype:

- `isometriclandscape/PNG/landscapeTiles_010.png` → `grass.png`
- `isometriclandscape/PNG/landscapeTiles_014.png` → `earth.png`
- `isometriclandscape/PNG/landscapeTiles_015.png` → `lush_grass.png`

The fetch script verifies each downloaded file against its pinned Git blob SHA before writing it into this directory.
