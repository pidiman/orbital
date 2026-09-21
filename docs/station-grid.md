# Station grid configuration

Edit `data/station_grid.json` and restart the game. Defaults are `columns: 17`
and `rows: 17`: 289 cells, increased from 9×9 / 81. Each dimension must be an odd
integer of at least 9. Rectangular grids are supported. Invalid definitions
warn and fall back to 17×17.

The grid grows around the same (0, 0) origin. Cell spacing remains 58 model units;
default cell centers range from −464 to +464 on both axes. Continuous positions,
grid snapping, connectivity, overlap and 2×2 footprint rules are unchanged.
The full footprint must remain in bounds. The view retains the original cell
scale, with Fit grid, zoom and pan controls to reach the expanded area.

There are no new save fields or version changes. The v2 loader uses the current
configured bounds; a legacy 9×9 save therefore loads directly without rewriting
coordinates or identities. Exact continuous coordinates also survive. Do not
shrink a configured grid below an existing colony's occupied footprint: the
existing bounds validation will reject modules outside that smaller area.

`tests/grid_checks_runner.gd` creates an actual v2 file under the previous 9×9
bounds and loads it under 17×17. It verifies exact positions and identities,
outer placement, four-cell gate reservation/demolition, rectangular bounds and
an unchanged v2 snapshot schema. Gameplay costs and resource rules are unchanged.
