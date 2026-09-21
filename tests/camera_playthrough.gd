extends "res://tests/outpost_playthrough.gd"

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = down
	get_viewport().push_input(event, true)
	await settle(2)

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	get_viewport().push_input(event, true)
	await settle(2)

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var camera = game.ship_camera
	var input = game.camera_input
	var hud = game.hud
	input.focused = true
	input.set_process(false) # Deterministic frame durations for continuous input checks.
	var before: Dictionary = game.persistence.snapshot()
	checks.default_off = not game.preferences.values.edge_scrolling
	await mouse(Vector2(600, 450), true)
	var origin: Vector2 = camera.position
	await motion(Vector2(680, 490))
	await mouse(Vector2(680, 490), false)
	checks.drag_direction = camera.position.is_equal_approx(origin - Vector2(80, 40))
	checks.drag_no_action = before == game.persistence.snapshot()
	camera.reset_view()
	# Placement mode must remain armed after a drag, without spending/building.
	hud.choose("solar")
	before = game.persistence.snapshot()
	await mouse(Vector2(600, 450), true)
	await motion(Vector2(620, 450))
	await mouse(Vector2(620, 450), false)
	checks.build_drag_no_action = before == game.persistence.snapshot() and game.board.selected == "solar"
	hud.choose("")
	camera.reset_view()
	# A short click still salvages through the original handler, only on release.
	var piece: Dictionary = game.debris.pieces[0]
	camera.position = piece.point
	camera.force_update_scroll()
	var center: Vector2 = game.get_viewport_rect().size * 0.5
	var materials: int = game.model.materials
	await mouse(center, true)
	checks.press_defers_action = game.model.materials == materials
	await motion(center + Vector2(3, 0))
	await mouse(center + Vector2(3, 0), false)
	checks.short_click_salvages = game.model.materials > materials
	camera.reset_view()
	for code: int in [KEY_W, KEY_A, KEY_S, KEY_D]:
		origin = camera.position
		var key_event := InputEventKey.new()
		key_event.physical_keycode = code
		key_event.pressed = true
		Input.parse_input_event(key_event)
		Input.flush_buffered_events()
		input.focused = true
		input._process(0.05)
		key_event = InputEventKey.new()
		key_event.physical_keycode = code
		Input.parse_input_event(key_event)
		checks["key_%d" % code] = is_equal_approx(camera.position.distance_to(origin), 30.0)
	game.preferences.path = "user://camera-test-preferences.cfg"
	game.preferences.enabled = true
	before = game.persistence.snapshot()
	await use(hud.settings_button)
	await use(hud.settings_toggles.edge_scrolling)
	checks.toggle_on = game.preferences.values.edge_scrolling
	checks.menu_blocks_edge = input.edge_direction(Vector2(1, 450)) == Vector2.ZERO
	var restored = preload("res://scripts/client_preferences.gd").new()
	restored.path = game.preferences.path
	restored.load_preferences()
	checks.preference_reload = restored.values.edge_scrolling
	hud.close_panels()
	await motion(Vector2(1, 450))
	checks.edge_direction = input.edge_direction(Vector2(1, 450)) == Vector2.LEFT
	origin = camera.position
	input.focused = true
	input._process(0.05)
	checks.edge_moves = camera.position.x < origin.x
	checks.ui_blocks_edge = input.edge_direction(Vector2(40, 30)) == Vector2.ZERO
	await use(hud.settings_button)
	await use(hud.settings_toggles.edge_scrolling)
	hud.close_panels()
	checks.toggle_off = input.edge_direction(Vector2(1, 450)) == Vector2.ZERO
	checks.settings_no_game_mutation = before == game.persistence.snapshot()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.preferences.path))
	camera.pan_pixels(Vector2(1e8, 1e8))
	checks.bounds_max = camera.position == camera.pan_bounds().end
	camera.pan_pixels(Vector2(-1e8, -1e8))
	checks.bounds_min = camera.position == camera.pan_bounds().position
	await use(hud.station_view_button)
	checks.reset = camera.position == center and camera.zoom == Vector2.ONE
	camera.fit_grid()
	checks.fit = camera.zoom.x < 1.0
	await use(hud.settings_button)
	save_frame("camera_settings")
	game.fleet._discover_region("venus")
	game.fleet.regions.current_region = "venus"
	camera.pan_pixels(Vector2(1e8, 1e8))
	checks.remote_bounds = camera.position == camera.pan_bounds().end
	report("checks", checks)
	finish()
