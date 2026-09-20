# Research and gate implementation plan

Goal: spend trade Tech on permanent catalog unlocks and Xenocrystals on Home gate transport, preserving v2 saves and existing gameplay.

1. Add technologies.json and Research Lab / Teleport Gate module definitions. RefCounted ResearchModel owns researched IDs and per-lab completion counts, checks lab/prerequisites/Tech, and resolves generic unlock categories.
2. Generalize footprint cells around continuous module centers. Reuse cell overlap/edge geometry for any rectangular footprint; snap even-sized centers halfway between grid lines. Update preview, inspection, drawing and save geometry validation.
3. RefCounted GateTransport owns gate counters, ship locations and timed transit jobs. Launch validates installed gate, idle Home ship, discovered adjacent destination and data-defined crystal cost. Arrivals only relocate ships; block their existing work commands. Gate demolition does not cancel launched transit.
4. Add a Research / Gates panel with catalog rows, Tech balance and explicit lock reasons, gate/ship/destination pickers and current ship location. Hide locked module buttons, keep module catalog scrollable.
5. Save research and transport fields in additive v2 extensions, validate all references and mission exclusivity before commit, default missing fields for old saves. Preserve opaque extension metadata.
6. Run model tests for trade-funded research, four-cell overlap/bounds/continuous placement/demolition, transport cost/zero cost/busy/unknown/unreachable destinations, arrival isolation and save round-trips. Run existing regressions and a rendered UI walkthrough with trade acquisition, research, gate build/jump/save/load/demolition. Record evidence and warnings.
