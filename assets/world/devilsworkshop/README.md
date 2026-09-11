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

The official itch.io page states that the pack contains roughly 700 isometric assets and provides 50x50 no-alias PNG exports. DigiGame deliberately commits only the four 50x50 sprites needed by the current environments so the Web build does not absorb the full asset archive.

## Runtime files

| DigiGame file | Upstream file | Git blob SHA | Current use |
|---|---|---|---|
| `blocks/isometric_pixel_0000.png` | `Textures/assets_pixel_50x50/isometric_pixel_0000.png` | `0d619e63570dd0c75f15da9f4f9768db97d0fbab` | grass / primary terrain |
| `blocks/isometric_pixel_0001.png` | `Textures/assets_pixel_50x50/isometric_pixel_0001.png` | `87c195bf9a2fc6dcdbff292cf373a4c274543b8c` | warm route / staging terrain |
| `blocks/isometric_pixel_0005.png` | `Textures/assets_pixel_50x50/isometric_pixel_0005.png` | `77a4f814304a3910ee62fc4da2fed1b5989763a7` | digital data pads / beacons |
| `blocks/isometric_pixel_0020.png` | `Textures/assets_pixel_50x50/isometric_pixel_0020.png` | `fa56fc3049abe91f4a3bd53ca0c07c1d4354256e` | lower water terraces / perimeter |

The sprites are used without pixel-level modification. DigiGame scales them at runtime to match the existing 64x32 logical isometric grid and applies color modulation for scene-level art direction. No endorsement by Devil's Work.shop is implied.

## Attribution notice

> Isometric block artwork: Ajay Karat | Devil's Work.shop — licensed under CC BY 4.0.

Any future sprites added from this pack should be recorded here with their exact upstream filename and immutable blob hash before being used at runtime.
