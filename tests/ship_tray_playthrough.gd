extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	# Legal construction with a fixed funding fixture; purchases/actions use UI.
	game.model.materials = 10000
	for x in range(1, 5): game.model.build(Vector2(x * 58, 0), "solar")
	game.model.build(Vector2(0, 58), "space_depot")
	game.model.build(Vector2(58, 58), "research_lab")
	game.fleet.diplomacy.inventory.tech = 2
	game.fleet.research.research("teleportation")
	game.model.build(Vector2(-87, -29), "teleport_gate")
	game.fleet._discover_region("venus")
	game.fleet.diplomacy.inventory.xenocrystal = 3
	var ids: Dictionary = {}
	await use(hud.menu_buttons.Ships)
	for kind: String in game.model.ship_catalog:
		await use(hud.ship_buttons[kind])
		ids[kind] = game.model.next_ship_id
	checks.catalog_buys_all_roles = game.model.ships.size() == 5
	checks.one_tile_per_ship = hud.ship_tiles.size() == game.model.ships.size()
	checks.no_command_list_in_catalog = not hud.panel.is_ancestor_of(hud.ship_rows)
	checks.inline_title = absf(hud.title_label.get_global_rect().get_center().y - hud.toolbar.get_global_rect().get_center().y) < 12
	for id: int in game.model.ships:
		var before: Dictionary = game.persistence.snapshot()
		await tile(id)
		checks["tile selects %d" % id] = hud.selected_ship_id == id and hud.ship_context.visible
		checks["camera centers %d" % id] = centered(id)
		checks["no simulation mutation %d" % id] = before == game.persistence.snapshot()
		checks["commands retained %d" % id] = hud.sell_buttons[id].is_visible_in_tree()
		for capability: String in hud.capability_buttons[id]:
			checks["capability %d %s" % [id, capability]] = hud.capability_buttons[id][capability].is_visible_in_tree()
		checks["art reused %d" % id] = hud.ship_tiles[id].art == game.model.ship_catalog[game.model.ships[id]].art
	await tile(ids.material_ship)
	await use(hud.capability_buttons[ids.material_ship].collection)
	checks.material_deploy = game.fleet.collection.jobs.has(ids.material_ship)
	await settle(3)
	checks.collection_camera = centered(ids.material_ship)
	await tile(ids.trader)
	await use(hud.capability_buttons[ids.trader].trade)
	checks.trade_context_opens = hud.trade_panel.visible and not hud.ship_context.visible
	await tile(ids.scout)
	await use(hud.capability_buttons[ids.scout].survey)
	checks.scout_command = game.fleet.survey_jobs.has(ids.scout)
	await tile(ids.miner)
	await use(hud.capability_buttons[ids.miner].mining)
	checks.miner_assignment_mode = game.asteroids.selected_ship == ids.miner and not hud.ship_context.visible
	# A normal asteroid click after the camera translation still uses world coordinates.
	var target: int = game.asteroids.rocks.keys()[0]
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point
	# Pan this view so the target is in unobstructed world space; no model change.
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[target].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	screen = game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point
	await click(screen)
	checks.mining_hit_after_pan = game.fleet.jobs.has(ids.miner)
	await tile(ids.jump_ship)
	await use(hud.context_gate)
	checks.gate_preselects_ship = hud.gate_panel.selected_ship() == ids.jump_ship
	await use(hud.gate_panel.jump_button)
	checks.gate_command_unchanged = game.fleet.transport.jobs.has(ids.jump_ship) and game.fleet.diplomacy.inventory.xenocrystal >= 0
	await tile(ids.jump_ship)
	checks.transit_shown = hud.context_detail.text.contains("In transit") and hud.context_detail.text.contains("Venus") and centered(ids.jump_ship)
	for i in range(10): game.fleet.transport.tick()
	var before: Dictionary = game.persistence.snapshot()
	await tile(ids.jump_ship)
	checks.remote_region_selected = game.fleet.regions.current_region == "venus" and not game.board.visible
	checks.remote_centered = centered(ids.jump_ship)
	checks.ship_location_unchanged = game.model.locations.ship_region(ids.jump_ship) == "venus" and game.model.locations.station_region("station:home") == "home"
	var after: Dictionary = game.persistence.snapshot()
	before.extensions.regions.current_region = "venus"
	checks.only_view_region_changes = before == after
	await use(hud.capability_buttons[ids.jump_ship].founding)
	checks.founding_reachable = not game.model.locations.outpost_at("venus", "player").is_empty()
	await settle(3)
	save_frame("remote_ship_context")
	# Native touch selects the ship and returns the view to its physical Home region.
	checks.touch_emulation_enabled = Input.emulate_mouse_from_touch
	var touch := InputEventScreenTouch.new()
	touch.position = get_viewport().get_final_transform() * hud.ship_tiles[ids.trader].get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	await settle(2)
	touch.pressed = false
	Input.parse_input_event(touch)
	await settle(2)
	checks.touch_selects_and_changes_region = hud.selected_ship_id == ids.trader and game.fleet.regions.current_region == "home" and centered(ids.trader)
	await use(hud.sell_buttons[ids.trader])
	checks.decommission_removes_tile = not game.model.ships.has(ids.trader) and not hud.ship_tiles.has(ids.trader)
	# Many ships: purchase enough to require horizontal scrolling.
	for x in range(-4, 0): game.model.build(Vector2(x * 58, 116), "solar")
	for i in range(12): game.model.buy_ship("scout")
	await settle(3)
	checks.tray_scrolls = hud.ship_tray.get_h_scroll_bar().max_value > hud.ship_tray.size.x
	# Drag the actual horizontal scrollbar, as a pointer/touch device would.
	hud.ship_tray.scroll_horizontal = 0
	await settle(2)
	var bar: HScrollBar = hud.ship_tray.get_h_scroll_bar()
	var start: Vector2 = bar.get_global_rect().position + Vector2(30, bar.size.y * 0.5)
	var down := InputEventMouseButton.new()
	down.position = start
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(400, 0)
	motion.relative = Vector2(400, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	var up := InputEventMouseButton.new()
	up.position = motion.position
	up.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(up, true)
	await settle(2)
	checks.tray_pointer_scroll = hud.ship_tray.scroll_horizontal > 0
	var last: int = game.model.next_ship_id
	await tile(last)
	checks.last_tile_reachable = hud.selected_ship_id == last and centered(last)
	checks.panels_clear_tray_footer = hud.ship_context.position.y >= hud.ship_tray.get_global_rect().end.y and hud.ship_context.get_global_rect().end.y < hud.footer.position.y
	save_frame("many_ships")
	# Verify world interaction under an offset camera, not just model commands.
	hud.close_panels()
	game.model.materials = 0
	game.model.changed.emit()
	var piece: Dictionary = game.debris.pieces[0]
	# Choose exposed debris: map-ship selection takes priority when a sprite
	# crosses the salvage point, especially in this large moving fleet fixture.
	for candidate: Dictionary in game.debris.pieces:
		var clear: bool = true
		for id: int in game.model.ships:
			if game.fleet.transport.location(id) == game.fleet.regions.current_region and candidate.point.distance_to(game.ship_camera.ship_point(id)) < 70:
				clear = false
		for rock: Dictionary in game.asteroids.rocks.values():
			if candidate.point.distance_to(rock.point) < 50: clear = false
		if clear:
			piece = candidate
			break
	game.ship_camera.ship_id = -1
	game.ship_camera.position = piece.point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport().get_canvas_transform() * piece.point)
	checks.salvage_after_pan = game.model.materials > 0
	game.model.collect(100)
	await use(hud.tool_buttons.solar)
	var build_point := Vector2(0, 116)
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.board.world_to_screen(build_point)
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(build_point))
	checks.placement_after_pan = game.model.modules.get(build_point) == "solar"
	var test_path: String = "user://orbital-tray-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await use(hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.model.add_minerals(1)
	await use(hud.load_button)
	await settle(3)
	checks.save_load_unchanged = game.persistence.snapshot() == expected
	checks.tray_rebuilt_on_load = hud.ship_tiles.size() == game.model.ships.size() and hud.selected_ship_id == -1 and not hud.ship_context.visible
	await tile(last)
	checks.restored_tile_works = centered(last)
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()

func tile(id: int) -> void:
	game.hud.ship_tray.ensure_control_visible(game.hud.ship_tiles[id])
	await settle(2)
	await click(game.hud.ship_tiles[id].get_global_rect().get_center())

func centered(id: int) -> bool:
	var point: Vector2 = game.get_viewport().get_canvas_transform() * game.ship_camera.ship_point(id)
	return point.distance_to(game.get_viewport_rect().size * 0.5) < 2
