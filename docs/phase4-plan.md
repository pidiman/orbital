# Phase 4 implementation plan

Goal: turn surveyed anomalies into contacts and timed trade, retaining all 2D gameplay and v2 saves.

- [x] Add JSON factions, anomalies/aliens, goods, offers and a Trade ship capability.
- [x] Add a RefCounted trade model for contacts, standing, cargo escrow, timers, cancellation refunds and history. Fleet coordinates shared ship occupancy across mining/survey/trade.
- [x] Add capability-specific HUD commands and a contact/trade panel showing prices, rewards, standing, travel progress and history. Preserve original Miner/Scout controls.
- [x] Store trade state under extensions.alien_trade with its own schema version. Missing extension uses defaults and processes previously surveyed anomalies exactly once. Validate before committing any load.
- [x] Run model tests covering the full loop, busy hybrids, atomic affordability, cancellation, duplicate payout prevention, old v2 saves, active/completed save round-trips and malformed extension rejection.
- [x] Drive live UI through survey, Trade Ship purchase, launch, timer, rewards, standing and Save/Load; rerun existing playthroughs and inspect frames/diagnostics.

No Earth renderer or scene hierarchy changes. Future research consumption and diplomacy events remain outside this phase.
