# Camera controls and local preferences

Presentation/input only; gameplay models and v2 saves are unchanged.

- Left press on the field starts a gesture. Release within 7 viewport pixels invokes the existing ship/asteroid/debris/build handler, in its original priority order. Exceeding 7 pixels pans instead and suppresses the click, including in placement mode. Dragging pulls the field with the pointer.
- W/A/S/D pan up/left/down/right at 600 viewport pixels/second. Diagonals are normalized. Arrow keys remain available for UI navigation; F9 is unchanged. Keyboard panning pauses while a panel is open or a text editor owns focus.
- Menu contains Save, Load, and the Settings entry; Save/Load no longer occupy the resource bar. Settings is an exclusive panel. Edge scrolling defaults OFF; when enabled, the outer 24 viewport pixels scroll at the same speed. Open panels, UI, dragging, loss of window focus, and leaving the viewport block edge scrolling.
- Ship selection never follows a moving ship. Same-region map/tray selection and asteroid dispatch preserve camera position and zoom. Selecting a ship in another region switches region and centers once on its physical position, preserving zoom. Region switching also preserves zoom. Reset view and Fit grid remain available. Camera center is bounded to the viewed region's projected area (including the Home grid), plus 240 world pixels of margin.

Tune `pan_speed`, `drag_threshold`, `edge_width`, and `bounds_margin` in `data/camera_controls.json`. Boolean preferences are declared in its `options` array and rendered automatically by Settings.

Preferences use ConfigFile, section `camera`, in `user://orbital-client.cfg` (inside the engine’s per-user Orbital data directory). They are loaded at startup independently of gameplay save/load. Disposable verification sessions disable normal preference persistence and test with an isolated file.

Verification: `tests/camera_playthrough.gd` covers drag suppression, short-click salvage, placement drag, WASD, default/toggled edge scrolling, UI blocking, ConfigFile reload, bounds, reset and fit. Existing HUD, ship-tray, and map-selection playthroughs cover retained commands and save/load.

## Bottom controls and keyboard zoom

Fit grid, −, a live zoom multiplier, and + are always visible at the left of the bottom message bar by default, in every region and with panels closed. Equal side reservations keep the message centered without overlap. Directional arrow buttons have been removed.

Settings → “Show Fit grid & zoom controls” persists `show_grid_controls` in the same local config; older configs default it to true. Hiding these controls does not disable shortcuts. Hold `[` to smoothly zoom out or `]` to zoom in around the camera center, through the existing `zoom_view` method (0.15–2.0 limits). `keyboard_zoom_rate` in camera_controls.json tunes exponential zoom speed. Text-entry focus suppresses shortcuts. WASD and F9 are unchanged.

`tests/menu_controls_playthrough.gd` verifies nesting, relocation, centered messages, visibility persistence, both zoom limits, hidden-controls keyboard zoom, and the smaller desktop/touch layout.

`tests/camera_spawn_playthrough.gd` verifies unchanged framing on same-region selection and dispatch, cross-region centering with preserved zoom, live button/keyboard zoom text, and naturally spawned Xeno mining/save continuation.

## Trackpad and wheel zoom

Pinch uses Godot `InputEventMagnifyGesture.factor`; spreading fingers zooms in. Vertical `InputEventPanGesture.delta.y` and wheel up/down provide alternative zoom inputs. Fractional wheel factors are preserved for high-resolution scrolling. All call `zoom_view`, with the same 0.15–2.0 limits and live footer multiplier as buttons/brackets. The cursor's world point stays fixed unless camera bounds prevent it; buttons and brackets retain center-based zoom.

Tune `data/camera_controls.json`: `pinch_sensitivity` = 1.0 (exponent on native magnification), `scroll_zoom_sensitivity` = 0.08 (log zoom per vertical gesture unit), `wheel_zoom_sensitivity` = 0.12 (log zoom per notch, about 12.75% in). Lower values reduce sensitivity; zero disables that input. No gameplay save or preference schema changes.

Gestures use unhandled input so UI scrolling takes priority, plus the existing HUD hit test blocks panels, tray, bars and buttons. Zoom is ignored during a pending left-click/drag and while unfocused. `tests/gesture_zoom_playthrough.gd` injects all three native Godot event types through the viewport and checks cursor anchoring, directions, limits, UI blocking, live labels and unchanged model snapshots. Physical MacBook trackpad feel is not measured by these automated tests.
