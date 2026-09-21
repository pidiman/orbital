# Outpost mini-bases

Founding keeps its existing 60 Materials cost and transfers another 300 Materials from Home into the new outpost: 360 Home Materials must be available before either operation happens. Both `cost` and `starter_transfer` are configurable in `data/outposts.json`. The transfer is an inventory movement, not generated resources.

Only the existing Solar, Storage, Space Dock and Teleport Gate definitions are allowed by `buildable_modules`. View the outpost region and use Build or inspect its modules. The board uses the existing continuous positions, snapping, connectivity and 2×2 gate footprint. The core anchors the grid and cannot be demolished. Upgrades and demolition use the existing costs, effects, Power checks and refund rules against local resources.

A station-scoped StationModel adapter shares WorldLocations while resolving module positions against its explicit station ID. Home's default adapter, inventory, ships and simulation remain unchanged. Distinct outposts and Home can place modules at identical coordinates without identity collisions. Ship ownership and purchase Power remain at Home; outpost module Power is separate.

Outposts start with 300 Materials capacity and zero generated Power; Solar supplies local Power. Storage adds its existing capacity bonus. As at Home, Materials capacity and the existing unrestricted mined-Minerals inventory are distinct; this change does not discard or cap old local mining stock. Demolition preserves above-capacity stock/refunds, as at Home. There is still no resource hauling to Home and no remote Refinery, Habitat or Research Lab construction.

Gates are selected by stable structure identity and display their region. Ships must physically be in their departure gate's region, idle, and use discovered adjacent routes from the existing region graph. Home remains a valid destination. Departure costs use Home inventory for Home gates and the local Xenocrystal store for outpost gates. The existing data-driven jump price/time are unchanged. Cancelled jumps refund the departure inventory; launched jumps survive gate demolition.

The v2 `extensions.world_locations` graph stores grid dimensions, station inventories, module identity/ownership/region/positions/tier, gate counters and founding's `starter_transfer` record. Power and capacity reconstruct from the saved local modules/tiers and definitions, avoiding conflicting duplicate totals. Dock reservations and transit remain in their existing extensions.

Old outposts gain a zero Materials inventory entry, retain their Minerals/Xenocrystals, and receive no transfer retroactively. Their old decorative core marker is placed at the new grid origin; no player-built modules existed to move. They use the current data-driven grid (33×33 by default). New outposts record their grid dimensions at founding. Home module positions and inventories are unchanged.

Validation covers allowed modules, tiers, technology locks, footprint bounds/overlaps, local Power, inventory quantities and transfer records. `tests/outpost_base_playthrough.gd` covers founding affordability/transfer, UI placement, local costs and mining, identity collisions, Power/Storage/docks, outbound and return gates, transit and disk round-trips, upgrade/demolition and legacy migration. Existing outpost, research, refinery, hauling and Space Dock regressions remain covered.
