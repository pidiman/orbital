# Regions MVP plan

StationModel stays anchored at Home/Earth. Region identity, abstract coordinates, adjacency and content are independent of views and travel controls; jump is an adapter over a location setter, with no panning or 3D.

- [ ] Add JSON region/planet/content catalogs and RefCounted RegionModel with stable independent RNG streams, one-time discovery, region survey jobs, structure slots and location state.
- [ ] Integrate Scouts with shared fleet occupancy; use data graph adjacency, generic legacy-sector reachability and global mining IDs. Preserve Home content and simulation.
- [ ] Add planet view, region/location HUD, Scout/jump controls, regional mining/report UI; hide and gate Home structures/salvage remotely.
- [ ] Add extensions.regions schema 1 to v2, staged validation, per-region RNG seed/state strings, active job persistence, legacy Home defaults and retained extension fields.
- [ ] Prove graph multi-hop, deterministic discovery/order independence, home-only building, background mining, no reward duplication, cancellation, malformed/old saves and exact round trips without rendering.
- [ ] Drive the live Home → Scout → jump → regional mining → Save/Load → return loop, capture planets, and rerun existing regression playthroughs.
