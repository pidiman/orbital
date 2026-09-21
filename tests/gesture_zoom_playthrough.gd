extends "res://tests/menu_controls_playthrough.gd"

func send_zoom(kind: String, amount: float, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event: InputEvent
	if kind == "pinch":
		event = InputEventMagnifyGesture.new()
		event.factor = amount
	elif kind == "scroll":
		event = InputEventPanGesture.new()
		event.delta = Vector2(0, amount)
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if amount > 0 else MOUSE_BUTTON_WHEEL_DOWN
		event.factor = absf(amount)
		event.pressed = true
	event.position = point
	get_viewport().push_input(event, true)
	await settle(2)

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	game.camera_input.set_process(false)
	game.camera_input.focused = true
	var camera = game.ship_camera
	var hud = game.hud
	var snapshot: Dictionary = game.persistence.snapshot()
	var point := Vector2(450, 450)
	for kind: String in ["pinch", "scroll", "wheel"]:
		camera.reset_view()
		var anchor: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * point
		await send_zoom(kind, 1.2 if kind == "pinch" else (-1.0 if kind == "scroll" else 1.0), point)
		checks[kind + "_in"] = camera.zoom.x > 1.0
		checks[kind + "_anchor"] = (game.get_viewport().get_canvas_transform() * anchor).distance_to(point) < 0.01
		await send_zoom(kind, 1.0 / 1.2 if kind == "pinch" else (1.0 if kind == "scroll" else -1.0), point)
		checks[kind + "_out"] = is_equal_approx(camera.zoom.x, 1.0)
		await send_zoom(kind, 100.0 if kind != "scroll" else -100.0, point)
		checks[kind + "_max"] = is_equal_approx(camera.zoom.x, 2.0)
		await send_zoom(kind, 0.001 if kind == "pinch" else (100.0 if kind == "scroll" else -100.0), point)
		checks[kind + "_min"] = is_equal_approx(camera.zoom.x, 0.15)
		await use(hud.menu_buttons.Menu)
		var before: Vector2 = camera.zoom
		await send_zoom(kind, 1.2 if kind == "pinch" else -1.0, hud.menu_panel.get_global_rect().get_center())
		checks[kind + "_ui_blocked"] = camera.zoom == before
		hud.close_panels()
	camera.reset_view()
	await send_zoom("pinch", 1.25, point)
	checks.live_label = hud.zoom_label.text == "1.25x"
	save_frame("gesture_zoom")
	await use(hud.grid_buttons["+"])
	checks.button = camera.zoom.x > 1.25
	await zoom_key(KEY_BRACKETLEFT, 4)
	checks.keyboard = camera.zoom.x < 1.25
	checks.model_unchanged = snapshot == game.persistence.snapshot()
	report("checks", checks)
	finish()
