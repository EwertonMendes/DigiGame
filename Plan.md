# DigiGame — Game Design Plan

## 1. Product vision

DigiGame is a single-player isometric tactical RPG built around a small team of Digimon, meaningful long-term roster progression, branching digivolution and degeneration, and deliberate grid-based combat.

The target experience is a focused game with a real beginning, middle, and ending rather than an endless sandbox. A practical initial target is roughly 8–12 hours for a first complete campaign, with replay value coming from different owned Digimon, evolution routes, team compositions, optional missions, and a possible New Game+ mode.

The player should spend meaningful time both preparing a team outside combat and making tactical decisions inside combat. Preparation and battle are intentionally separate layers: the DigiLab handles digivolution decisions, while combat is about positioning, abilities, resource use, terrain, enemy behavior, and coordination.

## 2. Core pillars

### Tactical clarity

Battles should be readable and relatively fast. The player controls up to three owned Digimon on an isometric grid against one or more enemies. Position must matter enough that the grid is mechanically justified.

### Meaningful Digimon progression

Leveling is not a straight ladder. Digivolution and degeneration create branching progression, allow experimentation, and repeatedly restart the leveling journey with a stronger or strategically different Digimon.

### Team synergy

A strong team is more than three individually powerful units. The Link system, complementary attack patterns, status effects, movement tools, and terrain interactions should reward coordinated play.

### A world that visibly recovers

The hub starts limited and becomes increasingly useful as the campaign progresses. NPC Digimon arrive, services unlock, and the player can see the results of story progress.

### A complete campaign

The game has an authored story, escalating regions, memorable encounters, a final dungeon, a multi-phase final boss, an ending sequence, and credits.

## 3. Core gameplay loop

1. Return to the hub.
2. Manage the owned roster, party, equipment/items, and progression.
3. Use the DigiLab for digivolution or degeneration when requirements are met.
4. Select a story mission or optional mission.
5. Experience short exploration, dialogue, events, or choices where appropriate.
6. Enter a tactical battle.
7. Earn experience, items/materials, Digi Data, and other progression rewards.
8. Unlock new services, missions, Digimon possibilities, abilities, or story progress.
9. Return to the hub and prepare for the next mission.

The loop should avoid becoming a chain of contextless battles. Missions and hub progression give combat a purpose.

## 4. Tactical combat

### Team size

The player deploys up to three owned Digimon. Enemy groups may vary from a single boss to multiple coordinated enemies.

### Turn structure

The preferred baseline is an initiative-based turn order influenced by Speed. On a Digimon's turn, the player should normally be able to move and perform one main action. The system should support both move-then-act and act-then-move unless a specific action explicitly ends movement.

Exact action economy is still subject to playtesting, but the interface should remain easy to understand.

### Core stats

A practical starting stat set is:

- HP: health.
- SP: ability resource.
- ATK: physical damage contribution.
- INT: special/technique damage and related effects.
- DEF: physical/general durability depending on final formula.
- SPD: turn-order contribution and potentially other speed-related rules.
- MOV: maximum tactical movement range in tiles.

The final formulas should be documented once combat balancing begins.

### Positioning and targeting

Position must meaningfully affect decisions. Abilities can use patterns such as:

- Single target.
- Adjacent/melee.
- Line.
- Cone.
- Cross.
- Circular or diamond area.
- Ground-targeted area.
- Self-centered area.

The system should support push, pull, displacement, zones, hazards, and other tactical effects later without requiring a rewrite of core targeting.

### Terrain

Terrain can affect combat through properties such as:

- Defensive bonuses or penalties.
- Movement cost.
- Hazard damage.
- Elemental or species advantages.
- Blocking or non-blocking obstacles.
- Height/elevation if the feature proves worthwhile.
- Special traversal, such as flying units ignoring selected restrictions.

Terrain effects should remain visible and understandable rather than becoming hidden modifiers.

### Incapacitation

There is no permanent death. A Digimon reduced to 0 HP is incapacitated for that battle. Optional light post-battle consequences such as fatigue can be explored later, but they should not make experimentation punishing.

## 5. Link system

Link is a signature team-synergy mechanic.

Allied Digimon build or trigger Link opportunities by fighting near one another, setting up attacks, exploiting status effects, or combining compatible actions. Examples include:

- One ally displaces an enemy into another ally's threat area.
- An ally attacks a target already marked or exposed by another ally.
- Two allies occupy tactically supportive positions and unlock a coordinated follow-up.
- A setup move enables a stronger combined attack.

Link should reward planning and team composition without turning every action into an automatic combo.

Important: Link is not used for digivolution during combat. Digivolution never occurs in battle.

## 6. Digivolution and degeneration

The progression philosophy is inspired by the branching evolution structure of Nintendo DS Digimon Story titles such as Digimon Story Dusk.

### Branching paths

A Digimon species can have multiple valid digivolutions. A form may also be reachable from more than one earlier form. The system should be represented as a graph rather than as a single hard-coded evolution chain.

Illustrative example only:

Agumon may eventually qualify for multiple Champion-level forms depending on requirements. Those forms may later lead to different Ultimate and Mega options. The exact species graph will be authored as game content.

### Degeneration

The player may intentionally degenerate a Digimon to a valid previous form. Degeneration is part of normal progression and experimentation, not a punishment.

### Level reset

Every successful digivolution resets that Digimon to level 1.

Every successful degeneration also resets that Digimon to level 1.

This is a core rule. Re-leveling after changing form creates a repeated progression loop and makes choosing when to evolve or degenerate strategically meaningful.

### Requirements

Level is the standard requirement for a digivolution. A route may also require one or more additional conditions, for example:

- A specific item.
- A minimum ATK, INT, DEF, SPD, HP, or other tracked attribute.
- A number of battles or victories.
- Use of a particular ability category.
- Story progression.
- A species-specific condition.

Requirements should be visible to the player once the relevant route has been discovered, so progression feels goal-driven rather than arbitrary.

### DigiLab only

Digivolution and degeneration happen only in the DigiLab outside combat.

There is no mid-battle digivolution system. The player decides forms and team composition before entering a fight, then focuses entirely on tactics during the battle.

## 7. Obtaining new owned Digimon — Digi Data

New owned Digimon are primarily created from species-specific Digi Data.

### Earning data

When the player defeats an enemy Digimon, the player gains a percentage of Digi Data for that species.

The data amount depends on the defeated Digimon's rank/stage. Basic forms should provide a relatively large percentage per defeat; higher ranks require more defeats. Mega-level Digimon should provide the smallest percentage per defeat.

Exact percentages are a balancing variable and should live in data/configuration rather than scattered combat code.

### Conversion

When a species reaches 100% Digi Data, the player may convert that accumulated data into a new owned Digimon of that species through the appropriate out-of-combat system.

The conversion should feel like reconstruction from collected digital information rather than creature capture.

Whether data is consumed back to 0%, reduced by 100%, or supports overflow beyond 100% is an open balancing decision. The architecture should not hard-code a choice until the collection system is designed.

### Why this matters

The system encourages the player to fight different species, makes repeated encounters useful, and naturally makes powerful high-rank Digimon more difficult to obtain.

## 8. Player-owned Digimon versus hub NPC Digimon

These are two separate concepts.

### Player-owned roster

Owned Digimon are the units the player levels, evolves, degenerates, customizes, stores, and deploys in tactical battles.

### Hub NPC Digimon

Hub Digimon are world characters. They provide services, dialogue, story progression, shops, training, research, DigiLab functions, mission support, or other utilities.

A Digimon appearing as an NPC in the hub does not mean that specific NPC is part of the player's roster. The player may separately own a Digimon of the same species through Digi Data or other explicitly designed acquisition methods.

## 9. Hub and long-term progression

The hub is the campaign's persistent home base.

It begins small and gains functionality as the player advances. Potential services include:

- DigiLab for digivolution and degeneration.
- Digi Data conversion/reconstruction.
- Roster storage and party management.
- Item and equipment shop.
- Training or stat-related systems.
- Mission board or mission selection.
- Research/archive/Digimon encyclopedia.
- Optional arena or challenge content.

New NPC Digimon can arrive through story events or side objectives. The visual growth of the hub should reinforce progress.

## 10. Progression layers

The game should provide several simultaneous forms of progression:

- Digimon levels and stats.
- New abilities or ability options.
- Branching digivolution and degeneration routes.
- New owned Digimon through Digi Data.
- New party combinations and Link synergies.
- Items/materials and possible equipment systems.
- Hub services and NPCs.
- Story regions and missions.

A mission should usually advance at least one meaningful layer so rewards do not feel like experience points with no visible consequence.

## 11. World structure and maps

### Story maps

Major story encounters should use authored tactical maps. Boss arenas, chokepoints, hazards, cover, routes, and mission objectives should be deliberately placed to support interesting decisions.

### Procedural content

Procedural generation is best suited to optional missions, repeatable encounters, or exploration variants. It should generate coherent regions rather than choosing an unrelated terrain tile independently for every grid cell.

Procedural maps should use biome/noise/region rules, adjacency rules, and authored encounter templates.

## 12. Regions and visual progression

A possible campaign sequence is:

- Green Sector: natural grassland/forest region and early-game learning space.
- Data Ruins: abandoned digital structures and corrupted infrastructure.
- Frozen Sector: ice, snow, constrained traversal, and cold hazards.
- Volcano Server: volcanic terrain, lava, environmental pressure.
- Dark Area: heavily corrupted digital region with unstable rules and atmosphere.
- Kernel: final high-security core region with abstract digital architecture.

Each region should introduce at least one new tactical/environmental idea and have a distinct visual identity.

## 13. Story premise

The Digital World is suffering from fragmentation. Entire sectors disconnect, reappear altered, or lose pieces of their data and memory. Digimon experience memory loss and unstable development as the world's systems struggle to remain coherent.

The player's group begins in an isolated region with an immediate goal of surviving and finding a way out. As the campaign expands, they discover that the fragmentation is not simply a natural failure.

The central antagonist is an intelligence or system responsible for preserving stability. It concludes that evolution, change, conflict, and unpredictability are the source of instability. Its solution is to prevent change by freezing, isolating, or normalizing the Digital World.

The thematic conflict is therefore not merely good Digimon versus an evil Digimon. It is absolute order and stasis versus growth, change, and evolution.

## 14. Campaign structure

### Chapter 1 — Lost Sector

Introduce the world, tactical fundamentals, the initial party, the hub, and Digi Data. The immediate problem is escaping or reconnecting an isolated sector. End with a smaller boss that demonstrates the basic tactical rules.

### Chapter 2 — Broken Network

The group reaches other communities and learns that fragmentation is widespread. Different Digimon communities have different beliefs about whether reconnection is safe or desirable. The hub expands and tactical complexity increases.

### Chapter 3 — Evolution

Evidence appears that evolution data and development paths are being manipulated. Artificially altered or unstable Digimon appear. The deeper purpose of the system causing fragmentation becomes clearer.

### Chapter 4 — Dark Area

The party enters a severely corrupted region and discovers the origin or operational center of the crisis. The true antagonist and its philosophy are fully revealed. High-level team building and evolved forms become essential.

### Chapter 5 — Kernel

The final push toward the Digital World's core. Maps become more deliberate and demanding, the player's strongest evolution paths are relevant, and previous mechanics are combined.

The final boss should use multiple phases, such as territory control, destructive map changes, and a final form that modifies familiar tactical rules without becoming unreadable.

## 15. Ending

After the final battle, the game should not cut directly to a generic completion screen.

The ending can show:

- The restored or changed sectors.
- Hub NPCs the player helped.
- The final state of the hub.
- Important story relationships or choices.
- The player's final active team.
- The consequences of the antagonist's defeat or resolution.

Then roll credits.

A New Game+ mode can later provide additional evolution routes, encounters, difficulty options, or Digimon while preserving a completed-game reward loop.

## 16. Initial content scope

Do not begin by targeting hundreds of playable species. A first complete version should prioritize meaningful differences and polish.

A reasonable planning target is roughly 20–30 owned/playable Digimon species or base roster entries, with a larger total number of forms created through branching evolution paths. The exact count should be driven by production capacity and animation/content cost.

The game should prefer a smaller roster with distinct tactical identities over a huge roster of nearly interchangeable units.

## 17. Visual direction

The game remains isometric.

The visual target is a readable tactical board that feels like a cohesive Digital World environment rather than a programmer-art test grid floating over a static image.

Priorities:

- Coherent terrain regions instead of tile-by-tile random noise.
- Clear tile boundaries and readable movement/targeting overlays.
- Environmental props and biome identity without obscuring units.
- Layered, animated Digital World backgrounds where maps exist in abstract space.
- Subtle particles, lighting, data effects, and motion.
- Strong battle UI readability.
- Correct responsive composition on Web and desktop at different display aspect ratios.

Story maps should eventually feel authored and inhabited. Procedural maps should still obey visual composition rules.

## 18. Platform and technical direction

- Godot 4.7.x.
- GDScript runtime.
- GL Compatibility renderer.
- Same gameplay implementation for Web and desktop.
- GitHub Actions is the remote build and validation environment.
- GitHub Pages is the zero-install playable test target.
- Every meaningful runtime change should retain a passing Web export and Chromium smoke test.
- Visual changes should produce screenshot artifacts for review.

## 19. Development roadmap

### Phase A — Foundation and vertical slice

- Preserve the existing playable prototype while modernizing presentation.
- Establish agent instructions, reproducible CI, asset provenance, and visual validation.
- Replace incoherent random terrain with coherent region generation.
- Improve responsive presentation and background motion.
- Define tactical data structures before building the full combat system.

### Phase B — Tactical combat prototype

- Turn order.
- Movement range/pathing.
- Action targeting.
- HP/SP and damage.
- Win/lose conditions.
- Basic enemy AI.
- Three-player-unit support.
- Initial Link prototype.

### Phase C — Progression prototype

- Owned roster state.
- Experience and leveling.
- Digivolution graph.
- DigiLab UI and requirements.
- Degeneration.
- Level-1 reset behavior.
- Digi Data accumulation and 100% conversion.

### Phase D — Hub and campaign framework

- Hub scene and NPC service architecture.
- Mission selection.
- Save data.
- Story dialogue/events.
- Story map loading and objectives.
- Region progression.

### Phase E — Content and polish

- Additional species/forms.
- Abilities and status effects.
- Authored maps and bosses.
- Biome art and effects.
- Sound/music.
- UI polish and accessibility.
- Balance passes.
- Ending and credits.

## 20. Open design questions

These are intentionally not finalized yet:

- Exact turn-order formula and whether turn frequency can vary by SPD.
- Exact damage formulas.
- Exact Digi Data percentages by rank.
- Whether Digi Data can exceed 100% and whether conversion consumes exactly 100%.
- Exact stat inheritance or long-term benefit created by repeated digivolution/degeneration cycles.
- Ability learning and inheritance rules across forms.
- Equipment depth.
- Status-effect list and duration rules.
- Height/elevation complexity.
- Optional fatigue system.
- Exact number of species/forms in the first complete release.
- New Game+ rules.

These should be solved through focused design and playtesting rather than silently assumed during implementation.
