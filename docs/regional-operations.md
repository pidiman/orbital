# Regional ship operations

Ships use their physical `WorldLocations` region. A shared `local_destination`
resolver chooses Home storage at Earth or the player outpost in another region.
Transit remains exclusive: ships cannot work during a gate jump.

- Material collection enumerates canonical regional Depot structures, uses the
  existing region-specific supply/salvage callback, and delivers to local storage.
  One-unit cargo and existing movement rates remain unchanged. Full local
  Materials storage waits; cancellation recovers cargo locally. Regional ships
  now render outside Home too.
- Miner/Xeno Miner already used local mining routes; verified both outputs at
  Venus. A Home-region route now explicitly targets Home even for an outpost-
  purchased ship that returned there.
- Haulers resolve local refinery identity, buffers and destination. No remote
  refinery construction is enabled; without one, assignment reports no local
  Refinery. Home batch size and timings remain unchanged.
- Remote trading requires a contact in that region and an outpost. Costs, goods,
  and cancelled escrow use its inventory. Existing Home trade behavior remains.
  Standing and discovery progression remain global. Trade UI shows the selected
  ship's local goods. Outposts can persist recognized trade goods such as Tech.
- Scout exploration now originates at its physical region, never the viewed map.
- Jump Ship founding/building and gate transit are unchanged.

The shared Home-only work guard and obsolete work-region configuration are gone.
The existing v2 extensions store regional collection/hauling jobs; trade jobs add
an optional destination inside `extensions.alien_trade`. Old trade jobs without
it retain their original Home destination. Save validation permits remote work
while still rejecting work during transit and inconsistent storage identities.

Tests: `regional_operations_playthrough.gd` covers local collection, Ore/Xeno
mining, local trade, Scout origin independent of viewed map, no-refinery feedback,
active/finished save round-trips, and Home collection/hauling. Pioneer playthrough
also passes. No cross-region resource hauling or new outpost module types added.
