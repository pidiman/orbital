# Regions-only exploration

The runtime has one exploration/content layer: Home/Earth, Venus, Mars and Pluto. Sector definitions, map, discovery arrays, old Scout missions and counters were removed. `RegionSupply` is the existing presentation-independent supply model renamed from its old terminology; floating spawn, salvage and mining quantities/timers are unchanged.

Scouts use the existing region survey commands and data-driven `neighbors` graph. The ship command opens Outposts/Regions for choosing an adjacent undiscovered planet. Region viewing is separate from physical ship travel and no longer requires intermediate view hops.

`data/aliens.json` places Quiet signal and its two existing envoys at Venus and Ion chorus at Mars. They are explicit regional anomalies, with unchanged factions, offers, standing and one-time rewards. Surveying these planets discovers their contacts. Generated regional deposits and resource anomalies remain intact.

Gates now require an owned departure and destination gate in two different discovered regions. Any such pair connects directly, including Home–Pluto; Scout adjacency is not a gate routing constraint. Existing Xenocrystal costs and departure inventory rules remain. In-flight saves resume their launched trip even if a gate was subsequently demolished.

**Founding bootstrap unresolved:** strict paired gates prevent a new Jump Ship from reaching a region before the first outpost/gate is built there. Existing remote ships/outposts still work. No exception or free gate has been added without an explicit choice.

Save v2 keeps its version. Runtime fleet fields no longer contain sector arrays or old Scout missions. The compatibility loader moves discovered persistent ore to Home region records, retains amounts/positions/IDs and active mining, moves previously discovered contacts to Home anomalies, preserves inventory/standing/history/reward flags, and cancels old Scout missions. Subsequent saves strip the obsolete fields. Retired field names occur only at the compatibility boundary and in migration/historical test fixtures.

`tests/regions_only_playthrough.gd` verifies Scout discovery/UI, regional alien trade, old-save migration without duplicate earnings, exact new/migrated round-trips, paired nonadjacent gate travel, transit persistence and missing-gate/cost blocking. Refinery, hauling and compact HUD probes remain passing.
