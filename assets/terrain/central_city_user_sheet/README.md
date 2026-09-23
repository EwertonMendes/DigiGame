# Central City supplied ground sheet

This directory contains the normalized runtime atlas used by the Central City ground-sheet visual test.

## Source

The artwork was supplied directly by the project owner in the DigiGame development conversation on 2026-09-23. The original sheet is intentionally not re-authored here. The runtime atlas extracts only each tile's **top surface**, removes the authored side-wall relief, and normalizes every usable surface onto the same flat 64×32 isometric plane.

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
| (2, 3) | road lane rotated for isometric X axis |
| (3, 3) | crosswalk rotated for isometric X axis |
| (4, 3) | road arrow rotated for isometric X axis |

The atlas is deliberately separate from `MCBlocksColorOutline.png`. Central City ground can therefore be visually tested with the supplied sheet without changing the existing building, prop, interior, collision, or service systems.


## Ground-plane contract

Central City ground must render each atlas surface on the engine's exact 64×32 diamond. Ground cells must not render the original source tile's vertical side faces and must not use oversized quads that overlap neighbouring cells.

Road markings are directional assets. The original supplied lane/crosswalk/arrow orientation is used for the isometric Y axis; normalized 90-degree variants are used for the isometric X axis.
