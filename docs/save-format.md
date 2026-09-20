# Orbital checkpoints — JSON version 2

## Location and controls

The single latest checkpoint is `user://orbital-save.json`. In this native Summer installation, that resolves to:

`/Users/pidiman/Library/Application Support/Godot/app_userdata/Orbital/orbital-save.json`

Use **Save** and **Load** in the resource header. Save and autosave share this latest-checkpoint slot; Load restores its most recent contents, not a separate historical manual save. Startup automatically resumes it when present.

Autosave is requested after module build/demolition/upgrade, ship purchase/sale, mission dispatch/completion, survey launch and discovery. Requests are coalesced until the end of the frame, after model mutations finish. A periodic checkpoint every 10 simulation seconds covers salvage and ongoing drift/timers. Normal close/scene teardown saves the last state. Forced termination can only recover the last successful checkpoint; there is no offline progress calculation.

## Envelope

```json
{
  "format": "orbital.save",
  "version": 2,
  "min_reader_version": 2,
  "state": {
    "station": {},
    "fleet": {},
    "supply": {}
  },
  "extensions": {"alien_trade": {"schema_version": 1}}
}
```

`save_store.gd` owns explicit persisted-field allowlists; it does not serialize nodes, scripts, resources, or arbitrary engine objects. The three state sections are canonical snapshots of the RefCounted models.

| Section | Saved state |
| --- | --- |
| station | Continuous module world positions and kinds; tiers; ship IDs/types; next ship ID; Materials, Minerals, capacity, Power output/use (balance is their difference), colony level; refinery progress; tick count, fractional tick phase and total refined |
| fleet | All live asteroids, remaining ore, reservations and sector provenance; Miner and legacy dock jobs with target/timer/yield/repeat; Scout jobs with destination/travel timer; complete sector discovery records; next discovery ID and total mined |
| extensions.alien_trade | Faction identities/standing/contact flags; discovered alien contacts; Tech/Xenocrystal inventory; active trade jobs and prepaid cargo/rewards/timers; completed/cancelled trade history; processed anomalies and transaction ID allocator |
| supply | Debris amounts/positions/velocities, home-asteroid positions/drift, all ID counters, supply rules, elapsed time, partial fixed step, spawn timers, RNG seed and state |

Discovered asteroid marker positions are now logical model coordinates too. The view projects them after load, rather than picking a new marker location. ResourceClock retains no independent gameplay timer: its fractional phase lives in StationModel.

## Lossless JSON representation

- Ordinary records use JSON objects/arrays and strings/booleans/numbers.
- Non-string dictionary keys use `{"$entries":[{"key":{"type":"id","value":"1"},"value":...}]}`. Module keys use `type: "position"` and a Vector2 value. This preserves integer ship IDs versus continuous module positions, including mixed mining-job keys and dictionary order.
- Vector2 uses `{"$vector2":[x,y]}` with lossless encoded float components.
- Simulation floating-point values use `{"$float64":"<16 hexadecimal digits>"}`: eight bytes written/read with PackedByteArray encode_double/decode_double. This avoids observed decimal-parser round-off in supply speeds and fractional clocks.
- RNG seed/state are signed 64-bit decimal **strings**, never JSON numbers.
- Snapshot comparison normalizes ordinary JSON numbers to JSON's single numeric category. Typed engine integer fields and map keys are restored explicitly; exact simulation floats and RNG state retain their bits.

Do not edit these tags casually. Unknown or malformed tags inside required model fields are rejected.

## Versions and future phases

`migrate()` contains a tested version-1 → version-2 migration step. The v1 fixture lacks `station.tick_elapsed` and `extensions`; migration supplies `0.0` and `{}`. This is the migration scaffold for future schema changes, not a claim that an earlier released save system existed. Add sequential migration steps for future breaking revisions.

Phase 4 uses `extensions.alien_trade`, with `schema_version: 1` and the same lossless codec as the core. The save envelope stays v2. Absence of this extension is a supported old save: neutral factions and empty trade state are created, sector anomaly content is enriched from `data/aliens.json`, and previously revealed anomalies establish contacts or grant their one-time research reward. A processed-anomaly ledger prevents duplicate rewards on subsequent loads. A present malformed extension or unsupported extension schema rejects the entire load. Unknown extension fields are retained. Adding factions/goods to the catalog supplies missing defaults without resetting existing standing or inventory. Extensions, unknown envelope keys, unknown state sections and optional section fields are retained when saving again. Only known fields are decoded/validated. A newer document is accepted if it declares `min_reader_version <= 2` and retains the required compatible core; its version is not downgraded. New required semantics should raise `min_reader_version` and add a migration in the newer application.

Module/ship catalogs remain external data-driven definitions, referenced by kind. Missing definitions or inconsistent derived Power/capacity/level reject load rather than silently changing the colony. Migration for future balance changes or removed content is deferred. Supply rules are saved with the supply snapshot to preserve exact continuation.

## Reliability

Writes go to a same-directory `.tmp`, flush/close, then rename over the checkpoint. A failed write/rename preserves the previous checkpoint. Loads parse and validate the complete state graph before applying it to the existing models. Checks include required types, finite positions/timers, resource quantities, available definitions/tiers, unique sector IDs, valid mining/survey references/reservations, supply timing and ID counters. Core rewards/build actions are never replayed. The one-time additive anomaly upgrade described above applies only to newly introduced anomaly content. Trade escrow is restored without charging again; completed transactions cannot pay twice. Cross-role double bookings, invalid cargo, orphaned contacts and malformed history are rejected before mutation.

Malformed JSON, incompatible versions and invalid state leave the running session intact. If an existing file cannot load, autosave pauses so it cannot overwrite the file with a fresh colony. An explicit successful Save replaces that checkpoint and resumes autosave; a successful Load also resumes it.

## Covered and deferred

Covered: all current economic and mission state above, exact timer/supply continuation, automatic startup resume, atomic writes and graceful-exit saving. Gameplay remains 2D; the Earth script and active scene are unchanged.

Not persisted: transient hover/build selections, selected tabs/open panels, floating notifications, and decorative animation phase. These reset when the model is restored. Deferred: multiple slots, cloud sync, historical backups, offline progress, and native-file recovery after arbitrary disk damage. Native Summer persistence is verified; browser storage durability still needs testing with an HTML5 export.

## Verification

`tests/persistence_checks.gd` runs within the existing headless model suite. It verifies exact canonical save→JSON file→load equality with simultaneous Miner, dock, refinery and survey work; fractional positions/tiers; resources and level; 64-bit RNG; identical future evolution; migrations; preserved compatible future data; atomic rejection of corrupt/orphaned state; autosave and missing files. The combined suite passes 168/168 checks, including 22 core persistence checks and 40 alien/trade checks.

`tests/persistence_playthrough.gd` presses real Save/Load buttons, checks build/discovery autosaves, restores active jobs and readouts, tears down the scene and constructs a fresh session through the normal startup loader, resumes jobs to completion, and verifies graceful-exit saving: 15/15 checks. Existing MVP, mining, ships/upgrades/positions, exploration and recovery playthroughs also pass (88 checks). Disposable verification instances disable the player slot by default; persistence probes explicitly use and clean up isolated test files.

Phase 4 adds `tests/trade_playthrough.gd`: 21 live checks for survey/contact discovery, paid travel, duplicate-click protection, standing/goods/history UI, autosave, active and completed trade Save/Load, and composed hybrid commands. The six existing playthroughs still pass (103 checks). See [Phase 4](phase4-trade.md).

### Material collection (v2 additive extension)

`extensions.material_collection` has `schema_version: 1`, `jobs` keyed by ship ID,
and `depots` keyed by continuous module position, using the existing tagged map/vector encoding.
Jobs save Home assignment, logical position, debris target, depot destination, cargo,
waiting flag and status. Depots save their cumulative delivered material count; their
installed module, tier and economy remain in the existing station fields.
Missing extensions default to idle ships and zero delivered counts. Validation rejects
invalid cargo, foreign-region assignments, duplicate reservations and overlapping fleet
missions before committing any state. Unknown extension fields remain preserved.

### Research and gate transport (v2 additive extensions)

`extensions.research` schema 1 stores `researched` (technology IDs mapped to true)
and `labs` (continuous module positions mapped to completion counters).
`extensions.gate_transport` schema 1 stores `gates` (module positions and launch
counters), `locations` (ship IDs and region IDs), and `jobs` (ship IDs mapped to
gate origin, Home origin region, destination, remaining/duration ticks and paid
cost escrow). Absent ship locations mean Home. Installed modules continue using
the existing station module map; multi-cell occupancy is derived from catalog
footprints rather than duplicated into save data.

Missing extensions mean no researched technologies and no relocated/in-transit
ships. Existing labs/gates derive their initial counters from installed modules;
a locked gate without its technology is rejected. Unknown extension metadata is
preserved. Research prerequisites, module footprint bounds/overlap, state references,
discovered adjacent routes, cargo costs, timers and cross-role ship occupancy are
validated before changing the live models. Gate demolition may leave an already
launched transit job: that job still completes at its saved destination.
