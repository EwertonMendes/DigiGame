# Central City supplied ground sheet

This directory contains the normalized runtime atlas used by the Central City ground-sheet visual test.

## Source

The artwork was supplied directly by the project owner in the DigiGame development conversation on 2026-09-23. The original sheet is intentionally not re-authored here; the runtime atlas crops and normalizes only the ground surfaces required by the city test.

## Runtime atlas

`central_city_ground_atlas.png` is a compact 5-column atlas. Every slot is 64×64 px with transparent padding and a consistent isometric top anchor.

| Atlas cell | Role |
| --- | --- |
| (0, 0) | road plain |
| (1, 0) | road lane |
| (2, 0) | road edge |
| (3, 0) | road alternate direction |
| (4, 0) | crosswalk A |
| (0, 1) | crosswalk B |
| (1, 1) | road arrow |
| (2, 1) | road tech/intersection |
| (3, 1) | gray pavement |
| (4, 1) | tan pavement |
| (0, 2) | stone pavement |
| (1, 2) | tech pavement |
| (2, 2) | grass |
| (3, 2) | grass alternate |
| (4, 2) | sand |
| (0, 3) | dirt |
| (1, 3) | water |

The atlas is deliberately separate from `MCBlocksColorOutline.png`. Central City ground can therefore be visually tested with the supplied sheet without changing the existing building, prop, interior, collision, or service systems.
