# Pioneer jumps

`data/ships.json` grants Jump Ship the `pioneer` capability and a `gate_building`
command whose module is `teleport_gate`. Other ships still require paired gates.
Pioneer jumps reuse gate transit, departure power, discovered-region checks and
normal departure-local Xenocrystal cost (currently 1 per jump).

Gate/Travel labels destinations Gate available / No gate / Unknown. A valid
pioneer trip requires explicit one-way confirmation before charging or departing.
Without a departure gate, the ship cannot return. Existing normal gate travel is
unchanged.

Destination gates use an outpost, not standalone structures. Found outpost uses
the existing Home-funded founding cost and starter transfer. Build Teleport Gate
checks research and enters ordinary 2×2 placement on that outpost's grid. Normal
local Materials, Solar power, footprint, upgrade and demolition rules apply.
There is no free gate, carried resource pool, or additional construction system.
Return trips require Xenocrystals in the departure outpost's local inventory.

Existing v2 region/ship/transit and outpost/module extensions already persist all
required state, so no schema change or special old-save migration is needed.

`tests/pioneer_playthrough.gd` verifies Scout discovery, non-pioneer blocking,
warning/confirmation, charge, transit reload, arrival, no return gate, founding,
local gate placement/cost, return travel, normal paired travel and save round-trip.
