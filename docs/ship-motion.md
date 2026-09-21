# Visual ship motion

`data/ship_motion.json` controls the view only. Restart to apply edits:

- `speed`: **260** view-space pixels/second, the default maximum travel speed.
- `ship_speeds`: optional catalog-ID overrides, e.g. `{"miner": 320, "trader": 220}`.
- `follow_rate`: **14** per second. Exponential easing smooths small quantized
  target changes (including the material supply model's 20 Hz updates).
- `max_frame_delta`: **0.05** seconds. A rendering hitch cannot cause a large
  one-frame jump; visual travel can lag rather than moving the simulation.
- `return_fraction`: **0.25**. The final quarter of a timed mission aims toward
  its visual departure point. This reads timers; it never changes them.
- `mission_markers`: cosmetic screen-area destinations for trade, sector Scout
  and regional Scout missions, which have no spatial destination in their models.

Keep speed, follow rate and maximum frame delta positive; return fraction should
be between 0 and 1. Marker coordinates are normalized within the world area.

`ShipMotion` is a Node in the 2D view. Each frame it updates one bounded cache
entry per ship or legacy module-owned Miner. Large distances use steady maximum
speed; near targets ease smoothly. Removed actors are pruned. Model projections
are sampled once per update, keeping the movement update linear in actor count.

All drawings, map hit tests, selection rings and Camera2D focus read the same
positions. Owned/legacy mining, dock return, material hauling, trade, Scout
missions and gate approach share this path. Mining no longer maps whole-second
remaining timers directly onto sprite positions. A depleted asteroid or completed
job retargets the existing sprite instead of snapping it to its idle/dock point.
Legacy module miners also finish their cosmetic return after the job disappears.

The controller does not advance clocks, call work commands, write model fields,
change capacity reservations, or serialize anything. Timed rewards and arrivals
can precede the visual sprite reaching its destination, especially with very low
visual speeds. That is intentional: movement never gates gameplay.

Loading resets interpolation to a valid point for the restored job phase. View
region changes, physical teleport arrivals and resizing similarly discard stale
coordinates. Teleportation remains a region transition, not simulated flight
between unrelated map coordinate systems; approach to the departure gate is
smooth. No v2 schema or extension changes are needed.

Verification: `tests/ship_motion_playthrough.gd` drives a real Miner assignment,
checks movement on successive render frames between model ticks, per-frame speed
bounds for each movement path, snapshot equality during visual updates, exact
mining completion/yield, mid-job disk save/load, easing of small target updates,
legacy miners and cache cleanup. Existing tray and docking playthroughs verify
commands and selection remain connected to the drawn sprite.
