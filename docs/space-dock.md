# Universal Space Dock

Only Space Dock is offered as a buildable dock. It costs 25 Materials and consumes 1 Power. `docking.ship_type: "*"` accepts all ship roles (including future roles); owner and physical-region matching remain required. Existing idle return, reservations, job release and homeless behavior are unchanged. Ships never cross regions to park.

| Tier | Slots | Materials to upgrade to this tier |
| --- | --- | --- |
| T1 | 1 | — |
| T2 | 2 | 30 |
| T3 | 3 | 55 |
| T4 | 4 | 90 |

The three-entry upgrade array in `data/modules.json` caps Space Dock at T4. There is no T5 option or active stat entry. A future tier can be added by appending data.

All six typed dock definitions remain as non-buildable legacy definitions so old saves can be validated against their original capacities and assignments. After full validation, their data-driven `migration_replacement` and `migration_tiers` convert them in place:

- Old T1 (2 slots) → Space Dock T2 (2 slots).
- Old T2 (3 slots) → Space Dock T3 (3 slots).
- Old T3 (4 slots) → Space Dock T4 (4 slots).
- Old T4/T5 (6/8 slots) → Space Dock T4 (4 slots).

Stable IDs, owners, regions and positions remain unchanged. Valid reservations are preserved; overflow ships use another available dock or become homeless and remain taskable. No ships are removed, jobs cancelled or resources charged/refunded for dock conversion. The separate retired Mining Ship module now converts directly to Space Dock T1 with its existing 20-Material refund and module-mining-job retirement.

Save version remains v2. Canonical kinds/tiers live in `extensions.world_locations`; parking assignments/capacity usage remain in `extensions.docking`, with matching legacy station projections. No new save schema is needed. Migration is idempotent.

`tests/space_dock_playthrough.gd` checks live construction, upgrades/capacity, max tier UI, all roles parking, job release, full messaging, region isolation, demolition, round-trip, and all 30 typed-dock/tier migration combinations plus their second round-trip. The click-to-mine regression uses Space Dock and checks unchanged mining/salvage/Xeno behavior.
