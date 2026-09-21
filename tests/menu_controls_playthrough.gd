extends "res://tests/outpost_playthrough.gd"

func zoom_key(code: int, frames: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game.camera_input.focused = true
	for frame in frames: game.camera_input._process(0.05)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	game.camera_input.set_process(false)
	var hud = game.hud
	var camera = game.ship_camera
	var before: Dictionary = game.persistence.snapshot()
	checks.top_menu = hud.menu_buttons.has("Menu") and not hud.menu_buttons.has("Settings")
	checks.save_load_relocated = hud.menu_panel.is_ancestor_of(hud.save_button) and hud.menu_panel.is_ancestor_of(hud.load_button) and not hud.resource_bar.is_ancestor_of(hud.save_button) and not hud.resource_bar.is_ancestor_of(hud.load_button)
	checks.no_arrows = hud.grid_buttons.size() == 3
	checks.default_visible = game.preferences.values.show_grid_controls and hud.grid_controls.is_visible_in_tree()
	checks.footer_parent = hud.footer.is_ancestor_of(hud.grid_controls)
	checks.message_centered = is_equal_approx(hud.status_label.get_global_rect().get_center().x, hud.footer.get_global_rect().get_center().x)
	checks.no_overlap = not hud.status_label.get_global_rect().intersects(hud.grid_controls.get_global_rect())
	await use(hud.menu_buttons.Menu)
	save_frame("menu")
	await use(hud.settings_button)
	checks.nested_settings = hud.settings_panel.visible and not hud.menu_panel.visible
	game.preferences.path = "user://menu-controls-test-%d.cfg" % OS.get_process_id()
	game.preferences.enabled = true
	await use(hud.settings_toggles.show_grid_controls)
	checks.hidden = not hud.grid_controls.visible
	var restored = preload("res://scripts/client_preferences.gd").new()
	restored.path = game.preferences.path
	restored.load_preferences()
	checks.reload_hidden = not restored.values.show_grid_controls
	await zoom_key(KEY_BRACKETLEFT, 1)
	checks.hidden_zoom_out = camera.zoom.x < 1.0 and camera.zoom.x > 0.15
	await zoom_key(KEY_BRACKETRIGHT, 2)
	checks.hidden_zoom_in = camera.zoom.x > 1.0
	await zoom_key(KEY_BRACKETRIGHT, 100)
	checks.max_zoom = is_equal_approx(camera.zoom.x, 2.0)
	await zoom_key(KEY_BRACKETLEFT, 100)
	checks.min_zoom = is_equal_approx(camera.zoom.x, 0.15)
	await use(hud.settings_toggles.show_grid_controls)
	checks.shown = hud.grid_controls.visible
	restored.load_preferences()
	checks.reload_shown = restored.values.show_grid_controls
	hud.close_panels()
	await use(hud.grid_buttons["Fit grid"])
	checks.fit_works = camera.zoom.x < 1.0
	var zoom_before: float = camera.zoom.x
	await use(hud.grid_buttons["+"])
	checks.plus_works = camera.zoom.x > zoom_before
	await use(hud.grid_buttons["−"])
	checks.minus_works = is_equal_approx(camera.zoom.x, zoom_before)
	checks.game_unchanged = before == game.persistence.snapshot()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.preferences.path))
	get_window().content_scale_size = Vector2i(960, 720)
	get_window().size = Vector2i(960, 720)
	hud.message("Material Ship waiting — storage full")
	await settle(5)
	checks.small_centered = is_equal_approx(hud.status_label.get_global_rect().get_center().x, hud.footer.get_global_rect().get_center().x)
	checks.small_clearance = not hud.status_label.get_global_rect().intersects(hud.grid_controls.get_global_rect())
	save_frame("bottom_controls")
	report("checks", checks)
	finish()
