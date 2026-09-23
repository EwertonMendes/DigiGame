# Seamless world runtime

The campaign overworld starts in `scenes/world/world_root.tscn`. The existing `hub.tscn` remains unchanged as a developer-only integration laboratory.

## Runtime contract

- `WorldRoot` owns the persistent player, camera, followers, HUD and service host.
- `AreaStreamer` keeps nearby authored chunks instantiated, queues adjacent chunks ahead of movement and unloads distant chunks with hysteresis.
- `WorldChunk` owns local terrain, collision, depth-sorted props, buildings, roof occlusion and interactables.
- `InteractionSystem` resolves world interactions centrally by explicit priority and distance instead of service-specific input chains.
- `WorldServiceHost` composes the existing DigiLab, Training, Hospital and Digimon screens without inheriting the legacy Hub gameplay chain.
- `WorldState` persists the logical area, current chunk, exact player position, facing and world-state dictionaries.
- Battle return is contextual: normal gameplay returns to the seamless world, while battles deliberately launched from the developer Hub return there.

## Central City

`assets/resources/world/central_city.json` is the first authored world area. Its 5×5 chunk grid contains Central Plaza, DigiLab, Hospital, Training, Data Market, Archive, canals, gardens, residences and city gates. All current visuals use assets already vendored by DigiGame.

Buildings are physically part of the overworld. Their interiors do not require a scene change: walking through the doorway fades the roof and reveals the interior. Service terminals reuse the same interaction contract that future houses, shops and quest interiors can use.

## Adding areas and chunks

New content should be data-first. Add chunk rows to an area definition or register a new area file in `WorldAreaCatalog`. Do not add a new monolithic area controller. Specialized chunk scenes may be introduced later as long as they implement the same `configure(definition, player, world_controller)` contract.

## Developer Hub

The old prototype Hub is not the normal application entry point. Development builds expose a **TEST HUB** action in the Developer Toolkit. Automated Web QA can use `?debug=1&test_hub=1`; the route is rejected when developer tools are unavailable.


## Central City art direction

Central City uses the authored `MCBlocksColorOutline.png` atlas for its urban surfaces, architecture and interior props. Roads, sidewalks and plazas are neutral/dark city materials; green is reserved for deliberate park plots. Establishment facades use neutral masonry with service-specific trim, windows and one exterior sign.

Service buildings do not reveal a tiny room underneath their roof. Their entrance transitions the persistent player/camera into a large dedicated interior stage in the same SceneTree. The transition uses camera zoom plus a digital color wash; there is no loading screen, black frame or scene replacement. Each service interior has its own functional zones and atlas furniture (lab machinery, recovery bays, training stations, market storage or archive stacks).
