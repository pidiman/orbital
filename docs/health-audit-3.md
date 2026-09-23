# Orbital health audit 3

Date: 2026-09-23  
Scope: read-only static audit of the current runtime, data, persistence, and automated checks.

No gameplay code or data was changed for this audit. The repository already had unrelated working-tree edits in `scripts/camera_input.gd`, `scripts/hud.gd`, and `scripts/ship_tile.gd`; they were left untouched.

## Performance first

This audit did not alter the project or run a controlled renderer benchmark, so it does not claim an FPS or frame-time number. The rankings below come from the actual per-frame loops and allocation patterns in the project. A capture with a normal and a large colony is still needed to separate CPU, draw-call, and GPU cost.

| Priority | System | Evidence | Likely impact |
|---|---|---|---|
| **High** | Ship presentation loop | `scripts/ship_motion.gd:54` calls `advance_visual()` every frame. It copies `model.ships` and `fleet.jobs`, creates a ship-unit array and an `alive` dictionary, walks every ship and Home mining structure, updates missions, rotations, exhaust state, and cleans several dictionaries. | Fleet size directly increases CPU work and temporary allocations. This is the strongest general stutter candidate once a save has many ships. It is view-only, but it is not cheap. |
| **High** | Asteroid defense simulation and rendering | `scripts/threat_field.gd:63` moves threats, scans each active turret and silo for its closest threat, advances every laser/missile, updates bursts, filters the burst array, and redraws every frame. `_draw()` renders threats, projectiles, missiles, bursts, and defense modules. | Threats are capped at 8, but projectile and missile arrays have no explicit active-count cap. Many turrets/silos can create many in-flight dictionaries and draw elements while targets remain alive. The closest-target work is bounded by active threats but scales with defense-module count. |
| **High** | Station draw path | `scripts/station_board.gd:_draw()` does a nested pair scan over all module positions to draw tube-to-tube links: O(M²) work on every redraw. It then draws each module, damage/connectivity indicators, HP, and tier labels. | Large stations or frequent redraws turn the previous tiling fix into a separate draw-time hotspot. The mask calculation itself is cached; this pair loop is the remaining expensive tube path. |
| **Medium/High** | Always-redrawn world views | `scripts/region_view.gd:_process()` queues a redraw every frame while a non-Home region is visible; its draw builds 150 star circles, planet glow bands, anomalies, labels, and outpost content. `scripts/asteroid_field.gd`, `scripts/debris_field.gd`, `scripts/material_ship_view.gd`, `scripts/ship_interaction.gd`, and `scripts/station_board.gd` also queue redraws continuously or whenever transient UI state is present. | Repainting static region content and multiple full overlays every frame can add CPU/GPU pressure even when nothing changes. The region view is the clearest unnecessary redraw. |
| **Medium** | Model/UI signal fan-out | `ResourceClock` advances the simulation every frame and emits model changes on ticks. HUD, trade, region, docking, gate, research, collection, cargo, repair, and save listeners subscribe to those changes and may refresh controls or request autosaves. | A large model can cause many UI refreshes after each simulation tick. This is event-driven at the signal level, but the fan-out can amplify each tick. |
| **Medium** | Scoped outpost adapters | `StationModel.scoped_station()` caches adapters by station ID, which is good, but adapter creation calls `recalculate()` and connects forwarding signals. Callers such as repair, cargo, trade, hauling, collection, and gate transport request scopes repeatedly. | The cache prevents an unbounded adapter leak for stable IDs, but first-use recalculation and signal wiring are expensive. Any future path that changes station IDs or bypasses the cache would regress into repeated model construction. |
| **Low/expected** | Audio synthesis | `scripts/ambient_music.gd:_process()` fills an `AudioStreamGenerator` buffer and evaluates trigonometric layers for every available audio frame. | Required while music is enabled; bounded by the 0.2-second audio buffer and normally less significant than the rendering/simulation loops. |
| **Low/expected** | Input and backdrop | `camera_input.gd` polls pan/zoom input; `space_backdrop.gd` refreshes its inverse transform each frame; `main.gd` advances persistence. | Small relative to the systems above. |

There are no `_physics_process()` implementations in `scripts/`; time-based work is split between the `ResourceClock` simulation tick and Node `_process()` loops. `scripts/resource_clock.gd` is expected to run every frame because it advances one-second simulation ticks. Floating-resource spawning is not an every-frame spawner: supply state advances from the clock and uses seeded spawn timing. The current code does not show a per-frame `Node.new()`/scene-instantiation loop; the allocations are mostly arrays, dictionaries, packed polygons, and redraw command data.

The active asteroid count is explicitly capped by `data/threats.json` (`max_active: 8`). Threats spawn at 30–60 seconds with an 18% 2–3 asteroid wave. Projectiles and missiles do not have a matching explicit cap, so a large number of defenses can create a transient projectile backlog. They are removed when a target disappears or their guaranteed-hit travel timer elapses, but a hard ceiling would make the worst case predictable.

The old tube/connectivity bug is not currently an every-frame BFS/mask recalculation: `StationModel._refresh_connectivity()` exits when `connectivity_dirty` is false, and `StationBoard` rebuilds connector masks only after module build/remove callbacks. The tube issue that remains is the O(M²) connector draw loop described above. No runtime sector simulation was found; sector names remain only at compatibility/migration boundaries and in stale tests/docs.

## Separation of concerns

| System | Current placement | Assessment |
|---|---|---|
| Module HP, damage, active state, repair rules | `scripts/station_model.gd` plus `data/module_durability.json` | Good model boundary. HP is authoritative in `RefCounted` station state; connectivity and HP determine whether a module functions. Partial HP remains active and zero HP is inactive. |
| Repair Ship | `scripts/repair_ship.gd` | Good `RefCounted` model. It scans only the ship's physical region, claims targets to avoid duplicate repairs, consumes local Materials, and advances from the clock. The repair beam is presentation code. |
| Cargo Ship | `scripts/cargo_shuttle.gd` | Good `RefCounted` route state. Source/destination, cargo, loading, unloading, gate jumps, storage waits, and Xenocrystal failures are persisted extension state. |
| Connectivity | `StationModel._refresh_connectivity()` | Good derived model state. BFS starts at the station/outpost core and is dirty only after graph changes; it is not saved as authoritative state. |
| Ship rotation, flames, trajectory and mining/repair beams | `ship_motion.gd`, `asteroid_field.gd`, `material_ship_view.gd`, `station_board.gd` | Correctly presentation-side and based on continuous `Vector2` positions. These views are nevertheless redrawn/polled more often than necessary. |
| Turrets, silos, asteroid movement, projectiles, impact selection, and loot trigger | `scripts/threat_field.gd` | **Architecture leak.** This is a `Node2D` that owns simulation dictionaries, timers, RNG, targeting, damage calls, and loot-side effects while reaching directly into `game.board` and `game.hud`. It is not a presentation-independent `RefCounted` model and cannot simulate an off-screen region cleanly. This is both the main separation-of-concerns risk and a likely performance/testability risk. |
| Connector auto-tiling | `StationBoard`/`ModuleArt` | Presentation-only and derived from the grid. The neighbor mask is event-driven and tube-only; module neighbors only produce ports. The visual variant mapping is hard-coded in `connector_variant()` rather than data-driven. |

## Data-driven definitions

- **Defense Turret:** `data/modules.json`; T1 range 220, one shot per second, projectile speed 330, 2 Power, 60 Materials. T2–T4 ranges 285/350/430 and fire intervals 0.8/0.6/0.45 seconds. Unchanged stats are merged from the base definition safely.
- **Missile Silo:** `data/modules.json`; T1 range 260, 4-second reload, speed 150, damage 4, 4 Power, 110 Materials. T2–T4 damage 5/6/7, reload 3.5/3.0/2.5 seconds, ranges 300/345/395.
- **Asteroid sizes and spawning:** `data/threats.json`; small health 2–3, speed 48–72, impact damage 2, loot 5–9; medium health 5–7, speed 36–58, damage 5, loot 10–18; large health 10–15, speed 25–44, damage 9, loot 18–30. Spawn interval, wave chance/size, active cap, edge margin, and impact radius are data-driven.
- **HP and repair:** `data/module_durability.json`; default max HP 12, +4 per tier, with module overrides (Habitat 24, Teleport Gate 20, Silo 18, Turret/Refinery/Research Lab 16, Depot/Dock/Storage 14, Solar 12, Tube 8). Repair defaults are 3 Materials per HP and 0.8 seconds per HP.
- **Cargo Ship:** `data/ships.json`; 120 Materials, 4 Power, 50-unit capacity, 2-second load wait, and a data-driven resource order covering Materials, Minerals, Tech, and Xenocrystals.
- **Repair Ship:** `data/ships.json`; 75 Materials, 2 Power, 2-second travel, 0.8 seconds per HP, 3 Materials per HP, and a configurable stop offset.
- **Space Dock and Connector Tube:** `data/modules.json`; dock tiers provide 1–4 universal slots; tube is T1–T4 with Materials-only visual reinforcement costs and no functional output.
- **Tube variants:** topology is deterministic, but `connector_variant(mask)` is code-defined in `station_board.gd`, not a data table. This is a modest data-driven gap if art variants or new connector families are added later.

## Cross-system integration

The intended defense loop is coherent: `ThreatField` selects the closest active defense module, applies guaranteed target damage when the visual projectile arrives, and on an undestroyed asteroid impact calls `StationModel.damage_module()`. HP remains functional above zero; at zero connectivity/HP makes the module inactive. `RepairShip` then finds sub-max HP modules in the same region, claims one, consumes local Materials over time, and restores HP. This avoids duplicate repair assignments and reuses the same active/inactive model rule.

The main caveat is ownership of the simulation: impact targeting uses `game.board` and returns immediately when the current board is not visible. In practice, damage and repair are evaluated for the currently viewed station/outpost, not as a persistent per-region threat simulation. An outpost can be damaged and repaired while it is the active viewed region, and its scoped connectivity/HP works; off-screen regions do not have an independent threat field. That will become a correctness problem when outposts defend themselves simultaneously.

Cargo routes use the location model and local station storage. Assignment requires discovered, gated source and destination regions; loading, unloading, storage-full waits, and per-jump Xenocrystal failures are represented in the route state. This is a clean integration for the current two-gated-region rule. A future region-local defense model should follow the same explicit station/region identity rather than extending `ThreatField`'s current board coupling.

## Save/load integrity

- Module position, kind, tier, stable structure identity, station ownership, and HP are serialized through the v2 station/world-location extensions. Turrets and silos therefore persist as ordinary modules; their transient target, cooldown, projectile, and asteroid dictionaries intentionally do not persist.
- Repair jobs are in `extensions.repair_ship`; Cargo Ship routes and cargo are in `extensions.cargo_shuttle`.
- Connectivity is derived from the saved graph. The save writes a connectivity schema marker, but does not treat the BFS result as authoritative; load marks connectivity dirty and recomputes it.
- Named saves are separate files under the save library directory (`user://saves/<sha256(slot-name)>.json`) with `slots.cfg` metadata; the legacy `user://orbital-save.json` remains a Load-list fallback.
- Legacy loading now runs migration before derived-state checks, reconciles retired docks, recomputes station projections, and logs canonical generated/used power plus ship ownership. Current saves retain strict validation.

The previous repeated migration regressions are substantially addressed, but the strict path remains a risk surface: every new extension needs defaults, validation, restore ordering, and a round-trip test. The defense field is transient by design, so reload intentionally starts a fresh threat schedule. HP autosave is signal-wired through `module_hp_changed`; upgrades restore HP to the new tier's maximum before serialization.

## Highest-priority technical debt

1. Move asteroid/threat/turret/silo simulation into a per-region `RefCounted` model. Keep `ThreatField` as a renderer/projectile presentation adapter. This removes the board-visible coupling and makes outpost defense, deterministic testing, and off-screen damage possible.
2. Replace the station-board O(M²) tube link scan with cached neighbor edges or a cell-index lookup. Keep the existing dirty mask invalidation.
3. Cache/reuse per-frame ship arrays and dictionaries in `ShipMotion`; update only changed jobs/ships where possible.
4. Add a hard active projectile/missile limit or pooled records. The asteroid cap alone does not bound the number of in-flight shots.
5. Make static region/debris/asteroid layers redraw on revision/camera changes instead of every frame; keep only animated overlays on a continuous loop.
6. Preserve one scoped station adapter per stable station ID and make that cache lifetime explicit as outposts expand. Avoid introducing paths that construct adapters inside high-frequency loops.
7. Replace hard-coded connector visual variant mapping with data if artists or future tube families need to tune it.
8. Remove or update stale sector-era tests and fixtures. They are not runtime leaks, but they obscure current coverage and have assumptions about removed sector APIs and the retired Mining Ship path.

## Automated test coverage

There is useful model coverage for regional operations, collection, docking, connector adjacency, hauling, trade, and location migration. `tests/connector_adjacency_playthrough.gd` checks starter tubes, tube costs, adjacency, and outpost placement; `tests/hauler_playthrough.gd` checks refinery hauling/buffers; `tests/location_checks.gd` and `tests/regional_operations_playthrough.gd` cover location-aware collection and local operations.

Coverage gaps are material:

- No focused automated scenario was found for `ThreatField` turret targeting, silo targeting, projectile/missile guaranteed hits, active-threat caps, or asteroid loot/drop behavior.
- No focused HP progression test covers small/medium/large impact damage, zero-HP inactive transition, partial-HP Repair Ship healing, or the defense-to-repair loop.
- No focused Cargo Ship route playthrough was found; the existing hauling tests are for refinery Haulers, not the regional Cargo Ship shuttle.
- Tube auto-tiling is logged and exercised indirectly by connector tests, but there is no visual assertion that mask 3 is drawn as a straight corridor rather than a cross. The O(M²) draw path is likewise unprofiled.
- Connectivity has model-level adjacency coverage, but no end-to-end test verifies that every module class stops consuming/producing when disconnected and reactivates after reconnection, including outpost cores.
- Save tests cover extension round trips and legacy migration in several areas, but there is no single current-save strict-validation fixture combining HP, turrets/silos, Cargo routes, outposts, docks, and connectivity-derived recomputation.
- Several older tests still reference removed sectors or old APIs. They should be retired or rewritten so the suite describes the regions-only game.

The practical next measurement is a repeatable 60-second capture at three states: a fresh Home view, a large station with many ships, and a defense-heavy station with eight active threats and several silos. Record frame time, script time, draw calls, object count, and temporary allocation pressure; then verify whether the ranked static hotspots match the profiler.
