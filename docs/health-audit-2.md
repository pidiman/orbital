# Orbital health audit 2

Date: 2026-09-20. Scope: current on-disk source, definitions, test assertions and stored evidence. Read-only audit except for this requested report; no gameplay/code changes, engine launch, test execution or save writes. Findings are source-verified, not a fresh runtime certification. Compared with `docs/orbital-health-audit-2026-09-20.md`.

**Health:** substantially stronger model separation, recovery and persistence. No current colony-wide economic soft-lock or resource multiplication exploit found by inspection. The progression endpoint is nevertheless a dead-end: teleportation parks useful ships where they cannot work or return. Outposts need a coherent location/ownership model, not just more region content.

## Ranked risks

| Severity | Finding and consequence | Evidence |
|---|---|---|
| **HIGH — latent save availability** | Trade history grows forever. The writer accepts arbitrarily large snapshots, while the loader rejects files over 8 MiB. Enough legal completed/cancelled trades can therefore produce a successfully written checkpoint that cannot reload. Threshold has not been runtime-reproduced. | `scripts/trade_model.gd:129` `_record`; `scripts/save_store.gd:513` `save_game`, `:536` `load_game` |
| **MEDIUM — economic endpoint** | Gate arrivals cannot work, return, or travel onward. A jump consumes one Xenocrystal and strands the hull operationally; the hull continues consuming Home power. Decommissioning remains available for 50% Materials recovery, so this is an idle-asset trap, not an irreversible colony lock. Research currently unlocks only this endpoint. | `scripts/gate_transport.gd:30–76`; `scripts/station_model.gd:44`, `:258`; `data/technologies.json` |
| **MEDIUM — content/save compatibility** | Adding a region in JSON works for a new game, but existing region extensions must contain every installed catalog region. A missing new record rejects the whole save. Legacy sectors are restored as a saved array rather than merged with new sector definitions. Catalog expansion is not universally save-safe. | `scripts/region_model.gd:113` `validate`; `scripts/save_store.gd:224` `restore` |
| **MEDIUM — exhausted progression** | Tech has a lifetime sink of only 2 units. Minerals, Tech and Xenocrystals have no inventory caps. Trades remain available after research/standing utility is exhausted; standing caps at 100. Scouts and labs lose purpose after finite discoveries/research. Gate jumps provide a repeatable Xeno expense only by parking more ships. | `data/technologies.json`, `data/trade_offers.json`; research/trade/station models |
| **MEDIUM — outpost coupling** | Camera/current region, ship location, station ownership and mining destination are separate, inconsistent concepts. A Home miner can extract Pluto ore into Home storage without moving; a ship actually teleported to Venus cannot mine. Gates only support Home-neighbor departures. | `scripts/mining_fleet.gd` `dispatch`, `tick`, `region_survey_error`; `scripts/gate_transport.gd`; `scripts/region_navigation.gd` |
| **MEDIUM — power semantics** | Power constrains purchases/upgrades/demolition but does not govern ongoing refining, mining, surveys, trade, research, hauling or transit. Current legal actions prevent ordinary deficits; future damage/outpost power loss would not stop operations. | `scripts/station_model.gd` `_refine`; fleet, research, collection and transport update methods |
| **LOW — coordinate coupling** | Collection embeds a station-to-sector conversion using `Vector2(900, 605)`. Region generation uses fixed layout-like coordinate bands; old discoveries use four repeating marker slots. These are node-free but not a unified physical coordinate system. | `scripts/material_collection.gd:31`; `scripts/region_model.gd:84`; `scripts/mining_fleet.gd` `discovery_position` |
| **LOW — bypassable boundaries** | Shared job occupancy is enforced through Fleet, but direct `diplomacy.dispatch()` only checks its own jobs. Public mutable dictionaries and direct inventory writes permit callers to bypass invariants. Catalog JSON is assumed valid. | `scripts/mining_fleet.gd:241`; `scripts/trade_model.gd:70`; `scripts/mining_fleet.gd:287`; all catalogs |

## 1. Separation of concerns and continuous positions

**Pass for dependency direction:** resources/modules/upgrades (`StationModel`), geometry, ships/mining/exploration (`MiningFleet`), supply, regions, trade, research, gates and material collection all extend `RefCounted`. None requires `Node2D`, `Sprite2D`, `CanvasLayer`, viewport geometry, input events or a scene node. `ResourceClock` is a generic `Node` adapter; `main.gd` is a `Node2D` composition root that constructs models/views and wires signals. These adapters do not own transaction rules.

**Pass for placement:** canonical module centers remain continuous `Vector2` dictionary keys. `StationBoard.placement_position()` performs optional snapping; `snap_offset()` adds half-spacing for even footprints. The 2×2 gate's four collision centers are offsets of ±29 around its continuous center, not integer grid indices. The model checks all four centers for bounds/overlap and at least one edge connection. It never rounds the supplied origin. Save validation also checks expanded footprints. No new gate snapping leak found.

Qualification: footprint dimensions are integer cell counts, geometry remains planar axis-aligned 58-unit squares with ±232 center bounds, and `footprint_rect()` returns `Rect2`. This is simulation geometry, not a 2D-node dependency. A 3D rendering of a planar game is feasible; volumetric placement requires redesign.

Region contents and hauling positions are also continuous `Vector2`, but use different units: station units, normalized Home supply coordinates and regional coordinates projected against an 800×600 reference. The collection conversion and fixed regional generation bands are the remaining spatial abstractions to clean up. Region catalog `coordinate` has three components but does not drive travel distance, generation or placement.

## 2. Complete definition inventory

“Data-driven” here means additional definitions using supported capabilities can be added without changing transaction code. It does not mean arbitrary new behavior, artwork or safe migration requires no code.

| File | Every current definition | Verdict |
|---|---|---|
| `data/modules.json` | `habitat` Habitat; `solar` Solar Panel; `storage` Storage; `mining_ship` Mining Ship dock; `refinery` Refinery; `space_depot` Space Depot; `research_lab` Research Lab; `teleport_gate` Teleport Gate | Data-driven costs, power, capacity, upgrades and supported capabilities/footprints. New behavior needs an interpreter; art must reuse a supported key or gain rendering code. |
| `data/ships.json` | `miner` Miner; `scout` Scout; `trader` Trade Ship; `material_ship` Material Ship | Data-driven variants and combinations of mining/survey/trade/collection. Commands come from a fixed capability registry. New roles need code. |
| `data/sectors.json` | `home` Home orbit; `dawn` Dawn arc; `twilight` Twilight arc; `echo` Echo pocket; `quiet` Quiet reach | Data-driven supported content and predecessor links; multi-hop predecessor discovery works. Existing-save sector additions are not merged automatically. |
| `data/regions.json` | `home` Home/Earth; `venus` Venus; `mars` Mars; `pluto` Pluto | Data-driven neighbor graph, survey time and generated content ranges. New regions require matching planet/anomaly references. Existing region saves reject newly missing catalog records. Home remains special. |
| `data/factions.json` | `lumen` Lumen Archive; `concord` Prism Concord | Data-driven faction definitions/initial standing. Contacts and offers must reference them. Additive defaults support existing saves. |
| `data/technologies.json` | `teleportation` Teleport Gate: 2 Tech, no prerequisites, unlocks `teleport_gate` | Additional prerequisite/module-unlock technologies are data-driven. Only module placement currently consults unlocks; ship unlocks or research stat effects are not implemented merely by adding JSON categories. |
| `data/trade_goods.json` | `tech` Tech; `xenocrystal` Xenocrystals | New inventory/reward goods are data-driven and receive additive defaults. A useful new sink needs supported consuming behavior. Research explicitly spends `tech`; trade costs read station fields, not trade inventory. |

Supporting content is also data-backed:

- `trade_offers.json`: `archive_data` Research exchange; `archive_gift` Supply the archive; `prism_gift` Goodwill cargo; `prism_crystals` Crystal exchange.
- `aliens.json`: `quiet_signal` Quiet signal, containing `lumen_envoy` Archivist Iri and `prism_envoy` Navigator Venn; `ion_chorus` Ion chorus, granting one Tech.
- `region_anomalies.json`: `spectral_archive` Spectral archive; `crystal_remnant` Crystal remnant.
- `planets.json`: `earth`, `venus`, `mars`, `pluto`. `supply.json` controls replenishment; `decommission.json` controls recovery.

Other extension limits: region generation only understands asteroid/anomaly content; region structures are placeholders; HUD navigation initially selects `venus`; colony baseline capacity/output and level formula remain hard-coded. Trade persistence only accepts Materials/Minerals as cargo costs, so adding inventory goods as costs is not data-only.

## 3. Economy across all systems

| Resource/system | Sources and consumption | Sustainability / remaining trap |
|---|---|---|
| Materials | Renewable debris: 8–14 per piece, spawn attempt every 3s; refinery converts 2 Minerals → 6 Materials every 3s, upgraded to 2s. Construction, ships, upgrades and goodwill consume Materials. | Free manual salvage provides recovery independent of power/ships. Normal collection respects capacity; refunds deliberately permit overflow. No negative-salvage or full-storage refinery loss found. |
| Power | Baseline 3; starting Habitat uses 2. Solar net +5, upgraded net +9. All owned hulls/modules reserve their configured demand. | No fuel consumption. Finite build area limits growth, but consumer removal and ship sales free power/space. Remote and idle ships still reserve power. |
| Minerals | Renewable Home asteroid: 18 per spawn attempt every 12s; finite sector/region deposits. Miner yield 18/8s. Refining, upgrades and trade consume ore. | Renewable at Home; no cap. Extra miners eventually exceed local replenishment. Remote deposits are finite and currently have no transport cost. |
| Tech | 18 Minerals → 1 Tech per 7s trade; one-time anomaly rewards. | Exactly one current research purchase costs 2 Tech. All later Tech is surplus with no implemented use. |
| Xenocrystals | After one 20-Material goodwill mission reaches Concord standing 8, exchange 12 Minerals + 8 Materials → 2 Xeno; regional anomalies also award Xeno. | Gate costs 1 per ship departure. Supply is renewable, but destination ships have no productive use/return, so this is not yet a healthy recurring sink. |

The unlock chain has no mandatory circular dependency: salvage → solar/miner/scout/trader → Echo contact → Tech exchange → lab → research → gate; goodwill unlocks Xeno trade independently. Region surveys/jumps also work without a gate, and anomalies can supply Tech/Xeno before research. No need to obtain Xeno through the gate it powers.

No profitable closed resource loop found in current definitions: hull/module refunds are 50%, the starting core cannot be sold, cancelled trade returns prepaid cargo without rewards, and discoveries/research are one-shot. Production is renewable rather than exponential. Build/sell or send/sell loops consume value.

Idle assets remain: completed Scouts, surplus miners, labs after the single research, collectors waiting at full storage/missing depot, and all arrived gate ships. Ordinary idle assets can be decommissioned. A Material Ship plus Depot costs 75 Materials and 3 power, hauls only one Material per trip, and competes for the same salvage available manually; multiple depots add capacity but do not provide separate inventories or processing throughput. Collector waiting preserves cargo and resumes when capacity/depot availability returns.

## 4. Cross-system integration

| Link | Result |
|---|---|
| Trade → research / gate goods | **Pass.** Completed escrowed trades credit the same inventory research/gate transactions debit. Research consumes Tech only; gates consume Xeno. No UI-only rewards. |
| Research → gate unlock | **Pass.** `StationModel.module_unlocked()` consults researched technologies; standalone StationModel callers also respect locks. Removing the lab does not revoke completed research. |
| Gate → region transport | **Partial.** Timed jobs debit inventory, persist, and set the owned ship's region on arrival. They do not change the viewed region. Only Home → discovered Home-neighbor routes work; no return/onward travel or remote work. Gate demolition intentionally lets existing transit finish. |
| Region graph / multi-hop | **Pass for navigation and discovery.** Home → Mars → Pluto works through neighbor checks, saved survey origins and unlocked adjacent jumps. Legacy sector routes now accept revealed predecessors too. **Not generic ship logistics:** gate routes do not use arbitrary origins or paths. |
| Material Ship → Depot → storage | **Pass for Home.** Supply removes actual debris into reserved ship cargo; delivery uses `model.collect()`, credits station Materials and depot delivered counters. Full storage retains cargo; depot loss pauses/reroutes; ship sale recovers cargo. Depot is an access/anchor/capacity module, not a local warehouse. |

Two “jump” systems coexist: free navigation changes the current region; paid gate transport moves a hull. Free navigation is not an illicit cost bypass in code, but it means gate unlock is unnecessary for access to all current deposits and anomalies. Regional surveying uses the viewed region as origin while the Scout remains a Home ship; this shortcut must be resolved before location matters operationally.

## 5. Prior-audit follow-up

| Prior risk | Current status |
|---|---|
| HIGH: full-station / zero-power lock | **Resolved by inspection.** Demolition and decommissioning free space/power and return Materials, including above capacity. Busy work releases reservations; new trade/hauling cancellation returns escrow/cargo. `tests/health_checks.gd` explicitly reconstructs the old lock and recovery. |
| HIGH: renderer-owned supply | **Resolved.** `SectorSupply` owns spawn, motion, expiry, salvage and RNG; views project existing state. `health_checks.gd` covers node-free supply and deterministic advancement. |
| MEDIUM: anomaly gameplay | **Resolved for current scope.** Sector anomalies establish contacts/reward Tech; region anomalies grant Tech/Xeno once. These resolve automatically, without a separate investigation mechanic. |
| MEDIUM: composable ship roles | **Resolved through intended Fleet APIs/HUD.** Shared `unit_busy()` covers mining, both survey types, trade, collection and transit; HUD builds one action per supported capability. Hybrid mining/survey/trade exclusion has tests. Direct low-level trade dispatch remains a bypass risk. |
| MEDIUM: power-loss consequences | **Still open.** No operating-power policy. |
| MEDIUM: economy sinks | **Partly resolved.** Trade/research/gates spend resources, but finite research and unproductive transport leave substantial surplus/idle-asset issues. |
| MEDIUM: generic exploration routes | **Resolved for exploration/navigation; open for transport.** Sector predecessor traversal and multi-hop regions exist; ship gates remain Home-only. |

## 6. Save/load integrity

**All identified current gameplay state has a persistence path** in `SaveStore.snapshot()`/`restore()`:

- Station modules and continuous positions, tiers, owned hulls/IDs, resources, capacity/power/level, tick phase, refinery progress and totals.
- Mining reservations/timers, remaining asteroid ore, sector discoveries, surveys, discovery IDs and totals.
- Supply rules, debris amounts/positions/velocities, Home asteroids, spawn phases, pending fixed-step time and exact RNG seed/state.
- `alien_trade`: faction standing/met flags, contacts, Tech/Xeno inventory, cargo escrow/jobs, history, processed anomalies and ID allocator.
- `regions`: current location, discovery/generated flags, contents, asteroid ownership, structures dictionaries, region RNG streams and survey origins/timers.
- `material_collection`: ship position, target reservation, depot assignment, cargo, waiting/status and depot delivered totals.
- `research`: researched technologies and lab completion counters.
- `gate_transport`: gate jump counters, ship locations and in-flight origin/destination/cost/timers, including transit after gate demolition.

Restore validates a candidate before committing; existing model references remain wired. Tagged vector/float encoding and string RNG values preserve precise state. Missing older extensions get defaults, v1 migrates to v2, and unknown top-level extension fields are preserved. Tests contain actual JSON round-trips, not only in-memory comparisons.

**Not persisted:** UI panels/selections, build tool, snap settings, hover/pulses, transient messages, visual animation phases, autosave timer/error flags and runtime catalog modifications. These are presentation/session/configuration, not missing current economic state. No offline elapsed-time catch-up is implemented. Installed catalogs remain authoritative: rebalance changes can reject saved power/capacity totals, and adding/removing definitions needs compatibility care. Unknown fields nested inside rewritten known dictionaries do not have the same blanket preservation guarantee as unknown extension fields.

Materially unresolved: unbounded-history versus 8 MiB loader mismatch; region catalog expansion incompatibility; old saves do not automatically gain new legacy sector entries. No complete current-state omission was found for normal same-catalog saves within size limits.

## 7. Outpost and 3D readiness

Before outposts, the principal design pressure points are:

1. One global StationModel owns Home modules, resources, power and capacity. `records.structures` is persisted but has no building/economy implementation; `outposts_enabled` is not a construction system. Build eligibility calls `primary_station_visible()`, coupling construction permission to viewed location.
2. Mining pays directly into Home Minerals; no cargo leg, destination inventory, local power, delivery or distance. Region navigation is independent of actual ship positions. Gates and collection explicitly encode Home-only rules.
3. Modules use positions as identity; jobs combine integer hull IDs and Vector2 dock keys. Identical positions in two stations would collide without region/station identity. Depot/lab/gate counters also use bare positions.
4. Fleet is the integration hub for all roles, regions, diplomacy, research and transport; collection is attached later by Supply. Shared busy checks, cancellation, save validation and HUD status precedence must be updated for each new role. There is no common mission/ownership interface.
5. Two discovery systems coexist, with separate catalogs, coordinates and jobs. Negative asteroid IDs encode discoveries, positive IDs Home supply; regional content retains original ore amounts while the fleet registry owns remaining ore. Consumers must choose the authoritative field.
6. SaveStore has hand-maintained field lists and cross-system validation. Outpost inventory/ownership/power would require migration and validation work, including additive-region defaults.

For 3D, the models can remain for a planar simulation, with replacement presentation/input adapters. True 3D needs a spatial policy beyond Vector2/Rect2, fixed tile geometry, normalized supply lanes and collection's fixed conversion. The three-component region map coordinates do not already provide that policy. Hard-coded art kinds, HUD refinery-condition duplication, fixed UI layout and visual flight interpolation are additional view work, not blockers in the economy model.

## 8. Automated coverage and limits

| System | Existing automated checks |
|---|---|
| Resources/building/power/capacity | `test_model.gd`; build rejection/atomicity and progression, plus `playthrough.gd`. |
| Mining/refining | `test_mining.gd`, `mining_playthrough.gd`; timers, reservations, yields, parallel units, conversion and storage pause. |
| Ships/upgrades/continuous placement | `test_ships_upgrades.gd`, `ships_upgrades_playthrough.gd`; purchase, repeated/partial mining, tier stats/costs, added variants and fractional positions. |
| Recovery/renderer-free supply | `health_checks.gd`, `health_playthrough.gd`; zero-power/full-station recovery, cancellation, overflow refunds, replenishment/population caps and deterministic supply. |
| Legacy exploration | `exploration_checks.gd`, `exploration_playthrough.gd`; discovery timing, reservations, depletion and anomaly/empty content. |
| Trade/factions/hybrids | `trade_checks.gd`, `trade_playthrough.gd`; contacts, standing gate, escrow, one-time rewards, cross-role exclusion, cancellation and persistence. |
| Regions | `region_checks.gd`, `region_playthrough.gd`; seeded generation, Home build restriction, multi-hop Pluto route, saved origins, remote mining, repeated jumps, old saves and malformed extension rejection. |
| Material hauling | `collection_checks.gd`, `collection_runner.gd`, `collection_playthrough.gd`; depot requirement, exact cargo, full-storage wait/resume, reservations, manual salvage race, depot removal, cargo recovery and persistence. |
| Research/gate/2×2 footprint | `research_checks.gd`, `research_runner.gd`, `research_playthrough.gd`; actual trade-to-research path, lock/payment, overlapping/bounded footprints, gate costs, transit occupancy, remote-work rejection, gate demolition and persistence. |
| Save/load | `persistence_checks.gd`, `persistence_playthrough.gd`, plus system suites; actual JSON, exact snapshots/evolution, RNG/clock, legacy migration, unknown extension fields and atomic rejection. |

Missing or weak: long-run whole-economy balance; history crossing loader size limit; existing-save migration after adding regions/sectors or rebalancing catalogs; automated architecture dependency enforcement; catalog schema/graph validation; comprehensive hybrid-role combinations including collection/transport; event-driven power failure; productive gate return/onward logistics and outpost behavior (not implemented). Existing gate tests deliberately assert remote work is blocked, so passing them does not establish a complete transport economy. Supply's long-run population test is not a full economy soak test.

Stored evidence inspected: research playthrough reports 31 checks true and no recorded errors; collection playthrough reports 11 checks true and no recorded errors. These are historical artifacts, not fresh audit runs. Tests that write saves/evidence were intentionally not executed under the read-only constraint.
