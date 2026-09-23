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

All 25 sections are present before `[World] READY`. The complete 4,900-cell ground is rendered through one global batched sheet mesh instead of thousands of per-tile `Node2D/Polygon2D` objects. Area construction yields after small batches of sections behind the opaque loading screen, keeping the first frame responsive without artificially stretching loading across 25 frames. The exterior remains hidden and non-interactive until all sections are ready.

Walking across section boundaries only changes district/title metadata; it never mutates the scene tree. This prevents mobile traversal from paying terrain construction/destruction costs and removes visible terrain pop-in.

For this visual test, Central City ground uses `assets/terrain/central_city_user_sheet/central_city_ground_atlas.png`, normalized from the project-owner supplied isometric sheet. Roads, crosswalks, sidewalks, plaza paving, grass, sand and canal water all come from that atlas. Architecture, roofs, service thresholds, interiors and props remain on `MCBlocksColorOutline.png`, so the ground experiment is isolated and can be discarded without touching gameplay systems.

## Adding a major area

Add a dedicated area scene and its data file, register the data in `WorldAreaCatalog`, and load that scene only at a major-region boundary. Do not introduce proximity streaming inside the area. Large-area loading is expected to happen once at the transition; exploration afterwards must be stable.

## Developer Hub

The old prototype Hub is not the normal application entry point. Development builds expose a **TEST HUB** action in the Developer Toolkit. Automated Web QA can use `?debug=1&test_hub=1`; the route is rejected when developer tools are unavailable.


## Performance contract

Central City treats authoring sections as data boundaries, never rendering boundaries. The 4,900 ground cells stay inside one global ground batch with no more than three ground-render nodes, and the area regression keeps the world runtime below its existing node budget.

Static world collision is represented by the authored walkability grid instead of duplicating every blocked cell into PhysicsServer shapes. Player clearance samples preserve collision margins; dynamic bodies and doorway Area2D triggers remain engine-native physics objects.

Tree canopy sway is shader-driven. Leaf particles are only emitted in the player's nearby section neighborhood, managed by one area-level cadence rather than per-tree GDScript processing.

World interaction candidates use a registry updated by SceneTree add/remove events and player movement instead of scanning the `world_interactable` group every frame.

Area-title banners are reserved for major authored locations and explicit story events. Crossing an internal authoring section never displays a banner or forces an immediate save.
