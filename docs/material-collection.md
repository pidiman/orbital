# Automated material collection

Build Space Depot in Modules (35 Materials, 2 Power, +50 shared material capacity).
Buy Material Ship in Ships (40 Materials, 1 Power), then choose Deploy at Home.
The `material_depot` and `collection` capabilities drive availability and behavior;
ship names/types are not used to dispatch jobs. Speed, cargo capacity and supported
region are defined in data/ships.json.

The ship selects the nearest unreserved debris to the Home station, flies to it,
and uses SectorSupply.salvage with a cargo receiver and a one-unit limit. Manual
salvage uses the same function and retains its existing 8–14 material fragment
amounts. No new spawning system or alternate salvage amount generator exists.
Cargo is credited through StationModel.collect only on arrival at the depot.
Full storage retains cargo and shows a bottom-bar waiting message. Spending
materials resumes delivery automatically. Multiple ships reserve different debris;
manual salvage or drifting debris can invalidate a target, causing reselection.

Collection continues at Earth while the player views other regions. Cross-region
hauling is future scope. Removing the final depot pauses the ship with cargo intact;
building another resumes it. Decommissioning refunds carried cargo even above capacity,
following existing recovery behavior. Motion and all rendering remain 2D.

Verification: 19 collection model checks, 11 rendered UI/playthrough checks,
29 existing mining checks and 210 existing ships/upgrades/exploration/recovery/
persistence/trade/region checks pass. The rendered probe builds and deploys using
mouse input, observes repeated deliveries, fills storage, confirms the bottom message,
restores waiting cargo, then purchases a Scout to free storage and observes resumption.
Model checks also cover exact disk save/load, old saves, atomic rejection, competing
collectors, manual collection races, removal/recovery and Home background operation.
See tests/collection_runner.gd and tests/collection_playthrough.gd.
