# Orbital

**Pitch:** Grow a lone habitat above Earth into a thriving orbital colony, one salvaged fragment and carefully placed module at a time.

**Core loop (30s):** Click drifting debris for Materials, select a module, preview a connected grid cell, build, and add solar capacity to support further expansion.

**Core mechanics:** Salvage drifting debris; build a connected station; balance resources to reach colony milestones; dispatch ships to mine asteroids and refine their Minerals.

**Art direction:** Clean sci-fi diagrams above blue Earth. Dark navy space, readable pale module silhouettes, cyan power and amber salvage.

**Scope:** Top-down 2D HTML5 MVP in Summer Engine. Mouse-first, touch-equivalent input. Five data-driven modules: Habitat, Solar Panel, Storage, Mining Ship and Refinery.

**Economy:** Start with one Habitat and 40 Materials. Habitat costs 30 and consumes 2 Power. Solar costs 20, produces 6 and consumes 1 Power. Storage costs 25, consumes 1 Power and adds 75 material capacity. The founding habitat includes a permanent 3-Power emergency supply. Material capacity starts at 100. Power is a capacity balance, recalculated each second and immediately after building. Reject placements whose projected balance is negative, but solar can bootstrap expansion. Debris yields 8–14 Materials; excess stays available until the fragment leaves the screen.

**Placement:** One module per square. New modules must share an edge with the station. Show the footprint and explain occupied, disconnected, unaffordable, out-of-grid or underpowered placements. Invalid actions spend nothing. Keep the tool active for repeat builds and provide a mouse-accessible cancel button.

**Win condition:** Levels 1, 2 and 3 at 1, 5 and 9 modules. Nine modules establishes the colony, shows a celebration, and allows continued building. Further levels every four modules.

**Architecture:** JSON module definitions with optional mining/conversion capabilities; station/resource model with signals and transactional placement; one-second resource tick; separate MiningFleet job reservations and AsteroidField presentation; separate debris, board drawing and catalog-driven HUD. Future modules can use these capabilities without changing placement or menu code.

**One thing this is NOT:** A survival combat game.

**Inspirations:** Space station schematics, Mini Metro's legibility, the incremental growth of city builders.

**Parked for later:** Full deep-space exploration, alien trade, events, research, combat, multiplayer, save/load.

**Local target constraint:** Installed Summer 4.7.2 Mono has no export templates. Build and verify the Summer MVP now; browser export requires a compatible non-Mono Summer environment and matching Web templates.

**Phase 1 — Mining:** Click a large violet asteroid to dispatch an idle Mining Ship (45 Materials, 2 Power). After eight resource ticks the ship delivers up to 18 Minerals and becomes available again. Asteroids arrive every 12 seconds, with at most three in the sector; claimed asteroids are held until extraction finishes. A Refinery (40 Materials, 3 Power) converts 2 Minerals into 6 Materials every three ticks. Each refinery pauses without losing resources when Materials storage lacks room for a full batch. Minerals are uncapped. Original module prices, power rules, salvage and colony milestones are unchanged.

**Phase 2 — Ships and upgrades:** Independent Miner (45 Materials / 2 Power) and Scout (35 Materials / 1 Power) ships live in a separate Ships catalog and menu tab. They do not occupy grid cells or count toward colony levels. An assigned Miner automatically repeats eight-tick, 18-Mineral cycles until its asteroid is depleted. A Scout surveys an adjacent sector placeholder in five ticks and reveals a 54-Mineral deposit. The Phase 1 grid-based Mining Ship remains available as a one-shot mining dock.

Habitat, Solar Panel, Storage and Refinery support one upgrade from T1 to T2. Inspect a module to see its tier, current stats, improvement and Materials/Minerals price. Habitat adds 25 material capacity (20 M / 6 Minerals); Solar generation rises 6 → 10 (30 M / 8 Minerals); Storage bonus rises 75 → 150 (25 M / 6 Minerals); Refinery cycle falls 3s → 2s (35 M / 10 Minerals). Power consumption is unchanged. Ordered upgrade data supports future tiers without changing the calculations. The existing Earth renderer and 2D scene are preserved.

## Positioning contract

Module centers are continuous Vector2 world coordinates, never locked grid indices. The visible grid is a board/input snapping helper; world geometry handles placement and the board handles projection. Default snapping, 2D visuals, and Earth stay unchanged. See `docs/positioning.md`.

## Phase 3: nearby exploration

A sector map lists reachable destinations from Home orbit. Owned Scouts reveal a selected sector after a travel timer: persistent mineable asteroid deposits, anomaly records (placeholder only), or empty space. Miners can be assigned directly from the discovery report. Sector routes, times and contents are data-driven. Existing colony systems, continuous Vector2 coordinates, 2D rendering and Earth remain intact.

## Recovery and resource supply contract

Placed modules and owned ships can be decommissioned for partial Materials refunds, freeing power and positions. The initial habitat is protected; no connectivity restriction may trap recovery. Removed busy units release missions without rewards. Resource supply is simulation-owned and presentation-independent: a RefCounted model controls spawning, lifecycle and salvage amounts in sector coordinates; Node2D fields are views/input adapters only. Earth/orbit art remains unchanged.
