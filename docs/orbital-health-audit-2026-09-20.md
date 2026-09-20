# Orbital health audit

Date: 2026-09-20

Orbital’s core transactions and phase integrations are sound by inspection, but separation is incomplete and growth can reach an irreversible power dead-end.

Scope: read-only source and test audit. No gameplay or code changes were made, and tests were not rerun. This file exports the report.

## Risks ranked by severity

| Severity | Finding | File/system |
|---|---|---|
| **High** | **Power soft-lock is possible.** Fill the default 81 positions with 27 Solar Panels and 54 Habitats: net power is 30. Buy 30 Scouts without acquiring a miner: power becomes zero, minerals remain zero. No space for solar/mining modules, no power for a Miner, no minerals for solar upgrades, and no demolition, decommissioning or shutdown mechanism. Salvage cannot resolve this progression lock. | `scripts/station_model.gd`, `scripts/station_geometry.gd` |
| **High** | **Resource availability depends on 2D presentation.** Debris spawning, movement, expiry and salvage amounts live in a `Node2D`; home asteroid spawning and removal depend on viewport coordinates in another `Node2D`. Replacing these views with 3D would remove gameplay supply unless that behavior is ported. | `scripts/debris_field.gd`, `scripts/asteroid_field.gd` |
| **Medium** | **Exploration routes are only superficially generic.** Reachability checks whether `reachable_from` contains `"home"`; revealing another sector never opens routes from it. Only asteroid discoveries receive gameplay behavior; anomalies are reports. Multi-hop exploration, aliens and trade require logic changes. | `scripts/mining_fleet.gd:92`, `scripts/sector_map.gd` |
| **Medium** | **Future power-loss events have no operational consequences.** Purchases prevent deficits, but mining, refining and surveying never check power while running. Damage or events that reduce generation would leave everything operating. | `scripts/station_model.gd`, `scripts/mining_fleet.gd` |
| **Medium** | **Ship capabilities cannot safely compose.** Mining checks `jobs`; surveying checks `survey_jobs`. A future ship with both capabilities can undertake both simultaneously through the model/map. The HUD also treats every non-mining ship as a Scout. | `scripts/mining_fleet.gd`, `scripts/hud.gd:319`, `scripts/sector_map.gd` |
| **Medium** | **Long-term economy lacks sinks.** Minerals are uncapped, home ore and salvage replenish indefinitely, upgrades are finite, and four surveys exhaust exploration. Scouts continue reserving power afterward. No exponential resource exploit found, but stockpiling and permanently idle assets replace progression. | Economy, `data/*.json` |
| **Low** | **Extension debt:** public mutable dictionaries; unchecked JSON schemas; module positions double as identity; dock/ship jobs use mixed `Vector2`/integer keys; asteroid ID signs encode origin; refinery conditions are repeated in HUD; art uses hard-coded kinds. No persistence. | `scripts/station_model.gd`, `scripts/mining_fleet.gd`, `scripts/asteroid_field.gd`, `scripts/hud.gd`, `scripts/module_art.gd` |

## Separation and coordinates

- **Pass for the core:** `StationModel`, `MiningFleet` and `StationGeometry` extend `RefCounted` and have no dependency on `Node2D`, `Sprite2D` or other presentation nodes.
- **Pass for station positions:** canonical module centers are continuous `Vector2`; placement snapping is confined to `scripts/station_board.gd`. Fractional placement, upgrades and mining docks have automated checks.
- **Qualified overall:** asteroid positions and ship flight positions exist only in presentation. Core geometry also hard-codes 58-unit axis-aligned squares and ±232 bounds. A 3D view of the same planar simulation is feasible; true volumetric construction requires geometry changes.

## Definition inventory

| Source | Every current definition | Data-driven verdict |
|---|---|---|
| `data/modules.json` | Habitat, Solar Panel, Storage, Mining Ship dock, Refinery | **Yes for existing capabilities.** Prices, power, capacity, mining, conversion and upgrade tiers are data-driven. New artwork or behavior needs code. |
| `data/ships.json` | Miner, Scout | **Yes for single-capability variants.** Purchase and mining/survey parameters are generic; new roles and combined capabilities are not fully supported. |
| `data/sectors.json` | Home orbit; Dawn arc—54 ore, 5s; Twilight arc—54 ore, 7s; Echo pocket—anomaly, 6s; Quiet reach—empty, 4s | **Yes for additional home-adjacent sectors using existing contents.** Arbitrary route graphs and new discovery behavior are not data-only. |

Power is sustainable **while expansion space or solar upgrades remain available**: each T1 solar contributes **+5 net**, T2 **+9 net**. Modules, ships and upgrades all participate in the same budget. Unlimited salvage prevents ordinary material bankruptcy; full storage pauses refining without wasting ore. These protections do not prevent the full-station lock above.

## Cross-system integration

- **Phase 3 → Phase 1: passes by inspection.** Reveal creates persistent asteroids in the shared fleet registry; normal dispatch, extraction, mineral credit and depletion handle them. Rendering is not required for discovered deposits.
- **Phase 2 → Phase 3: passes by inspection.** Owned survey-capable ships drive timed exploration with busy-ship and duplicate-destination checks.
- The negative discovery IDs and projected home-screen markers are shortcuts, but **the actual resource integration is not a UI reward hack**. Remote mining currently ignores distance and travel.

## Automated coverage

| Covered | Missing or weak |
|---|---|
| Placement rejection/atomicity, power bootstrap, storage, colony levels — `tests/test_model.gd` | Full-station recovery, power exhaustion, long-run economic balance |
| Timed mining, reservations, parallel docks/refineries, exact conversion, full-storage pause — `tests/test_mining.gd` | Supply behavior independent of rendering, viewport-dependent economy |
| Ship purchases, repeat/partial mining, upgrade costs/effects, extra tiers/types, fractional positions — `tests/test_ships_upgrades.gd` | Power-increasing upgrade rejection, combined ship capabilities, malformed definitions |
| Scout timing/concurrency, discovery persistence, discovered-ore mining/depletion, anomaly/empty sectors — `tests/exploration_checks.gd` | Multi-hop routes, event-induced deficits, removal/cancellation, persistence |
| Mouse-driven salvage/build/mining/upgrade/exploration and projection checks — playthrough scripts | Automated architectural dependency enforcement |

Stored Phase 3 evidence reports **20/20 exploration** and **25/25 ships/positioning** checks passing with no recorded errors. Those are historical results, not a fresh verification of this audit.

Evidence files: `docs/phase3-exploration-results.json` and `docs/phase3-ships-results.json`.
