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
| `blocks/isometric_pixel_0001.png` | `Textures/assets_pixel_50x50/isometric_pixel_0001.png` | `87c195bf9a2fc6dcdbff292cf373a4c274543b8c` | stone/plaza terrain |
| `blocks/isometric_pixel_0005.png` | `Textures/assets_pixel_50x50/isometric_pixel_0005.png` | `77a4f814304a3910ee62fc4da2fed1b5989763a7` | digital data plates |
| `blocks/isometric_pixel_0020.png` | `Textures/assets_pixel_50x50/isometric_pixel_0020.png` | `fa56fc3049abe91f4a3bd53ca0c07c1d4354256e` | water terraces / perimeter |

The committed PNG pixels are unchanged. The source image is a complete 50x50 block, but its visible top face is smaller than the full canvas and does not use the exact same projection as DigiGame's 64x32 gameplay grid. Rendering the entire PNG once per logical tile therefore creates visible spacing and alignment artifacts.

`DevilsWorkshopArt.gd` samples only the authored top-face region and maps it onto an exact 64x32 polygon. Terrain colors are established by an opaque base diamond and the source artwork is blended over it as pixel detail. Full cube sprites remain available for isolated props, but continuous floors use surface polygons so gameplay coordinates, hover overlays and movement remain mathematically identical to the original board.

## Attribution notice

> Isometric block artwork: Ajay Karat | Devil's Work.shop — licensed under CC BY 4.0.

Any future sprites added from this pack should be recorded here with their exact upstream filename and immutable blob hash before being used at runtime.
