# Outposts part 1 Implementation Plan

> Implement sequentially with a review checkpoint after each task.

**Goal:** Jump Ship founding and physically local outpost mining, with no return hauling or remote module construction.

**Architecture:** The existing WorldLocations station/structure records own outpost identity and local inventory. A RefCounted OutpostModel interprets founding capabilities and JSON definitions. Mining routes select a same-region player outpost, while existing Home adapters remain unchanged. Save v2 gains an outposts extension marker and additive canonical fields; pre-outpost cross-region mining orders are cancelled atomically without removing ore.

**Tech Stack:** GDScript RefCounted models, existing 2D Node2D/Control views, JSON catalogs, headless and rendered verification.

- [x] Add data/outposts.json (60 Materials, mineral storage), Jump Ship founding capability (65 Materials/2 Power), and enable outposts in non-Home region definitions.
- [x] Add scripts/outpost_model.gd: validate physical region, discovery, capability, occupancy, uniqueness and cost; atomically create station/structure/storage/founding state. Leave the hull intact.
- [x] Route mining to a same-region outpost; reject cross-region actors; preserve Home yields/timers/repetition. Keep trade, surveys and material collection restrictions separate.
- [x] Extend save validation and migration: validate inventory/ownership/founding IDs, allow local remote mining, retain active Home jobs; release legacy remote reservations and display a migration notice. Test rejected documents leave live state intact.
- [x] Extend the capability command registry and show local storage in region UI/2D view. Update obsolete remote-mining messages.
- [x] Add model tests for founding, gate transit, costs, duplicate commands, wrong region, local deposits, Home isolation, save/load and legacy migration. Update only the old remote-mining expectations that intentionally change.
- [x] Walk the rendered build/gate/found/mine/save/load flow; run Home, mining, trade/research/collection and persistence regressions; document results and limitations.
