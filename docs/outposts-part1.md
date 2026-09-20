# Outposts: founding and local mining

## Player flow

1. Buy a **Jump Ship** in Ships: **65 Materials, 2 Power**.
2. Use the existing researched Teleport Gate to send it to a discovered adjacent region. The existing gate definition still charges **1 Xenocrystal** per ship.
3. After arrival, use that hull's **Found outpost** command in Ships. Founding spends **60 Home Materials**, instantly creates one player outpost in that region, and leaves the Jump Ship intact. Viewing a region alone is insufficient; the hull must physically be there. The founding cost is shown in the command tooltip and insufficient-funds message.
4. Send a Miner through the gate to the same region. Assign a local asteroid from the view or region panel. Its normal yield/timer/repeat behavior credits the **outpost's local Minerals**, never Home.
5. The outpost marker, region details and orbit readout show local Minerals. The top resource bar remains Home inventory.

Founding is a single atomic command; there is no additional timer or pending construction stage. Repeated commands neither spend again nor create duplicates. Each player region has at most one outpost. Founding does not depend on the viewed region. The main station, hull power costs and ship decommission refunds remain at Home. Removing the founding hull leaves the established outpost and its historical founder ID intact.

## Model and data

- `data/ships.json`: `jump_ship` composes the `founding` capability through the existing HUD capability registry; no role-name branching. A hybrid definition can combine `founding` and `mining`.
- `data/outposts.json`: outpost name, founding resource costs, initial local storage, logical position and reused 2D art. Current cost is Materials only; existing trade goods such as Tech are supported as optional definition costs.
- `data/regions.json`: `structures.outposts_enabled` controls eligible regions. Discovery and existing gate adjacency still apply.
- `OutpostModel` is a presentation-independent RefCounted command/validation service. Canonical state remains in `WorldLocations`.
- Each outpost is a distinct `station:outpost:N` owner, linked to `structure:N`, with owner, region, definition, mineral inventory and established founding record. Continuous position is not identity. Same coordinates in Venus and Mars do not collide.
- Local mining assignments use `local_outpost` and record physical actor region, target region, destination station/region and cargo. `WorldLocations.receive()` credits the named local inventory. Mineral storage has no capacity limit, matching existing Home Minerals; Materials capacity behavior is unchanged.

## Intentional behavior change and old saves

**The `legacy_remote_home` shortcut is retired for new orders.** A Home Miner can no longer extract Venus/Mars/Pluto ore without travelling. Remote mining requires an outpost and a physically local Miner. Home ore, including existing Home exploration-sector deposits, keeps its old yield, timing, repeat and Home destination.

Save format stays v2. `extensions.outposts.schema_version = 1` marks the policy version. New ownership/storage/founding data extends `extensions.world_locations.stations`, `.structures`, and `.ships`; local assignments remain in its existing `.mining_assignments`. Core save schema is unchanged.

Pre-outpost saves load with no outposts. Existing identity graphs, gate locations/transit, research, trade and Home jobs are preserved. Active legacy cross-region mining orders are cancelled on migration and their reservations released; remaining asteroid ore and previously credited resources are unchanged. Partial mission progress is discarded. A bottom-bar migration message explains the change. Pre-location v2 saves also assign Home ownership/identity as before. Migrated saves round-trip normally and do not repeat the notice.

Validation rejects malformed inventories, owner/region/structure/founder mismatches, unsupported extension versions and incorrect mining destinations before mutating live state. Founder IDs can remain historical after decommissioning. Outposts and their storage have one canonical authority, not duplicate records in the older region-content placeholder dictionary.

## Scope limits

No return hauling, outpost module construction, remote trade, remote Material Ship collection, remote research or extra gate routes. Gates retain their existing Home-to-discovered-neighbor restriction; discovering Pluto does not create a direct Home gate route. Outposts add no independent power grid. Remote inventories cannot fund Home trade, research or construction.

## Verification

Model tests cover the complete path, data-defined costs and hybrid capabilities, duplicate/cost/transit rejection, same-region mining, Home isolation, separate Venus/Mars inventories, active jobs and established/historical founding save/load, JSON disk round-trip, atomic corrupt-save rejection and both legacy v2 migration paths.

Verified suites: core economy passed; mining 29/29; combined ships/upgrades/exploration/recovery/trade/persistence/location/outposts 341/341; research 42/42; material collection 19/19. The 24,000-trade soak retains 256 records and produces an approximately 125 KiB save, below the unchanged 8 MiB loader cap.

Rendered input walkthroughs: outposts 23/23, research/trade/gates 31/31, Material Ship 11/11, and multi-region 27/27. Outpost walkthrough uses a funded/discovered fixture, then real UI purchase/research/gate/found/mine/save/load inputs; the separate trade walkthrough obtains Tech and Xenocrystals through actual trades. All completed with no probe errors. The ship purchase catalog now scrolls so the fifth role fits without obscuring controls or the bottom message bar.

Final diagnostics: zero script/runtime errors. The editor still reports two nonblocking, unclassified console warnings (the visible entry concerns Control focus); no warnings were reported by the completed verification probes.
