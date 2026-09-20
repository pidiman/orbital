# Phase 4 — Alien life and trade

Orbital remains entirely 2D. Earth/orbit rendering and the active scene are byte-identical to the prior checkpoint.

## Playing

Survey **Echo pocket** with a Scout (six resource ticks). The Quiet signal resolves into a relay shared by **Archivist Iri / Lumen Archive** and **Navigator Venn / Prism Concord**. Both factions begin at standing 0. Open **Sector map → Contacts & trade**, or use a Trade Ship's command in Ships.

A **Trade Ship costs 50 Materials and reserves 2 Power**. It occupies no grid position. Choose a contact from the first selector, choose an idle trade-capable ship, then click an exchange. Cargo is paid up front; arrival after seven resource ticks grants rewards and records one completed voyage. Countdown, standing, inventory and the three latest history entries appear in the panel. The full history is retained in the model/save.

| Contact | Exchange | Cargo | Arrival reward | Required standing |
| --- | --- | --- | --- | ---: |
| Lumen | Research exchange | 18 Minerals | 1 Tech + 4 standing | 0 |
| Lumen | Supply the archive | 20 Materials | 8 standing | 0 |
| Concord | Goodwill cargo | 20 Materials | 8 standing | 0 |
| Concord | Crystal exchange | 12 Minerals + 8 Materials | 2 Xenocrystals + 3 standing | 8 |

Standing caps at 100. Tech and Xenocrystals are held for future research/fabrication; this phase does not add a research tree. Standing already unlocks the rare exchange. Twilight's **Ion chorus** is a natural anomaly whose survey grants one Tech once, alongside its existing mineable asteroid.

Decommissioning a busy Trade Ship returns all prepaid cargo plus the normal ship refund, even above storage capacity. No trade reward or standing is granted for a cancelled voyage. Invalid, unaffordable, locked, busy or duplicate actions spend nothing.

## Model boundaries and data

- `data/factions.json`: stable faction IDs, names, descriptions, colors and initial standing.
- `data/aliens.json`: anomaly IDs, sector associations, alien envoys and one-time non-alien research rewards.
- `data/trade_goods.json`: inventory goods and descriptions.
- `data/trade_offers.json`: faction-specific costs, goods, standing rewards and standing requirements.
- `data/ships.json`: the new trade capability, cost, power and duration.
- `scripts/trade_model.gd`: RefCounted faction/contact/inventory state, escrow transactions, timers, history, anomaly ledger and validation. No viewport or Node dependencies.
- `scripts/mining_fleet.gd`: coordinates discovery and one shared occupancy check across mining, surveying and trading. A hybrid can expose all three roles but runs only one mission at a time.
- `scripts/hud.gd`: an explicit capability-to-command registry replaces the old mining/otherwise-Scout branch. Each declared supported capability receives its own action. Capability-less ships receive no fake Scout action. Existing primary command references remain compatible with the original tests.
- `scripts/trade_panel.gd`: the contact/trade view; no economy transactions happen in presentation code.

Sector discovery merges anomaly definitions by stable ID/name without resetting asteroid records. `processed_anomalies` makes outcomes one-time. The existing mining UI refresh now changes button visibility only when the destination changes, avoiding cancellation of a held mouse press during a resource tick.

## Persistence

The envelope remains **v2**, in the same `user://orbital-save.json`. Phase 4 adds **`extensions.alien_trade`, schema_version 1**, containing:

- Faction identity, standing and contact flags.
- Discovered alien contacts and their sector/anomaly association.
- Goods inventory.
- Active trade jobs with transaction ID, contact/faction/offer, prepaid cargo, promised rewards and remaining/duration timers.
- Completed/cancelled history and applied standing delta.
- Processed anomalies and the next transaction ID.

Missing extension means an old v2 save: default faction/inventory state is added, existing discovered anomalies gain their contacts/research once, and the next save includes the extension. Existing core resources/jobs/asteroids are preserved. Newly installed faction/goods catalog entries get defaults while existing values survive. Unknown optional extension fields are retained. Invalid present extensions, orphaned contacts, invalid escrow/timers, double-booked ships and unsupported extension schemas reject the whole load before mutation.

Trade launch/completion and existing discovery/decommission events request autosave. Loading in flight does not charge cargo twice. Loading completed history does not replay rewards. Catalog definitions remain external, consistent with existing module/ship saves; content removal or balance changes that invalidate the core economy still require explicit future migrations.

## Verification

- Combined headless model suite: **168/168**, including **40 new trade checks**. Covers discovery timing, two factions, role rejection, atomic costs, standing gates, rare rewards, cancellation/full-storage recovery, hybrid occupancy, no double rewards, active/completed real-file round trips, old v2 defaults, idempotent anomaly upgrades, unknown-field retention and malformed-extension rejection.
- Existing economy suite passes; mining model suite **29/29**.
- Live mouse-driven trade playthrough: **21/21**, including mining the cargo, revealing aliens, buying/sending a Trade Ship, timer/reward/standing UI, spam rejection, autosave, active/completed Save/Load and hybrid command composition.
- All six previous gameplay playthroughs: **103/103**. Total live checks **124/124**, with empty `errors_seen` and successful finishes.
- Evidence: `phase4-playthrough-results.json`, `phase4-trade_in_transit.jpg`, `phase4-alien_trade_complete.jpg`. Tests use isolated user:// files and never read or overwrite the player's checkpoint.

Native Summer is verified. HTML5 export/browser-storage durability and physical touch hardware testing remain pending, as before. No offline progression, research spending, narrative diplomacy, war, or trade automation is added.
