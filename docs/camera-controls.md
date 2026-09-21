# Camera controls and local preferences

Presentation/input only; gameplay models and v2 saves are unchanged.

- Left press on the field starts a gesture. Release within 7 viewport pixels invokes the existing ship/asteroid/debris/build handler, in its original priority order. Exceeding 7 pixels pans instead and suppresses the click, including in placement mode. Dragging pulls the field with the pointer.
- W/A/S/D pan up/left/down/right at 600 viewport pixels/second. Diagonals are normalized. Arrow keys remain available for UI navigation; F9 is unchanged. Keyboard panning pauses while a panel is open or a text editor owns focus.
- Settings is an exclusive top-menu panel. Edge scrolling defaults OFF; when enabled, the outer 24 viewport pixels scroll at the same speed. Open panels, UI, dragging, loss of window focus, and leaving the viewport block edge scrolling.
- Manual pan releases ship-follow. Region switching and ship selection keep their existing recenter behavior. Reset view and Fit grid remain available. Camera center is bounded to the viewed region's projected area (including the Home grid), plus 240 world pixels of margin.

Tune `pan_speed`, `drag_threshold`, `edge_width`, and `bounds_margin` in `data/camera_controls.json`. Boolean preferences are declared in its `options` array and rendered automatically by Settings.

Preferences use ConfigFile, section `camera`, in `user://orbital-client.cfg` (inside the engine’s per-user Orbital data directory). They are loaded at startup independently of gameplay save/load. Disposable verification sessions disable normal preference persistence and test with an isolated file.

Verification: `tests/camera_playthrough.gd` covers drag suppression, short-click salvage, placement drag, WASD, default/toggled edge scrolling, UI blocking, ConfigFile reload, bounds, reset and fit. Existing HUD, ship-tray, and map-selection playthroughs cover retained commands and save/load.
