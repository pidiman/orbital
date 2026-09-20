# Phase 3 — Exploration

Input: open Sector map, choose a reachable sector and an owned Scout, then Send Scout. After the data-defined travel timer, its state changes from unexplored through exploring to revealed. Choose a Miner and a discovered deposit to begin the existing repeated mining loop.

Feedback: sector state list, destination, remaining seconds/progress bar, and a persistent discovery report. Asteroids list ore remaining/mining/depleted; anomalies are text records only; empty sectors report no resources. No new audio in this phase.

Rules: one mission per Scout, one Scout per destination, reject invalid/unreachable/revealed destinations without mutation. Discovery creates mining targets in the fleet model exactly once, even without a renderer. Discovered targets stay until depleted; drifting home targets retain expiry. Sector records use stable string IDs and positive home asteroid IDs are separate from negative discovery IDs.

Data: sectors.json lists routes, travel seconds and typed contents. Ship survey travel_speed scales sector travel time. Modules and positions unchanged. Future content types slot into the discovery records; no alien/event mechanics built.

UI graph: existing HUD/Interface gains a SectorMap PanelContainer (containers, labels, buttons, OptionButtons and ProgressBar only). Earth and Node2D scene untouched.

Verification plan: model rejection/concurrency/reveal-once/persistence/anomaly/empty cases; mouse build Scout → choose Dawn → travel → discovery → buy/assign Miner → timed payout; existing MVP, mining, upgrades and continuous-position suites.

Verified: exploration live 20/20, existing live MVP 10/10, mining 18/18, ships/positioning 25/25; model combined 72/72, mining 29/29, station economy passed. All probes finished with no runtime errors or frame warnings. Discovery ID -1 was reserved to avoid no-selection sentinel collisions; discoveries start at -1000. Persistent discovery markers use separate visual lanes so they cannot block transient home asteroids.
