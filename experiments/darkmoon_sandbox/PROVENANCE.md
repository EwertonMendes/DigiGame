# Asset provenance

| Asset | Source | Distribution / files |
| --- | --- | --- |
| City atlas | User-supplied Darkmoon_City_Assets_Only.zip; Digimon World Dusk artwork | Explicitly requested by the user for inclusion in the repository/game on 2026-10-14; assets/scenery/darkmoon_city/tiles_8x8.png |
| Assembled modules | Native cells from the same supplied atlas | assets/scenery/darkmoon_city/pieces.png; deterministic cell layout in brushes.json |
| Trainer and Koromon | Existing DigiGame legacy assets | Existing assets retained; no additional character pixels introduced |

Source atlas SHA-256:
`a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a`.
The asset manifest records both shipped PNG hashes and the user's authorization.
No independent third-party license is asserted. The user's explicit instruction
supersedes the earlier attachment's private-only handling requirement.

Pixels retain native RGBA, color and transparency. Module assembly copies whole
8×8 cells without scaling or recoloring. Original maps, reference images, temporary
crops, unused 16/32-pixel atlases and source ZIPs are not shipped. All 3,825 valid
source cells remain available for building original scenery.
