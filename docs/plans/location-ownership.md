# Location and ownership refactor

Behavior is frozen. No outposts, remote work, new destinations, timing, cost or UI changes.

- Add RefCounted WorldLocations with stable station/structure IDs, explicit owner/station/region on ships and structures, and monotonic structure allocator. Ship transit is explicit. StationModel's old position maps become derived primary-station adapters; counter/state dictionaries belong to structure records.
- Keep RegionModel's viewed region separate from ownership. GateTransport delegates physical ship location to WorldLocations. Legacy gate location maps are serialization adapters only.
- Mining assignments use typed stable actor IDs, explicit actor/target regions, destination station/region and cargo. Preserve immediate end-of-cycle delivery and repeating timers. Explicit catalog policy preserves Home remote mining and view-origin survey shortcuts for review. Collection resolves local supply/depot IDs and uses the same destination inventory adapter.
- Persist canonical ownership/identities/mining routes in a new v2 extension. Validate against legacy projections and cross-system references before committing. Missing extension deterministically migrates Home objects and assignments, preserving existing gate relocations/transit rather than moving ships back Home.
- Run unchanged model suites and rendered Home/trade/gate/hauling/region probes; add identity, same-position-in-different-regions, migration, destination, malformed-state and cross-view regression checks.
