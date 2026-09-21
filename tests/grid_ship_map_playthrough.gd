extends "res://tests/ship_tray_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 10000
	for x in range(1, 8): game.model.build(Vector2(x * 58, 0), "solar")
	var original: Dictionary = game.model.modules.duplicate(true)
	await use(hud.tool_buttons.solar)
	await use(hud.grid_buttons["Fit grid"])
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(Vector2(464, 0)))
	checks.outer_cell_ui_build = game.model.modules.get(Vector2(464, 0)) == "solar"
	checks.existing_positions_fixed = original.keys().all(func(p: Vector2) -> bool: return game.model.modules.get(p) == original[p])
	checks.grid_controls_inside_footer = hud.footer.get_global_rect().encloses(hud.grid_controls.get_global_rect())
	var previous_zoom: Vector2 = game.ship_camera.zoom
	await touch_at(hud.grid_buttons["+"].get_global_rect().get_center())
	checks.touch_zoom = game.ship_camera.zoom.x > previous_zoom.x
	checks.no_arrow_controls = hud.grid_buttons.size() == 3
	await use(hud.grid_buttons["Fit grid"])
	save_frame("expanded_grid")
	hud.close_panels()
	game.model.build(Vector2(464, 58), "space_depot")
	game.model.build(Vector2(0, 58), "research_lab")
	game.fleet.diplomacy.inventory.tech = 2
	game.fleet.research.research("teleportation")
	game.model.build(Vector2(-87, -29), "teleport_gate")
	game.fleet._discover_region("venus")
	game.fleet.diplomacy.inventory.xenocrystal = 2
	var ids: Dictionary = {}
	for kind: String in game.model.ship_catalog:
		await use(hud.ship_buttons[kind])
		ids[kind] = game.model.next_ship_id
	# Explicit test framing for sprite hit tests; selection no longer reframes.
	game.ship_camera.reset_view()
	for id: int in game.model.ships:
		game.ship_camera.position = game.ship_camera.ship_point(id)
		game.ship_camera.force_update_scroll()
		await tile(id)
		checks["tray %d" % id] = hud.selected_ship_id == id and tile_camera_stable
		hud.close_panels()
		var before: Dictionary = game.persistence.snapshot()
		await click(game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(id))
		checks["map menu %d" % id] = hud.selected_ship_id == id and hud.ship_context.visible and hud.sell_buttons[id].is_visible_in_tree()
		checks["shared selection %d" % id] = hud.ship_tiles[id].selected_ship and game.ship_camera.ship_id == -1
		checks["view only %d" % id] = before == game.persistence.snapshot()
		for capability: String in hud.capability_buttons[id]:
			checks["map command %d %s" % [id, capability]] = hud.capability_buttons[id][capability].is_visible_in_tree()
	checks.context_clear_footer = hud.ship_context.get_global_rect().end.y < hud.footer.position.y
	hud.close_panels()
	await touch_at(game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(ids.jump_ship))
	checks.native_touch_map = hud.selected_ship_id == ids.jump_ship and hud.ship_context.visible
	await use(hud.context_gate)
	await use(hud.gate_panel.jump_button)
	await tile(ids.jump_ship)
	hud.close_panels()
	await click(game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(ids.jump_ship))
	checks.transit_map = hud.ship_context.visible and hud.context_detail.text.contains("In transit")
	for i in range(10): game.fleet.transport.tick()
	await tile(ids.jump_ship)
	hud.close_panels()
	await click(game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(ids.jump_ship))
	checks.remote_map = hud.selected_ship_id == ids.jump_ship and hud.ship_context.visible and game.fleet.regions.current_region == "venus" and hud.capability_buttons[ids.jump_ship].founding.is_visible_in_tree()
	save_frame("remote_map_selection")
	await tile(ids.material_ship)
	game.model.materials = 0
	game.model.changed.emit()
	await use(hud.capability_buttons[ids.material_ship].collection)
	await tile(ids.material_ship)
	hud.close_panels()
	var hauling: Dictionary = game.persistence.snapshot()
	await click(game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(ids.material_ship))
	checks.active_collector_map = hud.ship_context.visible and game.persistence.snapshot() == hauling
	for i in range(2400): game.supply.advance(0.05)
	checks.outer_depot_collection = game.model.materials > 0
	await tile(ids.miner)
	await use(hud.capability_buttons[ids.miner].mining)
	var target: int = game.asteroids.rocks.keys()[0]
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[target].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point)
	checks.mining_assignment = game.fleet.jobs.has(ids.miner)
	var minerals: int = game.model.minerals
	for i in range(30): game.fleet.tick()
	checks.mining_delivery = game.model.minerals > minerals
	var test_path: String = "user://orbital-map-grid-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	checks.save_ok = game.persistence.save_game().is_empty()
	var expected: Dictionary = game.persistence.snapshot()
	checks.load_ok = game.persistence.load_game().is_empty() and game.persistence.snapshot() == expected
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()

func touch_at(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = get_viewport().get_final_transform() * point
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)
