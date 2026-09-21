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

A batch pauses without spending inputs or losing progress if ingredients are insufficient or the full output won't fit. `output_capacity: "station"` checks the selected output resource against station capacity. Materials retains its existing cap. Because trade Tech was uncapped, this adds a **Refinery-only Tech production ceiling** equal to station capacity; it does not cap trade receipts, change storage rules elsewhere, or discard above-capacity stock. Spending Tech or raising capacity resumes production. Tech is credited through the existing trade-goods authority.

Persistence stays v2: `extensions.world_locations.structures[stable_id].state.refinery_recipe` stores the selected ID. Progress uses the existing canonical `refinery_progress` and compatible legacy projection. Missing recipe fields mean the module's default; invalid IDs fail validation before changing live state. Demolishing a Refinery removes its state with the structure. No recipe is keyed by position in the saved extension.

`tests/refinery_recipes_playthrough.gd` drives two Refineries with different recipes, checks exact resource deltas, independent timers, full-output pause/resume, missing ingredients, switching, Tech tier rates, inspect UI, save round-trip, old defaults and atomic invalid-save rejection. Existing tier-upgrade UI/dock regressions also pass.
