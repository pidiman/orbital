# Ship-only mining and legacy module migration

The standalone `mining_ship` station module is retired. Its definition remains in `data/modules.json` solely for old-save validation/migration, with `buildable: false` and `migration_replacement: miner_dock`. It is absent from Build and new construction is blocked. Existing Miner Dock definitions and ship mining costs, timers and yields are unchanged.

On loading a validated old save, each Mining Ship module becomes a Tier 1 Miner Dock at its exact continuous position and stable structure ID. The Materials price difference (45 − 25 = 20) is refunded, including above storage capacity as with ordinary recovery refunds. Its module-owned mining job is cancelled and the asteroid reservation released without consuming remaining Ore or granting unfinished yield. Other ship jobs and existing docks remain intact. Layout/connectivity are preserved because the replacement occupies the same cell. The dock draws its normal 1 Power instead of the retired module's 2.

Migration happens on the isolated candidate after the entire saved graph passes validation, before committing to the live session. Both pre-location and canonical-location v2 saves are supported. Re-saving records the replacement through existing v2 fields; no save version or new fields are needed. A migrated save does not refund again.

Clicking an asteroid now resolves the explicit Assign selection first, otherwise the highlighted ship if it has a mining capability, then calls the existing `MiningFleet.dispatch` method. This also supports Xeno Miners. The existing resource/region/busy checks still apply; a selected incompatible miner cannot claim the wrong resource. With no mining ship selected, existing auto-dispatch behavior is unchanged. Floating salvage and click-versus-drag handling are unchanged.

Verification: `retired_mining_checks.gd` covers conversion, refunds, stable positions/IDs, active jobs, existing docks, pre-location saves and idempotence. `click_mining_playthrough.gd` verifies the Build catalog, direct and explicit assignment, docking, Ore/Xeno yields and Materials salvage through the live UI.
