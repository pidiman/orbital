# Refinery buffers and tasked Haulers

Refineries now put completed output into their own **30-unit shared buffer**, configured by `output_buffer_capacity` in `data/modules.json`. Inputs, recipe tier rates and output quantities are unchanged. A batch pauses without spending inputs or advancing its timer if its entire output will not fit; the HUD says **buffer full · paused**. Main storage is no longer credited by production. Recipe switching preserves all buffered resource types. Inspect shows buffer contents/capacity and assigned Hauler count.

Buy **Hauler** in Ships: **50 Materials, 2 Power**. Its `hauling` capability in `data/ships.json` sets **batch_size 5** and **travel_seconds 3** per leg. Select its tray tile or map sprite, choose **Assign refinery**, then click a Home Refinery. ESC cancels the pending selection. Assignment repeats until stopped; empty buffers leave it waiting at that Refinery. Each trip carries up to five total units, including partial loads and mixed recipe output. No outpost hauling is added.

Delivery uses the existing Home resource authorities, pausing with **Hauler waiting — storage full** when Materials or Tech reaches station capacity (the previous Refinery-only Tech ceiling). Partial receipts retain the rest of the cargo. Spending resources or adding capacity resumes delivery. A normal Stop finishes any carried delivery first, including waiting for space, then releases the assignment and returns to an available Space Dock; idle Haulers use the same universal docking rules as every other role. Visual motion uses ShipMotion; no special sprite movement loop.

Demolishing a Refinery recovers its buffered goods with the existing above-capacity recovery convention; assigned ships with cargo finish delivery, empty ones release. Decommissioning a loaded Hauler similarly recovers cargo so goods are not destroyed. These recovery actions do not change routine delivery capacity checks.

Save v2 remains intact:
- Per-structure buffer: `extensions.world_locations.structures[stable_id].state.output_buffer` (resource → amount).
- Hauler assignments/cargo/phase/timer/waiting/destination: `extensions.refinery_hauling` schema 1.
- Space Dock reservations remain in `extensions.docking`.

Old saves have no hauling jobs and empty refinery buffers; existing main inventory is untouched. Candidate validation checks buffer capacities/resources, ship capability, exclusive assignments, Home location, stable refinery references, cargo capacity and travel state before applying anything. Missing demolished sources are allowed only while cargo is delivering.

Tests: `hauler_playthrough.gd` covers production blocking, UI assignment, five-unit collection, repeat delivery, both recipes, Materials/Tech storage waiting, resume, Space Dock parking, stop/cargo recovery, demolition, disk/in-flight round trips, invalid-save atomicity and old-field defaults. Recipe, universal-dock and mining regressions cover retained behavior.
