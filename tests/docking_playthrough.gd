extends "res://tests/ship_tray_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 10000
	for x in range(1, 9): game.model.build(Vector2(x * 58, 0), "solar")
	var funds: int = game.model.materials
	await use(hud.tool_buttons.miner_dock)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(Vector2(0, 58)))
	checks.build_ui = game.model.modules.get(Vector2(0, 58)) == "miner_dock" and game.model.materials == funds - 25
	var dock_id: String = game.model.structure_id_at(Vector2(0, 58))
	for i in range(3): await use(hud.ship_buttons.miner)
	checks.two_slots = game.fleet.docking.usage.get(dock_id, {}).size() == 2
	checks.homeless_message = hud.status_label.text.contains("no free Miner dock") and game.fleet.docking.status(3) == "homeless"
	await tile(1)
	for i in range(180): await settle(1)
	checks.visual_dock = game.asteroids.ship_position(1).distance_to(game.asteroids.dock_point(1)) < 1
	checks.parked_tray = hud.ship_tiles[1].status == "Parked" and hud.context_detail.text.contains("Parked")
	hud.close_panels()
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.ship_position(1))
	checks.parked_map_commands = hud.selected_ship_id == 1 and hud.capability_buttons[1].mining.is_visible_in_tree()
	hud.close_panels()
	var touch := InputEventScreenTouch.new()
	touch.position = get_viewport().get_final_transform() * (game.get_viewport().get_canvas_transform() * game.asteroids.ship_position(1))
	touch.pressed = true
	Input.parse_input_event(touch)
	await settle(2)
	touch.pressed = false
	Input.parse_input_event(touch)
	await settle(2)
	checks.parked_touch = hud.selected_ship_id == 1 and hud.ship_context.visible
	save_frame("parked_miner")
	await use(hud.capability_buttons[1].mining)
	var target: int = game.asteroids.rocks.keys()[0]
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[target].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point)
	checks.dispatch_ui = game.fleet.jobs.has(1) and game.fleet.docking.status(1) == "working"
	checks.waiter_takes_slot = game.fleet.docking.status(3) == "parked" and game.fleet.docking.usage[dock_id].size() == 2
	var test_path: String = "user://orbital-docking-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await use(hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.fleet.cancel_unit(1)
	await use(hud.load_button)
	await settle(3)
	checks.disk_roundtrip = game.persistence.snapshot() == expected
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	game.ship_camera.reset_view()
	hud.close_panels()
	# Inspect the dock itself (parked sprites sit below it), then demolish.
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(Vector2(0, 58)))
	checks.inspect_capacity = hud.upgrade_stats.text.contains("Parking: 2 / 2")
	await use(hud.demolish_button)
	checks.demolish_ui = not game.model.modules.has(Vector2(0, 58)) and game.fleet.docking.status(2) == "homeless" and game.fleet.docking.status(3) == "homeless"
	checks.active_job_survives = game.fleet.jobs.has(1)
	hud.status_time = 0
	await settle(2)
	checks.demolish_message = hud.status_label.text.contains("no free Miner dock")
	await use(hud.menu_buttons.Build) # Close inspection before opening the catalog.
	# Isolate placement from randomly spawned debris over catalog test cells.
	game.supply.debris.clear()
	game.debris._sync_view()
	# All five catalog docks are normal build modules with the same controls.
	var x: int = 0
	for kind: String in game.model.ship_catalog:
		await use(hud.tool_buttons[kind + "_dock"])
		var point := Vector2(x * 58, 58)
		await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(point))
		checks["dock build " + kind] = game.model.modules.get(point) == kind + "_dock"
		if not checks["dock build " + kind]: report("build failure " + kind, {"message": hud.status_label.text, "selected":game.board.selected,"point":str(point),"camera":str(game.ship_camera.position)})
		x += 1
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()
