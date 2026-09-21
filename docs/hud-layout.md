# HUD layout

The top bar places ORBITAL inline with Build, Ships, Research, Gate/Travel, Outposts/Regions, and
Trade/Contacts. Only one panel is visible. Click/tap the active toolbar button,
use the fixed Close button, or press Escape to close it. Panels scroll within
the space above the message bar. Buttons have at least 44 logical pixels of
height; the inline toolbar scrolls horizontally on narrow viewports.

Power, Materials, Minerals, Tech, Xenocrystals, Save/Load, and the viewed-region
indicator remain visible. The region indicator describes the view, not a ship's
physical location. Gate/Travel lists ship locations and transit status.

- Build contains the complete module catalog, including the legacy Mining Ship
  module. Selecting a module closes the panel for placement. Clicking a built
  module opens its inspection, upgrade, and demolition controls in Build.
- Ships contains the purchase catalog only.
- The horizontal owned-ship tray reuses each role’s existing `art` and shows its
  status. It scrolls for large fleets. Click/tap a tile to select that ship, view
  its physical region, center the Camera2D on its drawn position, and open its
  commands. Every capability action and decommission remain available. Gate /
  Travel opens with that ship preselected. Assigning a Miner closes the panel
  so the player can click an asteroid.
- Reset view restores the current region’s default camera. Camera position and
  ship selection are transient UI state; loading resets them. The existing saved
  viewed-region field continues to work unchanged.
- Teleport-transit tiles focus the departure gate and display the destination;
  the model has no between-region spatial coordinates. Clicking again after
  arrival focuses the destination region. Collection and mining focus use the
  exact same position functions as their ship drawings.
- Research contains technology descriptions, Tech costs, and research states.
- Gate/Travel contains departure gate, ship, destination, and jump cost controls.
- Outposts/Regions contains region discovery/routes, local outpost storage,
  Scout and local mining commands, view navigation, and Home-sector exploration.
- Trade/Contacts contains factions, standing, inventory, offers, and history.

This change affects HUD/view scripts only. RefCounted models, catalog data,
economy, simulation, and the v2 save format are unchanged. Existing handlers
still call the same model APIs. Opening menus does not mutate a save snapshot.

Verification covers mouse and native touch events, exclusive panels, persistent
bars, footer clearance at 1280×860 and 960×720, module placement/inspection,
upgrades/recovery, all ship roles, exploration, trade, research, gates, outposts,
material hauling, and save/load. Existing gameplay playthroughs use the new menu
paths. The model suite passes, including the 24,000-trade history soak.

Known warnings remain in untouched model code: static `actor_key()` calls through
instances in mining_fleet.gd and location_save_validation.gd. Editor diagnostics
also retain an existing Control focus warning. No runtime script errors were
reported by the passing verification probes.

Ship-tray verification additionally covers all role icons and commands, remote
region selection without moving the ship/station, native touch selection, a
crowded scrollable tray, camera-adjusted salvage/placement/mining hit tests,
and reconstruction after save/load (`tests/ship_tray_playthrough.gd`).

## Expanded grid and map selection

The build grid is now 17×17 (289 cells), configured by `data/station_grid.json`.
See `docs/station-grid.md` for bounds and save compatibility. Build mode exposes
Fit grid, zoom ±, and four pan buttons at the lower left, above the message bar.
These are camera-only controls with mouse/touch targets; Reset view restores the
original camera. Backgrounds remain viewport-filling when zoomed or panned.

The owned-ship tray is unchanged. Clicking/tapping a ship sprite additionally
calls the exact same `HUD.select_ship(id)` handler as its tile. Both paths open
the existing commands and show a cyan tile border plus a ring on the selected
map ship. The hit target is 44 screen pixels across at any zoom. Coincident ships
at a gate can be cycled by repeated clicks. GUI controls take priority over map
selection. Close/Escape closes the command panel; selection remains highlighted
until another ship is selected, it is decommissioned, or a save is loaded.

`tests/grid_ship_map_playthrough.gd` verifies all five roles via both entry
points, native touch, remote selection, command visibility, footer clearance,
outer-cell construction, mining, outer-depot collection, and save/load. Existing
tray and HUD playthroughs also pass. Runtime probes report no script errors;
existing static-call, local-variable and Control-focus warnings remain.
