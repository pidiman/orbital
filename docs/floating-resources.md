# Expanded grid and regional floating resources

The grid is now **33×33**, up from 17×17: cell centers extend equally from −16 to +16 in both axes (±928 model units). Tune `data/station_grid.json`. Existing module positions, stable IDs, continuous placement, snapping and multi-cell footprints are unchanged; saves never reflow the station.

`SectorSupply` remains the presentation-independent supply authority. Its existing `salvage()` command now handles typed regional pickups, partial Materials receipts, and one-unit Material Ship collection. Legacy saved debris remains collectible with its old amount, position and drift until collected or expired. Asteroid generation/mining is unchanged.

Tune `data/floating_resources.json`:

| Type | Weight / probability | Amount per pickup |
| --- | --- | --- |
| Materials | 85 / 85% | 8–14 |
| Minerals | 14.8 / 14.8% | 1–3 |
| Xenocrystal | 0.2 / 0.2% | 1 |

Each discovered region starts with 5 pickups. A spawn is attempted every 3 seconds, up to 12 active pickups per region. New pickups last 60 seconds. The full-population cap can skip spawn attempts. Positions are uniform across the expanded Home grid or the remote region playfield, independent of camera position and viewport. New pieces have stationary positions with rotating presentation art. Colors and labels identify type and amount.

Every generation draw consumes that region's existing saved RNG stream. `extensions.floating_resources` (schema 1) stores regional pools, clocks, types, amounts, positions and remaining lifetimes. Allocated IDs reuse the existing debris ID allocator. Old saves without the extension start regional pools on the next supply step, retaining all legacy debris and jobs. Load validates the extension before committing any state. Save version remains v2.

Manual Materials/Minerals pickups in any viewed region credit the existing Home inventory. Xenocrystals now require a Xeno Miner; see `docs/xeno-miner.md`. Home extraction credits trade-goods inventory; remote extraction credits local outpost storage. This is a manual floating bonus, not remote mining or outpost hauling. Material Ships remain Home-only, target Materials only and reuse `salvage(..., receiver, 1)`; their cargo, depot delivery and storage-full behavior are unchanged. Outpost mining still credits local storage.

Economy change: the former Materials-only floating source is now mixed and spread across the map. Xenocrystals are a single-unit 1-in-500 spawn, a minor bonus compared with trade. Generation runs for discovered regions independently of which one is viewed, preventing menu/region switching from rerolling pickups.

Save, Load and Settings in Menu share the same filled/bordered normal and hover styles and typography.

Verification: floating model tests (20,000 spawns, type amounts, receipt, migration and deterministic continuation), 28 grid checks, live click/depot/Menu checks, plus collection, persistence, ownership, outpost and ship-tray regressions.
