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

### Permanent technique library

Each owned Digimon has an individual, permanent technique library. Basic Attack remains a universal command outside that library. A learned technique is never forgotten and remains usable after every digivolution and degeneration, regardless of whether the current form could have learned it originally.

Each form has exactly one signature technique at level 1 and normally one or two inherited techniques at later levels. A Digimon reconstructed directly in any rank begins with only Basic Attack and its current form's signature. Fresh forms learn one inherited technique at level 3, In-Training forms at level 5, Rookie forms at levels 8 and 16, Champion forms at levels 10 and 20, Ultimate forms at levels 12 and 24, and Mega/Ultra forms at levels 15 and 30. Entering a form immediately learns its signature without duplicating notifications or mastery progress.

Favorites are six ordered shortcuts, not equipment slots. The complete learned library remains available in battle. Players may archive techniques to hide them from the normal view without deleting knowledge or mastery. Combat must provide Favorites and All Techniques views plus role, element, affordability, target-pattern, name, recency, and SP-cost organization as the library grows.

Every technique has Learned (0–7), Experienced (8–23), and Mastered (24) mastery. Only effective uses count, with at most two points for one technique in a won battle. Each technique uses one mastery profile: Efficient reduces SP by 1/2, Swift reduces recovery by 5/10, Precise adds 5/10 accuracy, Reliable Effect adds 5/10 percentage points to effect chance, and Potent adds 5/10 percent damage or healing. Mastery never changes a technique's targets, range, area, element, or tactical identity.

Technique Records are permanent account unlocks used by the DigiLab tutor. Teaching costs 300/900/2,500/6,000 Bits for Common/Uncommon/Rare/Legendary Records. Signatures and DigiXros techniques cannot be taught. Compatibility is checked against the current form's elemental and execution tags only when teaching; once learned, the technique is permanently unrestricted. Common Records can also be researched by witnessing an enemy use the technique effectively and then winning. Each victory grants at most one insight per observed technique, and three insights unlock its Record.

The canonical catalogue covers all 2,260 named source rows inventoried from Digimon Story (201), Dawn/Dusk (513), Lost Evolution (546), and Super Xros Wars (1,000). Dawn/Dusk has 204 named normal techniques and 309 named special techniques; dynamic advertisement rows must never be counted as source techniques. Every source row must be audited as mapped, alias, requires-mechanic, or dummy-excluded. The 54 source-declared Super Xros Wars dummy entries remain in the audit but never enter runtime data. Runtime techniques are data-driven compositions of reusable damage, healing, status, movement, terrain, guard, counter, reflect, drain, revival, and Digi Data handlers; technique-specific scripts are not allowed. DigiXros itself is outside the current implementation and dependent techniques remain unavailable until that mechanic exists.

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

### Individual Tier ascension

Every reconstructed owned Digimon starts at Tier E. Tier belongs to the individual, persists through both Digivolution and Degeneration, and contributes to the final stats used by visible evolution requirements. It supplements level, species, form, techniques, terrain, Link and positioning rather than replacing them.

The final Tier multipliers are:

| Tier | HP / ATK / DEF / INT | SP / SPD |
| --- | ---: | ---: |
| E | 1.00 | 1.00 |
| D | 1.05 | 1.025 |
| C | 1.10 | 1.05 |
| B | 1.16 | 1.08 |
| A | 1.23 | 1.115 |
| S | 1.31 | 1.155 |
| SS | 1.40 | 1.20 |
| SSS | 1.50 | 1.25 |

MOV never receives a Tier multiplier. Reaching D/C/B/A/S/SS/SSS costs 300 / 1,500 / 5,000 / 15,000 / 50,000 / 125,000 / 300,000 Bits. D has no minimum form and needs no fusion. C requires Rookie or higher, B Champion or higher, A Ultimate or higher, and S/SS/SSS Mega or Ultra. C, B, A, S and SSS require a duplicate fusion; SS does not.

A fusion donor must be the exact current species, be in Storage, and have no equipment. Confirmation must identify the exact individual that will be consumed, and the complete transaction must validate before removing either Bits or the donor. The target retains its identity, nickname, favorite shortcuts, training, Potential and history. It assimilates the union of both permanent technique libraries; shared techniques retain the higher mastery instead of adding mastery, and donor-only techniques enter archived. No other donor state transfers.

### Individual Expansion

Tier S makes an individual eligible for permanent Expansion. Consuming one Expansion Core unlocks the individual; after unlocking, switching between 1×1 and 2×2 is free but only available in the DigiLab outside combat. Switching preserves current HP and SP proportions. All three active party members may be expanded simultaneously, and a unit never changes size during a mission.

While the 2×2 footprint is active, the Digimon gains 20% maximum HP and immunity to normal-class forced movement. Heavy forced movement continues to work; colossal is reserved for future footprints. Expansion gives no direct damage, defense, SP, SPD or MOV bonus. In the hub, an expanded follower uses 1.25× additional visual scale while retaining normal hub collision. In battle it uses 1.75× base visual scale, nearest-neighbor filtering and may later receive data-driven species adjustments.

The first Expansion Core is a guaranteed reward from a late story mission that introduces the system. Additional Cores are unlimited: an advanced repeatable mission guarantees one Expansion Fragment, and five fragments plus 50,000 Bits craft one Core. Inventory and encounter/quest item rewards must remain generic rather than hard-coded around Expansion items.

### Tactical footprints

Every battle actor has an explicit grid anchor and a data-defined set of occupied-cell offsets. Occupation is never inferred from the sprite. The initial supported footprints are 1×1 and 2×2, while the geometry foundation must accept future footprints such as 3×3 without rewriting combat.

- Movement remains cardinal. Every occupied cell must exist and pass static terrain validation. Each step costs the highest movement cost among cells newly entered during that step.
- Allies may be crossed during pathfinding, but a unit may never finish overlapping another unit. Enemy footprints block traversal. A 2×2 unit cannot use a one-cell corridor or temporarily shrink. Incapacitated units cease occupying cells.
- Terrain defense uses the least favorable modifier among occupied cells. A hazard activates once per unit when any occupied cell is affected. A future height system must require compatible support under every occupied cell.
- Clicking or touching any occupied cell selects the complete unit. Range and minimum range use the smallest distance between footprint edges. An area applies to an intersected unit at most once.
- Self areas and auras originate from the full body/perimeter. Lines and cones originate from the facing edge, so a 2×2 body creates a two-cell front. Line of sight succeeds when at least one unobstructed line exists between an attacker cell and a target cell.
- Link adjacency accepts any contact between allied footprints, with at most one opportunity per allied pair for each action.
- Pushes and pulls move the anchor one cell at a time, validate the complete footprint, and stop before units, obstacles or map limits.
- AI, keyboard/touch selection, cameras, VFX, previews and sprite depth must use occupied cells, footprint edges and visual centers rather than assuming one tile.
- Combat maintains a cell-to-actor index and refreshes it on spawn, movement and incapacitation for Web performance.

Encounter descriptors explicitly support Tier and footprint values; omitted values mean Tier E and 1×1. Enemy Tier is authored, never silently scaled, and appears in the battle HUD. Deployment is footprint-aware and must refuse battle start with a clear explanation when the selected team cannot fit.

Every main-story map must accommodate three allied 2×2 units and provide at least one two-cell-wide route from deployment to objectives. One-cell corridors may remain optional shortcuts for 1×1 units. Story-map validation must automatically check 2×2 connectivity. Boss-specific body parts, phases and footprints larger than 2×2 are intentionally outside this first delivery.

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
- Equipment depth.
- Height/elevation complexity.
- Optional fatigue system.
- Exact number of species/forms in the first complete release.
- New Game+ rules.

These should be solved through focused design and playtesting rather than silently assumed during implementation.
