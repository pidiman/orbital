# Health audit fixes: recovery and simulation-owned supply

## Decommissioning

Inspect a placed module and use **Demolish**, or use **Decommission** below a ship command in Ships. Each action shows the Materials refund. `data/decommission.json` defaults to 50% of Materials investment, rounded down, including paid upgrade Materials. A module/ship definition can override `refund_ratio`. Minerals are not refunded.

The starting habitat is protected. Generator demolition is rejected if it would leave negative power; consumers and ships can be removed at zero power. Interior modules are removable, and remaining modules continue operating even if a connecting module is removed. This deliberately avoids a connectivity-based recovery lock. New construction still requires contact with an existing module, using continuous world geometry.

Demolition frees the world position, recalculates power/capacity/colony level, and clears tier/refinery state. Decommissioning a ship or dock cancels its mining mission and releases its asteroid. A sold Scout releases its destination to unexplored. Cancelled work awards no Minerals. Repeated commands cannot repeat the refund.

Existing Materials and the complete refund survive capacity loss. Above-capacity stock can be spent; new salvage and refinery output wait for room. `collect()` clamps available room at zero to prevent negative salvage credits.

## Supply architecture

`SectorSupply` (`scripts/sector_supply.gd`) is a RefCounted simulation owned by the game, advanced by the existing resource-clock driver. It owns initial/periodic debris and home-asteroid spawning, bounded populations, independent seeded RNG, drift and expiry, salvage amounts, partial collection and exhausted-debris removal. MiningFleet retains ore balances, reservations and depletion. All this works without nodes or a viewport.

`data/supply.json` holds counts, intervals, amounts, sector-space velocities, entry/exit coordinates and spacing. Coordinates are dimensionless sector coordinates, independent of window size and camera projection. A fixed 0.05-second simulation step makes equal elapsed time reproducible across update subdivisions.

`debris_field.gd` and `asteroid_field.gd` now only project snapshots to screen, render, display feedback and forward clicks to the models. They neither spawn economic entities nor decide expiry or rewards. Removing/recreating their presentation does not alter supply. Persistent exploration targets remain owned by the fleet model and do not consume home-asteroid spawn slots.

## Verification

- Combined model suite: 106/106 checks, including 34 new recovery/supply assertions. It constructs the full 81-module zero-power station through legal build/sale APIs, then proves recovery through demolition, salvage and replacement Solar. It also covers ship exhaustion, busy mission cancellation, capacity overflow, duplicate actions and data-driven refunds.
- Renderer-free supply assertions cover initial stock, spawn timers, ranges, drift, capacity limits, partial/full/repeated salvage, expired items, claimed asteroids, depletion cleanup, long-run replenishment, configurable amounts and seeded update-subdivision equivalence.
- Existing station model suite and 29/29 mining checks passed.
- Real-input recovery playthrough: 15/15, including full-station recovery using HUD actions and supply progression while both views are detached.
- Existing real-input playthroughs: MVP 10/10, mining 18/18, ships/upgrades/continuous positions 25/25, exploration 20/20. All finished without runtime errors or frame warnings.
- All changed scripts compile; git diff whitespace check passes. The runtime is entirely 2D.
- Earth SHA256 remains `8e0ad4e005111c623d9e6a03afc1eb1fe6cb1c34969e835b28325b1ce386669f`; active scene SHA256 remains `60feb2488b36a6a09ba3a45abbb1ab22b98aeac2c1d7908ff2bfd7e2d6108703`.

Results and screenshots are saved under `docs/health-*`.
