# Connector Tubes and adjacency

Connector Tube is a 1×1, 5-Material, zero-power structural module. It has
three Materials-only upgrades (T2 8, T3 12, T4 18); the tiers currently change
the visual reinforcement only and deliberately add no capacity, output, or
power. T5 is not exposed. The module is available in the Home catalog and the
outpost buildable-module allowlist.

The station model checks new placement footprints for an orthogonal edge to an
existing footprint. A multi-cell placement, including the 2×2 Teleport Gate,
passes when any cell touches. Diagonal contact does not count. The first module
in an otherwise empty station is exempt. Existing modules are never rechecked
on load, so old non-connected layouts remain functional. The placement error is
“Must be placed next to an existing module or tube.”

New games receive five free tubes around the starting Habitat at
(-58,0), (58,0), (0,-58), (0,58), and (116,0). They are actual structures and
therefore persist normally in the v2 world-location extension. The existing
Home startup Materials calculation is unchanged: 35 + 25 + 20 + 50 = 130;
tubes are free and do not consume that budget. Outpost cores act as the local
adjacency anchor, so tubes and modules can be chained there using local
Materials.

The tube art is a teal cylindrical passage with dark interior, rails, bulkhead
reinforcement marks, and connector points. Existing board connection lines
visually bridge adjacent modules/tubes. Higher tube tiers add reinforcement
marks without affecting gameplay.
