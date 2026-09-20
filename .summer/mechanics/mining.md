# Phase 1: Mining

Input: click/tap a large violet asteroid to send the first idle Mining Ship. Small amber debris still yields Materials immediately. Asteroids are placed in outer orbital lanes to keep the station grid usable. Input is consumed by the clicked object, preventing accidental construction.

Response: reserve one asteroid and one ship. Show a flight path, moving ship silhouette and eight resource-tick countdown. On completion deliver up to 18 Minerals, free the ship, and remove a depleted asteroid. Claimed asteroids stay in-sector until mining completes; unclaimed ones drift away. Duplicate dispatch and busy/no-ship actions show an explanation without changing resources.

Economy: Mining Ship costs 45 Materials / 2 Power. Refinery costs 40 Materials / 3 Power. Each refinery converts 2 Minerals into 6 Materials every 3 one-second resource ticks. Conversion only progresses with sufficient input and room for the entire output; no resources are lost when storage is full. Multiple ships/refineries operate independently. Minerals have no cap in this phase.

Architecture: optional mining and conversion capabilities in data/modules.json. Existing StationModel owns resource balances and per-module conversion progress. MiningFleet owns target reservations and jobs; AsteroidField owns movement, rendering and pointer input. ResourceClock calls StationModel.tick; its ticked signal advances fleet jobs. HUD iterates catalog keys and displays Minerals plus fleet/refinery status. Unknown art types fall back to a generic habitat silhouette.

Feedback: violet rocks are visibly larger than amber debris; named asteroid labels, flight trails, countdowns and mineral popups explain progress. No new audio requirement; preserve existing silent presentation.

Verification: retain baseline model and full builder playthrough. Add model/fleet checks for duplicates, parallel ships, completion-once, departed targets, paused conversion, multiple refineries and data-driven capabilities. Run a mouse-driven fresh-game playthrough: salvage real debris, build solar/ship, click a natural asteroid, wait for Minerals, build a refinery, verify conversion with no intervening salvage. Capture mining and refining frames and inspect runtime diagnostics.

Deferred: exploration, trade, events, research, save/load and Web export environment setup.
