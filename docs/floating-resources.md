# Expanded grid and regional floating resources

The grid is now **33×33**, up from 17×17: cell centers extend equally from −16 to +16 in both axes (±928 model units). Tune `data/station_grid.json`. Existing module positions, stable IDs, continuous placement, snapping and multi-cell footprints are unchanged; saves never reflow the station.

`SectorSupply` remains the presentation-independent supply authority. Its existing `salvage()` command now handles typed regional pickups, partial Materials receipts, and one-unit Material Ship collection. Legacy saved debris remains collectible with its old amount, position and drift until collected or expired. Asteroid generation/mining is unchanged.

Tune `data/floating_resources.json`:

| Type | Weight / probability | Amount per pickup |
| --- | --- | --- |
| Materials | 85 / ~83.50% | 8–14 |
| Minerals | 14.8 / ~14.54% | 1–3 |
| Xenocrystal | 2 / ~1.96% | 1 |

Each discovered region starts with 5 pickups. A spawn is attempted every 3 seconds, up to 12 active pickups per region. New Materials/Minerals pickups last 60 seconds; unclaimed Xeno nodes last 180 seconds (per-type lifetime override). The full-population cap can skip spawn attempts. Positions are uniform across the expanded Home grid or the remote region playfield, independent of camera position and viewport. New pieces have stationary positions with rotating presentation art. Colors and labels identify type and amount.

Every generation draw consumes that region's existing saved RNG stream. `extensions.floating_resources` (schema 1) stores regional pools, clocks, types, amounts, positions and remaining lifetimes. Allocated IDs reuse the existing debris ID allocator. Old saves without the extension start regional pools on the next supply step, retaining all legacy debris and jobs. Load validates the extension before committing any state. Save version remains v2.

Manual Materials/Minerals pickups in any viewed region credit the existing Home inventory. Xenocrystals now require a Xeno Miner; see `docs/xeno-miner.md`. Home extraction credits trade-goods inventory; remote extraction credits local outpost storage. This is a manual floating bonus, not remote mining or outpost hauling. Material Ships remain Home-only, target Materials only and reuse `salvage(..., receiver, 1)`; their cargo, depot delivery and storage-full behavior are unchanged. Outpost mining still credits local storage.

Economy change: the former Materials-only floating source is now mixed and spread across the map. Xenocrystals are a single-unit approximately 1-in-51 spawn, a minor bonus compared with trade. Generation runs for discovered regions independently of which one is viewed, preventing menu/region switching from rerolling pickups.

Save, Load and Settings in Menu share the same filled/bordered normal and hover styles and typography.

Verification: floating model tests (20,000 spawns, type amounts, receipt, migration and deterministic continuation), 28 grid checks, live click/depot/Menu checks, plus collection, persistence, ownership, outpost and ship-tray regressions.

Spawn visibility fix: the old weight 0.2, shared cap of 12 and 60-second expiry made Xeno practically absent: 7 of 10 audited seeds produced none in 20 simulated minutes. The RNG, type registration and rendering were working. Weight 2 and a 180-second Xeno lifetime produced nodes in all ten audit seeds while remaining the rarest, smallest resource. This does not guarantee a spawn deadline. Existing saved lifetimes remain intact. Floating-clock subtraction now clamps tiny negative floating-point residues to zero so ordinary simulation snapshots pass existing save validation; no save schema changes.

## Materials debris art

Materials now select uniformly among five amber/rust 2D vector variants: riveted hull fragment, broken gridded solar panel, pipes/cables, cracked antenna dish, and dented hatch canister. `data/material_debris.json` defines palette and polygon/line/circle primitives; `types.materials.visual_variants` in `data/floating_resources.json` lists eligible stable IDs. Add an entry to both data files to extend the set without code changes. Cyan Xeno rendering is unchanged.

At spawn, a visual RNG copies the existing region seed and post-spawn RNG state; its draw never advances the gameplay stream. The optional `visual_variant` string is stored on the piece inside the existing v2 `extensions.floating_resources` pool. Old saves without it derive a stable fallback from region seed and piece ID. Missing art IDs also fall back gracefully. No quantities, timing, resource probabilities, movement, collection authority or save version changes. Materials art uses constant world scale, with a matching pointer hit area; camera zoom shrinks it exactly like modules.

`tests/debris_variants_playthrough.gd` checks all five randomly generated variants, 500 paired spawns with/without visual assignment (identical gameplay outputs and RNG state), v2 round-trip, legacy fallback, click-salvage quantities, and rendered galleries at normal/low zoom.
