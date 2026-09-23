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


## Central City high-resolution source surfaces

Central City uses curated copies of the 1024x1024 files as **source art**, while gameplay stays on DigiGame's original **64x32** isometric grid. `CentralCityArt.gd` samples the authored top face onto the exact gameplay diamond, preserving the new pack's detail without making the player or props look undersized.

Only perimeter cells render the original block side faces. Interior city cells remain flat, while the outer island edge exposes the authored Devil's Work.shop depth for a cleaner isometric silhouette.

Current Central City source surfaces:

| Source file | Central City role |
|---|---|
| `isometric_0072.png` | primary neutral/buildable city-lot floor |
| `isometric_0056.png` | primary garden grass |
| `isometric_0053.png` | checker garden accents |
| `isometric_0058.png` | mint/teal planted terraces |
| `isometric_0054.png` | secondary neutral paving |
| `isometric_0048.png` | teal digital promenade / DigiLab |
| `isometric_0049.png` | blue Hospital district |
| `isometric_0050.png` | purple Archive district |
| `isometric_0063.png` | dark gate / edge paving |
| `isometric_0064.png` | central digital-water plaza and canal |
| `isometric_0009.png` | Data Market district replacement |
| `isometric_0007.png` | luminous Training district grid |

The complete 1024x1024 source library remains under `assets_1024x1024/` behind `.gdignore`. Only selected runtime surfaces are copied into `city_1024/`, so Web/APK exports do not import the entire source collection. Source 0054 is the city's canonical sidewalk/pavement material: it defines the main cross-city promenades, section-block boundaries, service approaches, bridges and the paved civic plaza instead of being scattered decoratively.

MCBlocks has been retired from DigiGame. DigiLab is the first Central City service to receive a dedicated exterior (`assets/world/tblack/digilab.png`); its authored door is aligned to a 0054 forecourt and drives the seamless interior threshold. Hospital, Training, Data Market and Archive still use labeled floor pads until their dedicated structure artwork is authored. Seamless service interiors use Devil's Work.shop surfaces.
