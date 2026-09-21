# Typed ship parking

Five dedicated modules are available in Build: Miner Dock, Scout Dock, Trade
Dock, Material Dock and Jump Dock. Each currently costs **25 Materials**, uses
**1 Power**, and holds **2 matching ships**. They contribute no resource storage.
Normal placement, stable structure IDs, demolition, and refunds apply.

Definitions live in `data/modules.json`: `docking.ship_type` selects the match
key and `docking.capacity` is the slot count. Ships declare `dock_type` in
`data/ships.json` (their catalog ID is the fallback). Adding another matching
ship/dock pair requires data only; no role-name branches exist in parking code.
Dock capacity is separate from the existing material-storage `capacity` field.

The legacy **Mining Ship** module remains unchanged: it contains an autonomous
mining unit. Converting it into a parking-only dock would change old colonies'
mining yield and economy. Dedicated docks reuse/generalize that station-mounted
concept without adding autonomous miners or changing existing ship capabilities.

## Rules

`fleet.docking` is a presentation-independent RefCounted model. It observes the
existing model/job signals and uses `fleet.unit_busy()` for all capabilities.
Parking never makes a ship busy and never gates a command, purchase or reward.

- An idle ship keeps its valid slot, or takes the first free matching slot.
- Match requires the same physical region and owner, independent of the viewed
  region. Stable structure IDs identify docks, not their positions.
- Starting a job immediately releases the slot. Waiting ships can take it.
  Completing/cancelling a job attempts parking again. Repeating mining and
  deployed collection (including full-storage waiting) remain active jobs.
- Founding remains its existing instant transaction, with no added delay.
- If no slot exists the ship stays idle/homeless and can still take any legal
  job. Its tray/context shows `Idle · no dock`; the message bar explains missing
  capacity after temporary action messages expire. Purchase reports it directly.
  Material collection's storage-full warning keeps its existing priority.
- Demolition releases reservations without cancelling owned ships' active jobs.
  Idle ships take another local slot if available, otherwise become homeless.
- Remote ships never move Home to park. Remote module construction remains
  unavailable; a gate arrival therefore normally stays homeless for now.

The 2D view animates idle ships toward positions beside their assigned dock.
Return animation is cosmetic: slots reserve immediately and commands remain
available throughout. It introduces no simulated travel time or resource cost.
Tray and map clicks still use the same selection handler and drawn coordinates.
Dock inspection shows occupied/total slots. Existing bars and controls remain.

## Saves and validation

Save version stays **2**. `extensions.docking`, schema 1, adds:

- `ships`: one record per owned ship, with `state` (`working`, `parked`, or
  `homeless`), physical `region`, stable `dock_id`, and zero-based `slot`.
- `usage`: each dock's slot-to-ship map, including empty docks.

Structures themselves use the existing `extensions.world_locations` identity
records and the unchanged core module compatibility projection. No core save
fields or existing costs/yields/timers change. Old saves have no dedicated docks;
missing docking extensions migrate to working or homeless/unparked ships.
Unknown extension metadata is retained.

The isolated save candidate validates assignments against catalog type/capacity,
structure ownership/region, active jobs, unique slots, complete ship coverage,
and usage. Corrupt parking is rejected before mutating the live colony.
Reservations persist without repacking valid occupied slots.

## Verification

- `tests/docking_runner.gd`: parking, overflow, job release/waiter assignment,
  exact mining outcome, return after survey/trade/collection cancellation,
  teleport departure/arrival, founding, remote/owner matching, data-only new
  types, demolition/refund, migration, round-trips and atomic corrupt-state rejection.
- `tests/docking_playthrough.gd`: real Build/purchase/map/tray commands, animated
  parking, mouse/native touch selection, bottom messages, occupancy inspection,
  dispatch, all five dock catalog entries, demolition and actual save/load.
- Existing 341-check model suite and owned-ship tray playthrough remain passing.

Parking movement now uses the shared view-only `ShipMotion` controller and
`data/ship_motion.json` speed settings; the earlier parking-specific 400 px/s
animation has been replaced. Reservation/parking model rules are unchanged.
