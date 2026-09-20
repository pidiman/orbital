# Orbital

A focused top-down orbital colony builder made in Summer Engine. Start with one habitat above Earth, salvage debris, and assemble a connected station.

## Run

Open `project.godot` in Summer Engine and press Play, or run `summer run /path/to/Orbital`. The main scene is `orbital.tscn`.

- Click/tap amber debris to collect Materials.
- Select any module and click/tap an edge-connected grid cell.
- Solar panels provide the Power budget needed for more modules.
- Storage raises the material capacity. A partially collected fragment retains its remainder.
- Use **Inspect / cancel command** to clear the build tool. Right-click also cancels.
- Reach 9 modules for level 3 and the **Colony established** milestone. Continue building afterward.

The HUD explains rejected builds; no resources are spent on invalid placement. Debris remains collectible while a build tool is selected. Mouse-first landscape layout; touch is mapped to mouse input. No keyboard is required. Sessions are not saved in this MVP.

## Files

- `GameSoul.md`: game concept, scope, economy and deferred features.
- `data/modules.json`: prices, power, storage and descriptions.
- `scripts/station_model.gd`: placement validation, resource transactions and progression signals.
- `scripts/resource_clock.gd`: one-second simulation tick.
- `scripts/mining_fleet.gd`: ship availability, asteroid reservations and timed extraction.
- `scripts/asteroid_field.gd`: periodically arriving violet asteroids, dispatch input and mission visuals.
- `scripts/debris_field.gd`: bounded drifting salvage and collection.
- `scripts/station_board.gd`: grid, previews and station rendering.
- `scripts/module_art.gd`, `scripts/space_backdrop.gd`: original procedural 2D art.
- `scripts/hud.gd`: resource HUD, build buttons and feedback.
- `scripts/main.gd`: scene composition and event wiring.

Mining is implemented. Exploration, alien trade and event systems remain deferred.

## Verification

Model tests:

```sh
"/path/to/Summer" --headless --path "$PWD" --script res://tests/test_model.gd
```

The Summer MCP `RunVerification` operation accepts the contents of `tests/playthrough.gd` as `probe_source`. It clicks real GUI buttons and world positions, salvages materials, verifies placement failures, builds all module types and reaches the goal. Its 5× clock is for QA only; the game runs at normal speed.

Evidence: `docs/playthrough-results.json` records 10 passing baseline checks with zero errors. `docs/mining-playthrough-results.json` records 18 passing mining-loop checks and frame-stamped resource changes. `docs/mining-in-progress.jpg` and `docs/refining-complete.jpg` show the new loop. `docs/colony.jpg` shows the established colony. Native desktop runtime tested; browser and real touch hardware testing remain pending.

## HTML5 target — currently blocked

This machine has Summer `4.7.2.stable.mono.custom_build.eef8b5522` and no installed export templates. The Mono installation does not provide the supported Web export path, so no HTML5 build or export preset is claimed here.

Export requires a compatible **non-Mono Summer build environment with matching Web templates**. Use the Compatibility renderer (already selected), single-threaded Web export, include `data/*.json` in the export resource filter, and exclude tests/docs. Test through an HTTP server in a browser after generating the real `.html`, `.js`, `.wasm` and `.pck` files. Do not treat a PCK by itself as a browser build.

All gameplay uses GDScript and standard 2D APIs; no C# or native extensions are required.

## Phase 1: Mining

1. Build solar capacity, then a **Mining Ship** (45 Materials / 2 Power).
2. Click a **large violet asteroid**. An idle ship departs and a countdown appears; eight resource ticks later it delivers up to 18 Minerals and is ready for another mission. The asteroid is reserved while the ship works. Clicking it twice never launches duplicate missions.
3. Build a **Refinery** (40 Materials / 3 Power). Every three resource ticks each refinery consumes 2 Minerals and produces 6 Materials automatically. Conversion pauses when there is too little input or insufficient material storage. Build Storage or spend Materials to resume it.
4. Watch Minerals in the top HUD and idle ships/refinery status in the build panel. Mining and salvage work even while a build tool is selected.

Asteroids enter the outer sector lanes every 12 seconds (up to three at once). Unclaimed asteroids drift away; claimed ones are held until extraction finishes. Minerals are currently uncapped. More ships allow concurrent missions; more refineries process ore faster.

Module prices, power use, mission duration/payload and refinery recipes live in `data/modules.json`. The Modules tab iterates the module catalog rather than a fixed list of IDs; the separate Ships tab reads the ship catalog. New definitions with `mining` or `conversion` capabilities use the same systems; a new visual design can be added to `ModuleArt` separately.

Mining model tests:

```sh
"/path/to/Summer" --headless --path "$PWD" --script res://tests/test_mining.gd
```

Use `tests/mining_playthrough.gd` with Summer `RunVerification` for the mouse-driven end-to-end test. It earns Materials through actual debris clicks, builds both modules, dispatches to a naturally occurring asteroid, waits for Minerals, then checks the refinery's exact input/output without clicking more debris. It also verifies duplicate-dispatch protection, periodic spawning, repeat dispatch and HUD values. The test accelerates the clock to 3×; ordinary play remains 1×.

## Phase 2: Ships and upgrades

**Ships** is a separate build-menu tab. Buying a ship spends Materials and reserves Power immediately; it does not place a grid module or increase colony level.

- **Miner:** 45 Materials / 2 Power. Press its **Assign asteroid** command, then click a violet asteroid. It mines 18 Minerals every eight resource ticks and repeats automatically until depletion. Partial final loads are credited exactly, then the ship becomes idle. Other ships cannot claim the reserved target.
- **Scout:** 35 Materials / 1 Power. Press **Survey sector**. After five ticks it reveals the next adjacent sector placeholder and a rich 54-Mineral asteroid. Two adjacent sectors are available in this phase; each is revealed once. This is a survey placeholder, not a travel/exploration system.
- The Phase 1 **Mining Ship** module remains under **Modules** as the original one-shot mining dock. It can coexist with independent ships. The original click-an-asteroid shortcut still dispatches an available mining unit.

Press **Inspect / cancel command**, then click an existing station module to open **Upgrade**. T1/T2 badges appear on the board. The inspector shows current stats, the next improvement and both costs. Failed or repeated upgrades spend nothing.

| Module | Tier 2 improvement | Materials | Minerals |
| --- | --- | ---: | ---: |
| Habitat | +25 material capacity | 20 | 6 |
| Solar Panel | Generation 6 → 10 | 30 | 8 |
| Storage | Bonus capacity 75 → 150 | 25 | 6 |
| Refinery | Cycle 3s → 2s | 35 | 10 |

Upgrade power use remains unchanged. Existing construction prices and colony thresholds remain unchanged.

Data lives in `data/modules.json` (ordered `upgrades` arrays), `data/ships.json` (ship prices, power and capabilities), and `data/sectors.json` (survey placeholders/deposits). Module kinds remain separate from per-cell tier state; `definition_at` computes the effective stats. Ship IDs and job state are separate from the station grid. Future tiers are appended to data, and future Miner/Scout variants reuse the same capability systems.

Validation: `tests/test_ships_upgrades.gd` passes 38 model checks; `tests/ships_upgrades_playthrough.gd` passes 21 mouse-driven checks, including two automatic mining cycles, Scout discovery, exact upgrade costs, higher Solar output and a completely 2D runtime tree. Existing economy, 29-check mining model, 10-check MVP playthrough and 18-check Phase 1 playthrough also pass. Evidence is saved in `docs/ships-upgrades-results.json`, `docs/miner-assigned.jpg`, `docs/upgrade-before.jpg` and `docs/upgrade-after.jpg`.

The Earth source `scripts/space_backdrop.gd` is unchanged (SHA256 `8e0ad4e005111c623d9e6a03afc1eb1fe6cb1c34969e835b28325b1ce386669f`). No 3D nodes were added. A transient Summer UI-focus warning appeared during editor launch; the runtime playthroughs reported no errors. The previously documented HTML5 export prerequisite is unchanged.

### Continuous positions

Module positions now use continuous `Vector2` world coordinates. Grid snapping is confined to the board/input layer and remains enabled by default. See [positioning architecture and verification](docs/positioning.md).

## Phase 3 — Nearby exploration

Use **Sector map / Exploration** beneath the build tabs. Select a destination and Scout, then **Send Scout**. The map shows unexplored, exploring (countdown/progress), and revealed states. Scouts return to idle after arrival. Select a Miner and **Mine deposit** in a revealed sector; the existing automatic mining loop credits Minerals until depletion. The Phase 2 quick-survey command remains available.

| Sector | Travel (standard Scout) | Discovery |
| --- | --- | --- |
| Dawn arc | 5 seconds | 54-Mineral asteroid |
| Twilight arc | 7 seconds | 54-Mineral asteroid |
| Echo pocket | 6 seconds | Anomaly report; future-content placeholder |
| Quiet reach | 4 seconds | Empty |

`data/sectors.json` defines IDs, home routes, travel times and typed contents. `data/ships.json` defines Scout travel speed; module definitions stay unchanged. Discovery targets are created by the fleet model, retain sector provenance and remain mineable until depleted. Home-orbit rocks still spawn/drift independently. The sector map is a separate 2D Control script; station coordinates and Earth rendering are unchanged.

Verification: 72/72 combined model checks (including exploration, ships/upgrades and continuous positions), 29/29 Phase 1 model checks, and the station economy regression passed. Mouse-driven playthroughs: exploration 20/20, MVP 10/10, mining 18/18, ships/upgrades/positioning 25/25. Verified travel delay, hidden contents, discovery, Miner assignment, 18-Mineral payout, continued mining, anomaly/empty results, concurrency, duplicate rejection and depletion. Evidence: `docs/phase3-*-results.json` and `docs/exploration-*.jpg`.

## Recovery and simulation-owned supply

Inspect a module → **Demolish**, or Ships → **Decommission**, for a 50% Materials refund and released power/position. Busy missions are cancelled safely. The original habitat is protected; generator removal cannot cause a power deficit. Stock and refunds survive removal of Storage, even above capacity.

Salvage and home-asteroid spawning/lifecycle now run in the RefCounted `SectorSupply`, independently of rendering. Tune `data/supply.json` and `data/decommission.json`; definitions may override refund ratios. See [health-fix architecture and verification](docs/health-fixes.md). Run `tests/test_ships_upgrades.gd` for the combined model suite, including renderer-free supply and recovery checks.

## Save / Load

The resource header now has **Save** and **Load**. Both manual and automatic saves use the latest checkpoint at `user://orbital-save.json`; startup resumes it. Autosaves follow builds, decommissioning, upgrades and mission/discovery changes, every 10 seconds, and on graceful exit.

All current model state, jobs, fractional clocks and supply RNG are restored. The JSON v2 envelope includes migrations and preserved `extensions` for future relations/trade data. See [save format, native location, compatibility and limitations](docs/save-format.md).
