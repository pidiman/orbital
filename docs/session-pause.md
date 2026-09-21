# Global session pause

The top-bar Ⅱ / ▶ button and Space both call `SessionPause.toggle()`. The controller is an always-processing CanvasLayer; it sets `SceneTree.paused`, leaving the gameplay tree, ResourceClock, camera input, HUD timers, autosave clock and ship interpolation under the normal pausable process mode. No model timers or economy rules change.

While paused, the input controller consumes gameplay input before GUI/world handling. Only resume, visible Close buttons and Escape dismissal are allowed. Pending map drag gestures and transient dropdown popups are dismissed on pause to avoid replaying a partial interaction on resume. Existing panels stay visible behind a shaded PAUSED indicator.

Space takes priority over Godot's default `ui_accept` button activation, including focused buttons. WASD, brackets and F9 retain their normal behavior when running and are blocked while paused.

Pause is not serialized. A successful load resets the session to running. Save/Load UI is intentionally unavailable during pause, but programmatic or exit saving still serializes the unchanged game state safely.

`tests/session_pause_playthrough.gd` verifies both toggles, frozen model and mining/visual state, blocked gameplay input, Close dismissal, focus conflicts, resumed time and a disk save made while paused followed by a running load.
