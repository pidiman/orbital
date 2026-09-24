# AGENTS.md — Orbital

2D space colony builder in low Earth orbit. Summer Engine (Godot 4-compatible), GDScript.
Core loop: build station → collect → mine → refine → research → explore regions → trade → defend.

## Hard constraints
- Stay in 2D. No Node3D. Keep the code 3D-ready:
  - Game logic lives in RefCounted models (no Node2D dependency).
  - Positions are continuous Vector2; grid snapping only in the input/placement layer.
- Extend existing systems, don't rewrite or duplicate them. Reuse before adding.
- Everything tunable is data-driven (data/*.json): costs, tiers, HP, ranges, spawn rates, timings.
- Keep every existing feature working. No unrequested gameplay/economy changes.
- PRESENTATION-ONLY tasks must not touch logic, timers, economy or save format.

## Project layout (key files)
- data/modules.json, data/ships.json, data/regions.json, data/technologies.json,
  data/refinery_recipes.json, data/threats.json, data/camera_controls.json
- scripts/save_store.gd — save/load, migration, validation
- scripts/ship_motion.gd — ship movement, rotation, flames, beams
- scripts/station_board.gd — station grid drawing, tubes
- scripts/threat_field.gd — turrets, missiles, asteroid threats (Node2D, known debt)
- scripts/hud.gd — top bar, ship tray, panels, FPS counter
- tests/test_model.gd, tests/save_key_roundtrip.gd

## Domain model (current truth)
- Regions only: Home (Earth), Venus, Mars, Pluto. Old sector system is removed — do not reintroduce.
- Location model: every ship/structure has a stable identity + current region.
  Ships operate in the region where they physically are. No "Home-only" guards.
- Resources credit LOCAL storage of the region (Home storage or that outpost's storage).
- Outposts: own grid, own storage, own power. Buildable there: Space Dock, Teleport Gate,
  Storage, Solar Panel (+ defense).
- Ships are bought at a Space Depot (required), then fly to a free Space Dock slot.
  No free dock → ship stays near the Depot as "homeless".
- Universal Space Dock (T1=1 … T4=4 slots). Old per-type docks migrate to Space Dock.
- Gates: travel requires gates on both ends. Jump Ship can pioneer-jump one-way to a
  discovered gateless region and build a gate there.
- Automatic ships (Start/Stop toggle, no manual targeting): Material Ship, Miner,
  Xeno Miner, Repair Ship, Cargo Ship (route-based). Multiple auto ships must not claim
  the same target.
- Ship tiers: Material Ship, Miner, Xeno Miner, Hauler have T1→T2 (2x yield/capacity).
  Other ships have no tiers.
- Module HP: asteroid damage scales with asteroid size; module works while HP > 0,
  inactive at HP = 0, never destroyed. Upgrade restores HP to full. Repair Ship heals
  partial damage automatically.
- Defense: Defense Turret and Missile Silo use guaranteed hits on a locked target ID +
  travel time (never physics collision). Projectiles spawn from the barrel tip.

## Save safety (always apply)
- Save format is v2 JSON. New persisted state goes under `extensions`.
- All persisted dictionary keys must be strings (IDs as "12", grid cells as "x,y").
  Parse them back to int/Vector2 on load.
- Never persist derived/transient data: placement caches, connectivity, tube masks,
  visuals, rotation, beam state.
- Old saves must load with sensible defaults for any new field.
- Order on load: migrate → install canonical locations → recompute derived values →
  validate. Never validate raw legacy data before migration.
- Legacy saves use tolerant mode; current saves stay strictly validated.
- Unknown/invalid entries: skip with a path-specific warning, never abort the whole load.
- When adding or changing persisted state, extend `tests/save_key_roundtrip.gd`
  (save → load → save → strict reload) and run it before finishing.

## Performance rules (always apply)
- Target: ~120 FPS on a fresh game; no visible hitches on click/placement.
- No per-frame recalculation of things that only change on events: placement cells,
  connectivity BFS, tube tiling, panel height, repair scans, dock reconciliation.
- Invalidate caches on SPECIFIC events (module/tube add/remove, build tool switch,
  region change). Never hook invalidation to broad `model.changed`.
- One user action = at most one rebuild. Coalesce duplicate signals.
- Placement updates are incremental (only the neighborhood around the changed cell).
- Idle/parked/docked ships skip per-frame visual work (rotation, flame, beam).
- Signals: don't emit `changed` when nothing changed (e.g. empty cargo ticks).
- HUD/panels coalesce refresh signals into one deferred refresh.
- Static views (stars, planets, debris, regions) redraw only on camera/data change.
- Respect caps in data/threats.json (asteroids, projectiles, missiles).
- Autosave is debounced; no disk I/O on the placement frame.
- Remove all temporary diagnostic logging/probes before finishing.

## Known pitfalls (already fixed — don't reintroduce)
- Arrival checks use a radius (`distance_to(target) <= arrival_distance`), never
  `is_equal_approx` — eased movement never hits the exact position.
- Mining/repair beam is visible ONLY in EXTRACTING/REPAIRING state after arrival.
  Hidden while flying to/from target, idle, parked, waiting.
- Panels auto-fit height to CURRENT content; re-measure after every content/tab switch.
  ScrollContainer must get content min-height (zero height = invisible content).
- Deselect must actually hide the visual frame, not only clear state.
- Every preload() path must point to an existing file.
- Fresh state (New Game) has only Home station — guard lookups into outpost catalogs.

## UI conventions
- Top bar row 1: ORBITAL, pause, buttons (Build, Demolish, Ships, Research, Gate,
  Outposts, Trade, Menu), icon-only resources. Must fit on one row.
- Top bar row 2: compact ship pills (icon + short name + status color + region planet icon)
  and icon status indicators (miners, refineries, colony level, modules, progress bar).
- Menu dropdown: New game, Save, Load, Settings.
- Selection (modules and ships): 1st ESC / close = panel closes, frame stays;
  2nd ESC = full deselect. Click on empty space = close panel AND deselect.
- Show module HP only when damaged (< 100%).
- Settings are client preferences (not in gameplay save): edge scrolling (off),
  zoom controls (on), ship trajectories (off), music + volume, Show FPS.
- F9 debug panel (DEBUG_MODE only): region-aware resource grants, asteroid toggle,
  spawn asteroid now, Xenocrystal tuning (amount, lifetime).
- Keep UI compact; the player values screen space.

## Visual conventions
- Dark space theme, clean flat shapes, colored accents.
- Colors: Materials amber, Minerals violet, Xenocrystals cyan, Tech teal.
  Beams: Miner amber, Xeno Miner cyan, Repair green.
- Ships rotate smoothly to face travel direction and show an engine flame only while moving.
- Mining ships stop about one ship-length before the target.
- Cargo Ship is ~3x size (purple container transport, dual engines).
- No boxes/frames drawn around ships except the selection highlight.
- Connector tube visuals: two redesign attempts failed and were reverted.
  Don't change tube visuals unless explicitly asked; if asked, work in small steps.

## Workflow
- A git commit exists before each task. Keep changes scoped to the request.
- Diagnose before fixing when a bug persists: log state transitions, report the root
  cause with evidence, then fix.
- Before finishing, run:
  - tests/test_model.gd
  - tests/save_key_roundtrip.gd
  - tests/beam_state_test.gd
  - headless startup (no parser errors)
  - git diff --check
- Report: root cause (for bugs), what changed, data values chosen, how to test.

## Known tech debt
- threat_field.gd is Node2D, not RefCounted → outposts don't defend themselves when not viewed.
- Refinery recipe timings live in two places (modules.json and refinery_recipes.json).
- Stale sector tests; missing automated tests for turret/threat/HP/cargo.
- Before release: DEBUG_MODE off, Show FPS default off.
