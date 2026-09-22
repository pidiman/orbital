# Starting infrastructure and Depot ship purchases

Fresh startup and New game initialize Materials from `data/new_game.json`:
Space Depot 35 + Space Dock 25 + Solar 20 + buffer 50 = **130 Materials**.
The module list and buffer are tunable. The initial grant may exceed Home's
100 storage capacity; capacity itself is unchanged, so collecting more waits
until spending creates room. Loading a saved game never applies this grant.

Ship purchases require a Space Depot in the viewed base. Depot eligibility uses
the existing module capability. With multiple Depots, the first owned Depot is
used. At an outpost, purchases spend local Materials and consume local power;
prices and per-ship power draws are unchanged. Space Depot is now included in
the outpost's data-driven module allowlist.

Ships receive the purchasing base's identity and region. Their purchase position
is saved under the existing `extensions.world_locations.ships` record; old ships
without this optional field retain their previous idle-position fallback.
Newly purchased sprites start beside the Depot. Existing docking reserves a free
regional slot, and the existing visual interpolation flies the sprite there.
Without a slot, the ship stays beside the Depot and the usual homeless status
appears. No task eligibility or job timers depend on visual arrival.

Save version remains 2. Power validation now waits for canonical ship ownership
to load, so local outpost ships are not charged against Home's power.

Verification: `tests/depot_purchase_playthrough.gd` exercises New game,
infrastructure costs, Home/outpost purchase blocking, local payment and power,
spawn position, interpolation, docking/homeless fallback, v2 round-trip, and an
older Home save retaining its original 40 Materials.
