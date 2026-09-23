# Devil's Work.shop isometric blocks — selected runtime sprites

DigiGame uses a small curated subset of **2D Pixel Art - Isometric Blocks - Free Sprites** for the hub and tactical battlefield presentation.

- Author / required attribution: **Ajay Karat | Devil's Work.shop**
- Official pack page: https://devilsworkshop.itch.io/big-pixel-isometric-block-pack-free-2d-sprites
- Official current license: **Creative Commons Attribution 4.0 International (CC BY 4.0)**
- License: https://creativecommons.org/licenses/by/4.0/
- Official pack version shown when integrated: **v05.1**
- Binary distribution mirror used for deterministic repository materialization: https://github.com/MLaroucheLaSalleMtl/7382-Team-C-2020
- Mirror revision: **11d22b3c4c1c6e9a720bf7e049feb0ec37229184**
- Mirrored asset directory identifies the source package as **Low_Poly_Pixel_2D_Blocks_DevilsWorkShop_v04**.

The official itch.io page states that the pack contains roughly 700 isometric assets and provides multiple export sizes. DigiGame keeps the original curated 50x50 runtime subset for the Hub/battlefield and now also carries the project-supplied 1024x1024 source collection under `assets_1024x1024/` for high-detail overworld authoring. That complete source folder is intentionally marked with `.gdignore`; only the Central City selections copied into `city_1024/` are imported/exported by Godot.

## Runtime files

| DigiGame file | Upstream file | Git blob SHA | Current use |
|---|---|---|---|
| `blocks/isometric_pixel_0000.png` | `Textures/assets_pixel_50x50/isometric_pixel_0000.png` | `0d619e63570dd0c75f15da9f4f9768db97d0fbab` | grass / primary terrain |
| `blocks/isometric_pixel_0001.png` | `Textures/assets_pixel_50x50/isometric_pixel_0001.png` | `87c195bf9a2fc6dcdbff292cf373a4c274543b8c` | stone/plaza terrain |
| `blocks/isometric_pixel_0005.png` | `Textures/assets_pixel_50x50/isometric_pixel_0005.png` | `77a4f814304a3910ee62fc4da2fed1b5989763a7` | digital data plates |
| `blocks/isometric_pixel_0020.png` | `Textures/assets_pixel_50x50/isometric_pixel_0020.png` | `fa56fc3049abe91f4a3bd53ca0c07c1d4354256e` | water terraces / perimeter |

The committed PNG pixels are unchanged. The source image is a complete 50x50 block, but its visible top face is smaller than the full canvas and does not use the exact same projection as DigiGame's 64x32 gameplay grid. Rendering the entire PNG once per logical tile therefore creates visible spacing and alignment artifacts.

`DevilsWorkshopArt.gd` samples only the authored top-face region and maps it onto an exact 64x32 polygon. Terrain colors are established by an opaque base diamond and the source artwork is blended over it as pixel detail. Full cube sprites remain available for isolated props, but continuous floors use surface polygons so gameplay coordinates, hover overlays and movement remain mathematically identical to the original board.

## Attribution notice

> Isometric block artwork: Ajay Karat | Devil's Work.shop — licensed under CC BY 4.0.

Any future sprites added from this pack should be recorded here with their exact upstream filename and immutable blob hash before being used at runtime.


## Central City 128x64 surfaces

Central City uses curated copies of the 1024x1024 files as **source art**, not as 1024px screen tiles. `CentralCityArt.gd` samples only the authored top face and projects it onto an exact 128x64 isometric gameplay diamond. This preserves source detail while keeping movement/collision geometry deterministic and avoiding visible cube side walls between adjacent floor cells.

Current Central City source surfaces:

| Source file | Central City role |
|---|---|
| `isometric_0056.png` | primary garden grass |
| `isometric_0053.png` | checker garden accents |
| `isometric_0058.png` | mint/teal planted terraces |
| `isometric_0055.png` | primary civic stone |
| `isometric_0054.png` | secondary neutral paving |
| `isometric_0048.png` | teal digital promenade / DigiLab |
| `isometric_0049.png` | blue Hospital district |
| `isometric_0050.png` | purple Archive district |
| `isometric_0063.png` | dark gate / edge paving |
| `isometric_0064.png` | circuit-water canal |
| `isometric_0001.png` | warm Data Market paving |
| `isometric_0007.png` | luminous Training district grid |

The 64x32 Hub and battlefield renderer remains unchanged; the 128x64 contract is isolated to the Central City exterior.
