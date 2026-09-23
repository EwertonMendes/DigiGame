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

All 25 sections are present before `[World] READY`. Area construction is staged one authored section per frame behind an opaque in-game loading screen, so slow mobile devices can present their first Godot frame immediately instead of leaving the browser download bar stuck at 100%. The exterior remains hidden and non-interactive until all sections are ready.

Walking across section boundaries only changes district/title metadata; it never mutates the scene tree. This prevents mobile traversal from paying terrain construction/destruction costs and removes visible terrain pop-in.

Central City uses the authored `MCBlocksColorOutline.png` atlas for urban surfaces, architecture and interior props. Roads, sidewalks and plazas are neutral/dark city materials; green is reserved for deliberate park plots. Establishment facades use neutral masonry with service-specific trim, windows and one exterior sign.

## Adding a major area

Add a dedicated area scene and its data file, register the data in `WorldAreaCatalog`, and load that scene only at a major-region boundary. Do not introduce proximity streaming inside the area. Large-area loading is expected to happen once at the transition; exploration afterwards must be stable.

## Developer Hub

The old prototype Hub is not the normal application entry point. Development builds expose a **TEST HUB** action in the Developer Toolkit. Automated Web QA can use `?debug=1&test_hub=1`; the route is rejected when developer tools are unavailable.
