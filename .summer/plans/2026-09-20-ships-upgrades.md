# Ships and upgrades implementation plan

- [x] Add ship/sector catalogs, per-module tiers, purchases and effective stat lookup.
- [x] Extend fleet jobs with independent ships, repeating assignments and Scout surveys.
- [x] Add Ships and Upgrade UI pages, 2D fleet visuals, module selection and tier badges.
- [x] Run model tests, original playthroughs and Phase 2 mouse playthrough.
- [x] Verify Earth hash and absence of runtime 3D nodes, review screenshots and diagnostics.
- [x] Update documentation and leave the updated game running.

Evidence: 38/38 new model checks, 21/21 Phase 2 runtime checks, 29/29 previous mining model checks, 18/18 mining playthrough and 10/10 MVP playthrough. Miner auto-delivery at frames 423 and 583 (18 then 36 Minerals), upgrade at frame 591 pays 30 M + 8 Minerals and increases Power 3 -> 7. All probe errors_seen lists empty. Earth source hash unchanged; active scene root Node2D and runtime tree contains no 3D nodes. Reviewed ship/upgrade screenshots. One transient UI-focus warning observed at editor launch, no runtime debugger errors.
