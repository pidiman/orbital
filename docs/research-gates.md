# Research and Teleport Gates

Open **Research / Teleport Gates** beneath the module catalog.

- Research Lab: 40 Materials, 2 Power.
- Teleport Gate research: 2 Tech, spent once. Requires a lab; unlock survives lab demolition.
- Teleport Gate construction: 80 Materials, 3 Power, 2×2 footprint. No Tech build charge.
- Transport: 1 Xenocrystal, 3 simulation ticks. Both values are configurable in the module's `teleport` capability; zero jump cost is supported.

Acquire Tech from the Lumen Archive's Research exchange and Xenocrystals from the
Prism Concord's Crystal exchange after earning the required standing. Research lists
costs and Researched / Available / Locked status, with the reason for a lock.
Locked module buttons are hidden until their technology is researched.

The Home gate launches idle ships to discovered direct neighbors in the existing
region graph. The selected ship moves; the player's viewed region and primary
station do not move. Arrived ships are rendered at their destination and their
location appears in the fleet and transport UI. Remote ship work, further hauling,
return gates and remote construction are future scope. Existing abstract mining
missions remain unchanged; relocated ships cannot start mining, survey, trade or
collection jobs. Busy Material Ships must be decommissioned or otherwise have their
assignment cancelled before transport; an idle Material Ship can be transported.

The gate's continuous center is snapped half a cell along each even-sized axis.
All four occupied cell centers participate in overlap, edge connection and bounds
checks. Inspection works from any occupied cell; demolition frees the entire
footprint and applies the existing material refund. A launched ship still arrives
if its gate is demolished. Decommissioning a ship during transit refunds its paid
jump goods, following the existing mission recovery convention.

## Data and model boundaries

`data/technologies.json` defines id, name, description, `tech_cost`, optional
`requires` prerequisite IDs, and `unlocks` categories (currently module catalog IDs).
Additional module-unlocking technologies and prerequisites require only catalog
changes. `ResearchModel` and `GateTransport` are RefCounted, with no presentation
or scene dependencies. Research and teleport capabilities select labs and gates;
no module-type switch controls research or transport. Generic footprint geometry
supports rectangular module definitions. Node2D drawing and Control-based UI adapt
the models to the screen.

Save v2 remains unchanged at the top level. New state lives under
`extensions.research` and `extensions.gate_transport`; see save-format.md.

## Verification

- 42 research/transport model checks passed, covering trade-funded Tech and crystals,
  permanent research, insufficient resources, data-only unlocks, four-cell occupancy,
  bounds, fractional overlap, direct graph routes, zero jump cost, duplicate launch,
  remote work blocking, gate demolition during transit, exact disk save/load, legacy
  defaults and atomic rejection of corrupt unlock state.
- 31 rendered walkthrough checks passed with no engine errors or frame warnings:
  salvage, mining, contact discovery and trade; lab build; research; 2×2 gate build;
  transport cost and insufficient-crystal feedback; transit/arrival save/load;
  viewing the arrived ship at Venus; inspection and demolition. Insufficient-crystal
  UI edge case explicitly sets the balance to zero after verifying paid jumps.
- Existing economy/placement tests, 29 mining checks, 210 ships/upgrades/exploration/
  recovery/persistence/trade/region checks and 19 Material Ship checks passed.
  The 11-check rendered Material Ship walkthrough also passed.
- Editor diagnostics show no project/script/debugger errors. The editor retains its
  pre-existing control-focus warning; isolated verification runs reported no warnings.

Run `tests/research_runner.gd` with Summer headless for model checks. Run
`tests/research_playthrough.gd` through the Summer verification runner for rendered
proof. Evidence: research-playthrough-results.json and research-gate-*.jpg.
