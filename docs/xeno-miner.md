# Xeno Miner

`data/ships.json` defines a sixth role, **Xeno Miner**: 70 Materials, 3 Power, `mining.resource = xenocrystal`, 20-second extraction cycle, yield 1, repeat enabled. The Ore Miner remains 45 Materials / 2 Power / 18 Minerals per 8 seconds. Mining capabilities default to Minerals for compatibility with old module definitions; matching uses the resource capability, never the ship type.

Buy it through Ships, select its tray tile or sprite, choose **Assign Xeno node**, then click a teal Xenocrystal node in its physical region. Clicking a node without selecting a ship can also assign an idle compatible miner. Wrong resource, busy ship, transit, and wrong-region assignments are rejected. The same MiningFleet dispatch, timer, repeat, cancellation, reservation, completion and visual flight paths handle both resources.

Xenocrystals are no longer click-salvageable, including old floating pickups. Materials and Minerals retain their click-salvage behavior; Material Ships still collect Materials only. The floating spawn weight is 2 (about 1.96%); nodes contain one unit and last 180 seconds unclaimed. See `docs/floating-resources.md` for the visibility fix. A claimed node stops expiring while the ship works; cancellation releases it and resumes expiration. Larger data-tuned nodes repeat one unit per cycle.

The **Xeno Dock** costs 25 Materials and 1 Power, initially parks 2 Xeno Miners, and uses the standard docking capacity upgrades: 3 / 4 / 6 / 8 slots for 30 / 55 / 90 / 140 Materials. No dock is required to work; homeless messaging and local-region parking are unchanged.

Home extraction credits the existing trade-goods Xenocrystal inventory. Remote extraction requires physical gate travel and an outpost, exactly like Ore mining; output stays in that outpost's local Xenocrystal storage. Old outposts gain a zero Xenocrystal balance when loaded. No remote hauling is added.

Save version remains v2. `extensions.resource_mining` (schema 1) binds existing fleet target IDs to typed regional floating nodes. Existing canonical assignments in `extensions.world_locations` carry the appropriate cargo resource/destination; the old fleet job/quantity fields remain compatibility projections. Floating quantity/lifetime and region RNG stay in their existing extensions. Old saves default to no Xeno ships or typed mining bindings; floating nodes are registered on the next supply step. Validation checks resource capabilities, source quantities, IDs, ownership and reservations before committing.

Tests: `xeno_checks.gd` covers costs, docks, filters, 8s vs 20s timing, pinned lifetimes, repeat/depletion, malformed-save rejection, remote storage and round trips. `xeno_playthrough.gd` exercises catalog/tray/commands, mouse assignment, real file save/load, delayed credit and Materials salvage.

## Spawn visibility investigation (2026-09-21)

The reported complete absence could not be reproduced in commit 9b7208b or the player's local v2 checkpoint. Before changing code, a disposable read-only copy of that checkpoint generated 6 Home, 3 Venus, 1 Mars and 6 Pluto Xeno nodes during 20 minutes of supply simulation. Only 2 of the 6 Home nodes were inside the default unobstructed camera view. No Home/outpost gate or type exclusion exists: all discovered regions use the same weighted table. Minerals were still present in this checkout; the 1–3 amounts belong to Minerals, whereas new Materials contain 8–14.

Resolved table (unchanged by this visibility fix): Materials weight 85, amount 8–14; Minerals weight 14.8, amount 1–3; Xenocrystals weight 2 (~1.96%), amount 1. Spawn attempt every 3 seconds; shared regional cap 12; initial count 5. Xeno lifetime 180 seconds unclaimed. The generator samples the entire regional map, independently of the camera, so absence from the viewport does not prove absence from the pool. No guaranteed spawn deadline is imposed.

Confirmed presentation defect: Xeno reused the cratered Ore silhouette and purple, zoom-shrinking label. It now uses a three-shard cyan crystal (`#67f5e1`), a dark-backed “Xenocrystals · 1” label (also visible during extraction), and a minimum rendered size at zoom-out. Hit testing scales with that marker; quantities, positions, lifetimes, RNG and saves are untouched. Materials retain their existing art.

`tests/xeno_spawn_audit.gd` prints/reports the actual resolved table, advances natural Home/Venus spawns without forcing weights, captures the crystal at normal and low zoom, checks mining-only salvage rejection and deterministic save continuation. Set `ORBITAL_AUDIT_SAVE` to an absolute checkpoint path for a read-only reproduction from that save; otherwise it uses a deterministic disposable fixture. The user checkpoint is never written. This test supports diagnosis; it does not establish why a different build or session might show no Xeno.
