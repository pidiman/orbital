# HUD layout

The toolbar opens Build, Ships, Research, Gate/Travel, Outposts/Regions, or
Trade/Contacts. Only one panel is visible. Click/tap the active toolbar button,
use the fixed Close button, or press Escape to close it. Panels scroll within
the space above the message bar. Buttons have at least 44 logical pixels of
height; the toolbar wraps on narrow viewports.

Power, Materials, Minerals, Tech, Xenocrystals, Save/Load, and the viewed-region
indicator remain visible. The region indicator describes the view, not a ship's
physical location. Gate/Travel lists ship locations and transit status.

- Build contains the complete module catalog, including the legacy Mining Ship
  module. Selecting a module closes the panel for placement. Clicking a built
  module opens its inspection, upgrade, and demolition controls in Build.
- Ships contains all five purchase roles, capability commands, and decommission.
  Assigning a Miner closes the panel so the player can click an asteroid.
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
