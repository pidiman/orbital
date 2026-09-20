# Continuous station positioning

Module centers are canonical `Vector2` world coordinates in `StationModel.modules`, measured in fixed world units (a module footprint is 58 × 58). They are not cell indices or viewport pixels. Tier and refinery state, build/upgrade signals, and Phase 1 mining jobs use those same continuous coordinates. Independent ships retain their integer ship IDs.

`StationGeometry` owns continuous footprint overlap, edge-contact connectivity, and the current build-area limit. It neither rounds nor snaps. Partial edge contact is valid; diagonal corner contact and separated modules are not. The current grid yields exactly the former placement decisions.

`station_board.gd` is the presentation/input adapter:
- `screen_to_world` / `world_to_screen` isolate projection from simulation.
- `placement_position` applies optional snapping before passing world coordinates to the model.
- `snap_enabled` defaults to true; `snap_spacing` defaults to 58 world units.
- Cell indices exist only for drawing the helper grid and test mouse targeting.
- Selection uses world-space footprint hit testing; drawing and mining paths project the stored positions.

To loosen/remove snapping, change the board's snap settings. To introduce a depth-style view later, extend the board projection and inverse input mapping. Resource, upgrade, mining and placement rules do not depend on that projection. This change adds no depth simulation or 3D nodes, and no module-movement feature.

Verification: station model regression passed; mining 29/29; ships/upgrades plus continuous-position checks 49/49. Played MVP 10/10, mining 18/18, ships/upgrades plus projection checks 25/25. Fractional positions survive without quantization and support upgrades/refinery/mining. Tested projection round trips and altered board scale/origin without changing simulation positions. All gameplay probes finished with no errors or frame warnings.

Earth script SHA256 remains `8e0ad4e005111c623d9e6a03afc1eb1fe6cb1c34969e835b28325b1ce386669f`.
