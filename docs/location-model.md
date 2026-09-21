# Location and ownership groundwork

The original refactor preserved gameplay. Outposts part 1 now adds founding and local mining; see [outposts-part1.md](outposts-part1.md) for current behavior, migration and verification. All models stay RefCounted and rendering stays 2D.

## Authority and compatibility

`StationModel.locations` (`world_locations.gd`) owns the identity graph:

- `stations[station_id]`: stable ID, owner, region. Outpost stations additionally hold definition, linked structure ID, local inventory and founding state. The data-defined primary station is `station:home`, owned by `player`, at Earth (`home`).
- `structures[structure_id]`: monotonic `structure:N` ID, kind, station ID, owner, region, continuous Vector2 position, and state. Tier, refinery progress, lab completions, depot deliveries and gate jumps belong to this record.
- `ships[ship_id]`: existing monotonic integer ID, kind, owning station, owner, physical region, and transit origin/destination. Ownership stays Home after teleportation; its power cost and recovery rules stay unchanged.

Position is geometry, never global identity. `(station_id, position)` resolves a structure; equal positions at different stations do not collide. Demolition removes the record; rebuilding allocates a new ID. Upgrade retains the ID. Existing snapping and 2×2 footprint rules are untouched.

`RegionModel.viewed_region` is navigation/presentation state, with `current_region` retained as a compatibility alias. Viewing Pluto never relocates ships or structures. GateTransport reads physical ship locations from the graph and changes them on arrival.

The old `modules`, `ships`, tier/progress, gate location and capability-counter dictionaries are compatibility projections for the existing UI and v2 core schema. Their whole-property setters are migration adapters. Do not mutate scalar entries or clear a returned projection: use model commands or canonical records. Nested job/counter dictionaries reference canonical state.

## Work and delivery

Mining assignments are keyed by typed actor identity (`ship/1`, `structure/structure:2`), with explicit origin region, target asteroid ID/region, destination station/region, cargo and policy. The existing `fleet.jobs` map exposes timers to the current UI/save adapter. At the existing completion tick, mined cargo passes through the destination inventory adapter. Yield, repetition and timing are unchanged; no extra hauling leg is introduced.

Material collection resolves the ship's physical region, that region's supply, a stable depot ID and owning destination station. It calls the existing salvage operation, carries one Material, and deposits through the same inventory adapter. Full-storage waiting, removed-depot waiting, recovery and automatic resume retain their old behavior. Gates retain their source structure ID even after demolition, so launched trips still finish.

`data/location_rules.json` declares primary ownership, supported work regions, the current supply region and compatibility policies. Unsupported inventory destinations do not silently credit Home. Outposts now register their own local mineral inventories in this adapter; Home hauling remains unavailable.

## Save migration

Save version remains **2**. `extensions.world_locations` schema 1 stores stations, structures, ships, the structure ID allocator and canonical mining assignments. Existing collection/gate extensions additionally store depot/destination and launch-gate identity. Outposts part 1 adds `extensions.outposts` schema 1 and additive outpost inventory/founding fields to the canonical graph, without changing the v2 core. The old core fields remain compatibility projections.

A save without the new extension gets deterministic structure IDs and Home ownership/location defaults. Existing gate relocation/transit takes precedence over the default, preserving old gameplay. Active mining and collection routes are reconstructed; missing demolished depots/gates remain valid historical references. Validation checks canonical state against the old projections before committing the entire candidate. Unknown extension metadata is retained.

## Compatibility policies and outpost transition

- **`legacy_remote_home` is now disabled for new orders.** Remote mining requires a physically local Miner and an outpost; delivery uses `local_outpost`. Pre-outpost saves release legacy cross-region orders without consuming their remaining ore and show a migration notice.
- Regional Scout surveys still select their route origin from the viewed region (`viewed_region_legacy`); the ship's physical Home location stays distinct.
- Gate arrivals can found outposts through the `founding` capability or mine locally through `mining` after an outpost exists. Return travel, full remote module construction and material hauling are not implemented. Other work remains Home-only.

## Original refactor verification (historical)

`tests/location_checks.gd` exercises 62 identity/location/migration assertions, included in `test_ships_upgrades.gd`: same-position identities across stations, upgrade/rebuild IDs, explicit remote mining yield/timing, view isolation, collection cargo/wait/resume, gate transit/arrival, atomic corruption rejection, old v2 migration (including demolished launch/drop-off structures), deterministic continuation and disk round-trip.

Existing model/economy, mining, research, collection, trade, recovery, exploration and persistence tests remain in use. Rendered research/trade/gate, collection and multi-region probes verify the player flows. The 24,000-trade soak still retains 256 recent records and produces a roughly 125 KiB save, below the unchanged 8 MiB loader cap.

Latest verification: core economy passed; mining 29/29; combined ships/upgrades/exploration/recovery/trade/persistence/location suite 285/285 (including 62 location checks); research 42/42; collection 19/19. Rendered probes: research/trade/gates 31/31, collection 11/11, regions 27/27, all finished without probe errors. Editor diagnostics reported zero script/runtime errors and two unclassified console warnings (Control focus warning shown); no gameplay warning was introduced by the model refactor.

## Typed parking

`fleet.docking` now reserves local, owner-matched slots by stable structure ID.
Its assignments and usage persist in `extensions.docking` schema 1. Parking does
not change physical regions, ownership, work eligibility or delivery routing.
See [docking.md](docking.md) for configuration, migration and parking rules.
