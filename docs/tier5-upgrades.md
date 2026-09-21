# Tier 5 module upgrades

All previously upgradeable modules (Habitat, Solar Panel, Storage and Refinery)
now have four upgrade definitions, reaching T5. The five dedicated ship docks
also have T2–T5 upgrades. Other modules retain their existing non-upgradeable
status. Definitions, costs and effects remain in `data/modules.json`.

## Progression

| Module | T1 | T2 | T3 | T4 | T5 |
|---|---:|---:|---:|---:|---:|
| Habitat: Materials capacity bonus | 0 | 25 | 60 | 110 | 175 |
| Solar Panel: Power generation | 6 | 10 | 16 | 24 | 34 |
| Storage: Materials capacity bonus | 75 | 150 | 250 | 375 | 525 |
| Refinery: Minerals → Materials / seconds | 2→6 / 3s | 2→6 / 2s | 2→6 / 1s | 4→12 / 1s | 6→18 / 1s |
| Each typed dock: parking slots | 2 | 3 | 4 | 6 | 8 |

Power draw, footprints and other base stats stay unchanged. Refinery throughput
increases each tier while retaining a 3:1 conversion ratio; processing remains
on the existing integer-second clock. Dock slots use the same `docking.capacity`
field, read from the structure's resolved tier definition. Stable occupied slots
are retained and homeless ships automatically fill newly available slots.

## Upgrade costs (incremental, not cumulative)

| Module | To T2 | To T3 | To T4 | To T5 |
|---|---|---|---|---|
| Habitat | 20 Materials + 6 Minerals | 45 Materials | 80 Materials | 125 Materials |
| Solar Panel | 30 Materials + 8 Minerals | 55 Materials | 90 Materials | 140 Materials |
| Storage | 25 Materials + 6 Minerals | 50 Materials | 85 Materials | 130 Materials |
| Refinery | 35 Materials + 10 Minerals | 65 Materials | 110 Materials | 170 Materials |
| Each typed dock | 30 Materials | 55 Materials | 90 Materials | 140 Materials |

The request specified both Materials-only upgrades and unchanged existing tier
costs. Existing T2 costs/effects are preserved; all newly introduced upgrades
are Materials-only. No new tier costs Tech or Xenocrystals. If the intended
policy is to remove the legacy Mineral charges too, deleting those four data
keys is sufficient, but that is an explicit existing-cost change.

Costs remain resource dictionaries. The existing StationModel upgrade command
now handles optional Materials/Minerals keys and the trade inventory's resources
(such as Tech or Xenocrystals), validates every cost before spending, and formats
the same dictionary for the UI. Future resource costs need only data edits.
Demolition refunds still follow the existing Materials-investment rules.

## UI and persistence

Inspection lists T1–T5 with costs/effects, marks the current tier, and previews
the next tier. The Upgrade button shows its cost and disables with a clear
insufficient-resource tooltip. The panel scrolls above the bottom message bar;
T5 shows Maximum tier. Dock inspection uses upgraded occupancy/capacity.

Save version and schema remain unchanged. Tier values already persist in the
v2 core compatibility projection and `extensions.world_locations` structure
state. Parking assignments/usage already persist under `extensions.docking`.
The loader validates against the now-longer data arrays and resolved dock tier.
Old T1/T2 saves restore exactly and can upgrade further; no migration rewrite or
new extension fields are necessary.

## Verification

`tests/tier5_runner.gd` covers all nine upgradeable module definitions through
T5, exact spending, improving stats, stable IDs, dock capacity filling, maximum
and insufficient-funds rejection, old-definition snapshot migration, high-tier
round-trips, T5 refinery conversion and data-only future currency costs.
`tests/tier5_playthrough.gd` drives solar and Miner Dock upgrades through the real
UI, checks previews, all tiers, capacity usage, footer clearance, insufficient
Materials and actual disk save/load. Existing regression tests retain their T2
cost/effect assertions; only former T2-maximum expectations advance to T5.
