# Per-Refinery recipes

Inspect an individual Refinery and use its recipe dropdown. Each structure has an independent selected recipe and progress counter. New and old-save Refineries default to Minerals → Materials. Switching recipes resets only that Refinery's unfinished timer; ingredients are charged at batch completion, never on selection.

Definitions live in `data/refinery_recipes.json`; `data/modules.json` declares the Refinery's allowed IDs and default. The original recipe resolves the existing tier-specific `conversion` fields, preserving every old amount and duration. The Tech recipe supplies its own data-driven tier durations.

| Tier | Minerals → Materials (unchanged) | Materials → Tech |
| --- | --- | --- |
| 1 | 2 → 6 every 3s | 20 → 1 every 20s |
| 2 | 2 → 6 every 2s | 20 → 1 every 18s |
| 3 | 2 → 6 every 1s | 20 → 1 every 16s |
| 4 | 4 → 12 every 1s | 20 → 1 every 14s |
| 5 | 6 → 18 every 1s | 20 → 1 every 12s |

A batch now pauses against its local output buffer rather than main storage. Recipe inputs, yields and tier durations above remain unchanged; see `docs/refinery-hauling.md` for the 30-unit buffer and assigned Hauler delivery rules. Recipe switches preserve already buffered goods. Tech main-storage capacity is enforced at delivery.

Persistence stays v2: `extensions.world_locations.structures[stable_id].state.refinery_recipe` stores the selected ID. Progress uses the existing canonical `refinery_progress` and compatible legacy projection. Missing recipe fields mean the module's default; invalid IDs fail validation before changing live state. Demolishing a Refinery removes its state with the structure. No recipe is keyed by position in the saved extension.

`tests/refinery_recipes_playthrough.gd` drives two Refineries with different recipes, checks exact resource deltas, independent timers, full-output pause/resume, missing ingredients, switching, Tech tier rates, inspect UI, save round-trip, old defaults and atomic invalid-save rejection. Existing tier-upgrade UI/dock regressions also pass.


## Manual Run / Stop

Each Refinery detail panel has a Stop production / Run production button. Stopping freezes its batch progress without consuming inputs or producing output. Existing buffered goods remain available to Haulers, and installed Power usage is unchanged. Running resumes the saved progress, subject to the existing input and buffer-space checks. The explicit `Stopped` status is distinct from `buffer full · paused`.

The optional boolean `refinery_running` lives in each structure's state under the v2 `extensions.world_locations` graph. Missing fields default to true for new and old Refineries; invalid non-boolean values are rejected before applying a save.

Recipe popup fix: routine HUD refresh previously hid the OptionButton and cleared/rebuilt its options, dismissing its popup. The selector now remains visible for a Refinery and rebuilds only when its recipe choices change. Live stats continue refreshing while the popup is open.
