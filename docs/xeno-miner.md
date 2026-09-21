# Xeno Miner

`data/ships.json` defines a sixth role, **Xeno Miner**: 70 Materials, 3 Power, `mining.resource = xenocrystal`, 20-second extraction cycle, yield 1, repeat enabled. The Ore Miner remains 45 Materials / 2 Power / 18 Minerals per 8 seconds. Mining capabilities default to Minerals for compatibility with old module definitions; matching uses the resource capability, never the ship type.

Buy it through Ships, select its tray tile or sprite, choose **Assign Xeno node**, then click a teal Xenocrystal node in its physical region. Clicking a node without selecting a ship can also assign an idle compatible miner. Wrong resource, busy ship, transit, and wrong-region assignments are rejected. The same MiningFleet dispatch, timer, repeat, cancellation, reservation, completion and visual flight paths handle both resources.

Xenocrystals are no longer click-salvageable, including old floating pickups. Materials and Minerals retain their click-salvage behavior; Material Ships still collect Materials only. The rare 0.2% floating spawn weight and single-unit default node quantity are unchanged. A claimed node stops expiring while the ship works; cancellation releases it and resumes expiration. Larger data-tuned nodes repeat one unit per cycle.

The **Xeno Dock** costs 25 Materials and 1 Power, initially parks 2 Xeno Miners, and uses the standard docking capacity upgrades: 3 / 4 / 6 / 8 slots for 30 / 55 / 90 / 140 Materials. No dock is required to work; homeless messaging and local-region parking are unchanged.

Home extraction credits the existing trade-goods Xenocrystal inventory. Remote extraction requires physical gate travel and an outpost, exactly like Ore mining; output stays in that outpost's local Xenocrystal storage. Old outposts gain a zero Xenocrystal balance when loaded. No remote hauling is added.

Save version remains v2. `extensions.resource_mining` (schema 1) binds existing fleet target IDs to typed regional floating nodes. Existing canonical assignments in `extensions.world_locations` carry the appropriate cargo resource/destination; the old fleet job/quantity fields remain compatibility projections. Floating quantity/lifetime and region RNG stay in their existing extensions. Old saves default to no Xeno ships or typed mining bindings; floating nodes are registered on the next supply step. Validation checks resource capabilities, source quantities, IDs, ownership and reservations before committing.

Tests: `xeno_checks.gd` covers costs, docks, filters, 8s vs 20s timing, pinned lifetimes, repeat/depletion, malformed-save rejection, remote storage and round trips. `xeno_playthrough.gd` exercises catalog/tray/commands, mouse assignment, real file save/load, delayed credit and Materials salvage.
