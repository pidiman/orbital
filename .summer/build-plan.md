# Orbital implementation plan

**Goal:** A playable, focused orbital station builder with salvage, connected placement and resource feedback.
**Architecture:** JSON module catalog feeds a pure station model. A one-second clock refreshes resource aggregates. Separate board, debris, HUD and presentation scripts communicate through model signals.
**Tech stack:** Summer Engine, GDScript, Compatibility renderer, procedural 2D vector art.

## Tasks in order
- [x] Create data/modules.json and scripts/station_model.gd. Check initial economy, transactional placement failures, solar bootstrap, storage cap and level thresholds with tests/test_model.gd.
- [x] Create scripts/resource_clock.gd and scripts/debris_field.gd. Debris drifts, spawns at bounded intervals and awards materials once per collected amount.
- [x] Create scripts/station_board.gd and scripts/space_backdrop.gd. Render connected module silhouettes, placement grid, stateful preview and Earth limb.
- [x] Create scripts/hud.gd and scripts/main.gd. Build native Control buttons and labels, connect all resource feedback and colony milestone progression.
- [x] Author main.tscn through the live Summer editor, set project properties, and run.
- [x] Play actual mouse actions: collect debris, build each module, reject occupied/disconnected/underpowered/expensive placements, reach nine-module milestone. Inspect runtime diagnostics and screenshots.
- [x] Copy verified project to the workspace once writable. Document controls, architecture, verification and exact browser export prerequisite. Leave the game running.

## Cut list
Mining, exploration, trade, events, combat, research, multiplayer, save/load and store publishing.

## Verification result
Model tests passed. Mouse-driven runtime playthrough: 10/10 checks, no errors, nine modules and level 3 reached. Native runtime screenshot reviewed. Permanent workspace copy verified byte-for-byte against the tested build. Import and model tests passed from the permanent location; standalone Summer game launched there. HTML5 export remains blocked by the missing non-Mono Web environment.
