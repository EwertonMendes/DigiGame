# World area runtime

The campaign overworld starts in `scenes/world/world_root.tscn`. The existing `hub.tscn` remains a developer-only integration laboratory.

## Runtime contract

- `WorldRoot` owns the persistent player, camera, followers, HUD and service host for the current large area.
- Each large explorable region is one scene. Central City is `scenes/world/central_city_area.tscn`.
- `WorldAreaScene` builds every authored section before gameplay begins. Sections organize authoring data only; they are never streamed, queued, popped in or unloaded while the player walks.
- `WorldAreaSection` owns local terrain, collision, props, buildings and interactables inside the already-loaded area scene.
- `InteractionSystem` resolves world interactions centrally by explicit priority and distance.
- `WorldServiceHost` composes the existing DigiLab, Training, Hospital and Digimon screens without inheriting the legacy Hub gameplay chain.
- `WorldState` persists region, area, exact player position, facing and world-state dictionaries. The existing spatial-cell field remains serialized for save compatibility, but it no longer controls rendering.
- Battle return is contextual: normal gameplay returns to the current world area, while battles deliberately launched from the developer Hub return there.

## Area boundaries

Streaming is intentionally not used inside a large area. A future transition from Central City to another major region such as Green Sector should load a different area scene at an authored gate/transport boundary. That is the correct place for a loading transition, resource handoff and save checkpoint.

Small and medium interiors remain seamless. Service entrances keep the persistent player/camera and use the existing zoom + digital wash transition without changing scenes. While inside, the already-loaded exterior is hidden and its processing is paused; it is restored before the interior transition reveals the city again.

## Central City

`assets/resources/world/central_city.json` defines the 5×5 authoring grid used to compose the complete Central City scene: Central Plaza, DigiLab, Hospital, Training, Data Market, Archive, canals, gardens, residences and city gates.

All 25 sections are present before `[World] READY`. Central City stays on the same **64×32** isometric gameplay grid as the rest of the overworld, but paved exterior surfaces no longer expose that gameplay cell size visually. `city_paver_floor.gdshader` receives continuous world-grid UVs and renders four micro-pavers per gameplay-cell axis, so streets and plazas read as fine continuous pavement while movement, buildings and collision remain on the canonical grid. The exterior ground is still globally batched: one seam-protection base mesh plus one detail mesh per curated surface type. Area construction yields after small batches of sections behind the opaque loading screen, keeping the first frame responsive without terrain pop-in.

Walking across section boundaries only changes district/title metadata; it never mutates the scene tree. This prevents mobile traversal from paying terrain construction/destruction costs and removes visible terrain pop-in.

Central City's **hardscape top surface is procedural** rather than sourced from one large visual tile per gameplay cell. The medium-gray micro-paver field is now intentionally continuous: it is the city's circulation layer. Roads and pedestrian paths are read from the negative space between raised building foundations, planted civic islands, water and future structures instead of from brighter tactical-looking stripes painted onto gameplay cells. Deterministic per-stone and broad-area tonal variation prevents the field from reading as a checkerboard. Digital water still uses curated source art, while grass is concentrated inside raised landscape islands rather than large square ground patches.

MCBlocks has been removed from the project. DigiLab now uses the dedicated `assets/world/tblack/digilab/digilab.png` exterior, positioned against its 0054 forecourt with the seamless interior threshold anchored to the visible front door. Entering the threshold plays the supplied closed → semi-open → open door frames before the interior handoff. The exterior keeps the fully-open frame while the player is inside; when the city is revealed again, the same sequence plays in reverse (open → semi-open → closed) before movement is unlocked. The DigiLab interior floor currently uses only the project-authored `floor-1.png` from `assets/world/tblack/digilab/floor/`. Its complete 1024×1024 authored top face is sampled onto every exact 64×32 gameplay diamond, keeping the room visually uniform while preserving the canonical movement/collision grid. `floor-2.png` remains available as source art but is not rendered in the DigiLab interior. The original 1254×1254 AI-authored wall PNGs under `assets/world/tblack/digilab/wall/` are now treated strictly as visual reference/source art. Runtime rendering uses a deterministic vector kit under `assets/world/tblack/digilab/wall/runtime/`: every straight module owns exactly one 64×32 grid edge, all full-height pieces share the same 72 px architectural height, the front divider intentionally uses 34 px, and the doorway owns exactly four X-grid edges. The four room corners now have orientation-specific connector sleeves that overlap half an adjacent wall edge on both sides, while the doorway contains matching low-wall sleeves; this removes floating posts and visible sticker-like seams. Repeated wall geometry is submitted through three `MultiMeshInstance2D` batches and the 18×14 DigiLab floor is rendered through one 252-instance MultiMesh rather than hundreds of individual scene nodes. DigiLab wall movement uses the existing blocked-cell map only, avoiding redundant per-tile physics shapes. Anchors remain fixed integer grid vertices and all runtime SVGs render at scale 1 with no trimming, resizing, mirroring or rotation. Hospital, Training, Data Market and Archive remain accessible through labeled service pads until their dedicated structure artwork is authored. Other seamless interiors continue to use Devil's Work.shop surfaces, so no runtime dependency on the retired atlas returns.

## Adding a major area

Add a dedicated area scene and its data file, register the data in `WorldAreaCatalog`, and load that scene only at a major-region boundary. Do not introduce proximity streaming inside the area. Large-area loading is expected to happen once at the transition; exploration afterwards must be stable.

## Developer Hub

The old prototype Hub is not the normal application entry point. Development builds expose a **TEST HUB** action in the Developer Toolkit. Automated Web QA can use `?debug=1&test_hub=1`; the route is rejected when developer tools are unavailable.


## Performance contract

Central City treats authoring sections as data boundaries, never rendering boundaries. The octagonal island currently renders 4,341 authored ground cells; clipped corner cells are true non-walkable digital void rather than hidden floor. Ground draw calls are bounded by the small curated surface palette instead of section count, and the area regression keeps the runtime node budget below its existing limit.

### Central City landscaping

Urban structure and repeatable decoration are authored separately. `CentralCityUrbanPlan.gd` creates raised building foundations, garden islands and the Central Plaza pool frame. DigiLab, Training Center and Hospital foundations are derived from the same measured source-space footprints already used by their collision code, so the visual lot cannot drift away from the building. The platforms use a light procedural top and visible graphite side faces, making the buildings read as constructed on civic lots above the surrounding gray circulation field.

`CentralCityDecor.gd` then loads the replaceable catalog/profiles in `assets/resources/world/central_city_decor.json`. The rejected prototype decoration families were removed; the runtime prop kit currently contains the approved blue/yellow street lamps plus a matched pair of NE/NW futuristic benches under `assets/world/tblack/city/props_v2/`. All are normalized as individual transparent PNG sprites and nearest-filtered on the same fixed isometric ground plane as the rest of the city. Placements use fractional logical coordinates and small ground footprints register directly with existing polygon walkability. Approved lamps use a small procedural streetscape surround generated by `CentralCityUrbanPlan.gd`: a light micro-paver pad with district accent, plus a green canteiro inset for selected Plaza/Market placements. That surround is ground treatment, not another lamp base. No dark socket, collar, pedestal or mounting square is generated under the sprite. The lamp anchor targets the visual center of the authored pedestal (y=104 inside the 48×112 asset) rather than the PNG bottom, lowering the sprite seven pixels so the original graphite base visually enters the surrounding floor/canteiro. Placement validation still uses a larger clearance footprint around the complete prop, preventing overlap with foundations, entrances and tree islands. Runtime movement collision remains separate and uses an eight-point isometric footprint fitted to the visible pedestal, so actor clearance blocks visual overlap without producing a wide invisible box. Important districts use exact section-authored compositions; service buildings currently allow at most one safe outer-sidewalk lamp, Central Plaza keeps lamps away from the City Guide/pool, and unfinished gates/residential/garden blocks remain unlit until their curb geometry exists. Approved benches are currently limited to the Central Plaza landscape edges and canal landscape nodes, where each orientation follows the local isometric street edge. Their movement blocker is a fitted oriented footprint rather than a rectangular box. Stable asset IDs allow later approved art to be added or replaced without rewriting district placement code.

Static world collision is represented by the authored walkability grid instead of duplicating every blocked cell into PhysicsServer shapes. Player clearance samples preserve collision margins; dynamic bodies and doorway Area2D triggers remain engine-native physics objects.

### Dynamic exterior lighting

Central City owns one `WorldLightingSystem` beside the area runtime rather than embedding ad-hoc light nodes in individual sections. A `CanvasModulate` plus one global `DirectionalLight2D` now follow a deterministic preview hour. The time profile drives ambient tint, sun color/energy, sun direction, projected-shadow length/opacity and local-light strength from dawn through morning, midday, afternoon, sunset and night. The preview clock does not advance on its own and is not persisted; the Developer Toolkit's **LIGHTING** tab can set the exact quarter-hour or jump to authored presets. This is intentionally the same API a future gameplay clock can call instead of introducing a second lighting implementation.

The runtime deliberately separates shadow profiles: player/NPC/Digimon actors use fitted soft contact ellipses at their feet, tall props and buildings use directional projected casts derived from ground footprints, trees use a broad soft canopy cast whose direction and stretch follow the preview sun, and raised landscape islands cast only a short structural edge shadow. Shadows render above raised landscape tops but below world actors/buildings, so tree canopies remain visible across both grass islands and surrounding pavement without authored shadow PNGs. Static casters rebuild only when the preview time changes, while moving actor contact shadows update from their runtime anchors.

Street-prop lighting remains data-driven in `central_city_decor.json`. Approved lamps declare light offset, color, base energy, radius and logical shadow height; their `PointLight2D` energy is almost dormant at midday, ramps through sunset and reaches full output at night. DigiLab, Training Center and Hospital also expose lightweight authored door/accent light sources through the same runtime group, so their existing luminous architecture participates in the same day/night grade without separate shaders or baked glow sprites. All local lights share one generated radial texture, keep native per-light shadow maps disabled for this Web/mobile-safe pass, and are distance-culled around the player. Entering a service interior disables the complete exterior lighting layer until the player returns to the city.

`WorldPerformanceMonitor` reports registered shadow casters, total local lights and currently active local lights alongside the existing FPS/draw-call counters so lighting cost remains visible during Web and device testing.

Tree canopy sway is shader-driven. Leaf particles are only emitted in the player's nearby section neighborhood, managed by one area-level cadence rather than per-tree GDScript processing.

World interaction candidates use a registry updated by SceneTree add/remove events and player movement instead of scanning the `world_interactable` group every frame.

Area-title banners are reserved for major authored locations and explicit story events. Crossing an internal authoring section never displays a banner or forces an immediate save.
