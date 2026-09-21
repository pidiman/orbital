extends "res://tests/ship_tray_playthrough.gd"
var motion: Node

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	motion = game.ship_motion
	game.model.materials = 10000
	for x in range(1, 9): game.model.build(Vector2(x * 58, 0), "solar")
	var ids: Dictionary = {}
	var x: int = 0
	for kind: String in game.model.ship_catalog:
		game.model.build(Vector2(x * 58, 58), kind + "_dock")
		await use(game.hud.ship_buttons[kind])
		ids[kind] = game.model.next_ship_id
		x += 1
	await tile(ids.miner)
	await use(game.hud.capability_buttons[ids.miner].mining)
	var target: int = game.asteroids.rocks.keys()[0]
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[target].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point)
	checks.ui_assign = game.fleet.jobs.has(ids.miner)
	# With the model clock stopped, sprites must still move every render frame.
	var snapshot: Dictionary = game.persistence.snapshot()
	var start: Vector2 = motion.position_for(ids.miner)
	var moved_frames: int = 0
	var previous: Vector2 = start
	for i in range(12):
		await settle(1)
		var point: Vector2 = motion.position_for(ids.miner)
		if point.distance_to(previous) > 0.0001: moved_frames += 1
		previous = point
	checks.continuous_between_ticks = moved_frames >= 10
	checks.visual_does_not_tick = game.persistence.snapshot() == snapshot
	checks.camera_and_sprite = game.asteroids.ship_position(ids.miner) == game.ship_camera.ship_point(ids.miner)
	game.ship_camera.position = (motion.position_for(ids.miner) + game.asteroids.rocks[target].point) * 0.5
	game.ship_camera.force_update_scroll()
	await settle(2)
	save_frame("miner_mid_flight")
	# Deterministic fixed-delta view stepping checks the exact speed limit.
	motion.set_process(false)
	var path: String = "user://orbital-motion-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	checks.flight_saved = game.persistence.save_game().is_empty()
	snapshot = game.persistence.snapshot()
	motion.advance_visual(0.03)
	checks.flight_load = game.persistence.load_game().is_empty() and game.persistence.snapshot() == snapshot and game.fleet.jobs.has(ids.miner)
	checks.valid_loaded_point = motion.position_for(ids.miner).is_finite()
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ore_before: int = game.model.minerals
	var remaining: int = game.fleet.jobs[ids.miner].remaining
	for i in range(remaining - 1): game.fleet.tick()
	checks.no_early_yield = game.model.minerals == ore_before
	game.fleet.tick()
	checks.exact_yield = game.model.minerals == ore_before + 18
	game.fleet.cancel_unit(ids.miner)
	check_steps(ids.miner, "dock return")
	for i in range(300): motion.advance_visual(1.0 / 60.0)
	checks.reaches_dock = motion.position_for(ids.miner).distance_to(game.asteroids.dock_point(ids.miner)) < 0.01
	game.fleet.survey(ids.scout, "echo")
	check_steps(ids.scout, "scout outbound")
	for i in range(5): game.fleet.tick()
	check_steps(ids.scout, "scout return")
	game.fleet.tick()
	game.model.add_minerals(18)
	game.fleet.trade(ids.trader, "lumen_envoy", "archive_data")
	check_steps(ids.trader, "trade outbound")
	for i in range(6): game.fleet.tick()
	check_steps(ids.trader, "trade return")
	game.fleet.tick()
	game.model.build(Vector2(348, 58), "space_depot")
	game.fleet.collection.deploy(ids.material_ship)
	check_steps(ids.material_ship, "collector deployment")
	game.model.materials = 0
	for i in range(100):
		game.supply.advance(0.05)
		var before: Vector2 = motion.position_for(ids.material_ship)
		motion.advance_visual(0.05)
		checks.collection_bounded = before.distance_to(motion.position_for(ids.material_ship)) <= motion.speed_for(ids.material_ship) * 0.05 + 0.01
		if not checks.collection_bounded: break
	checks.collector_shared_point = game.get_node("MaterialShips").ship_position(ids.material_ship) == game.ship_camera.ship_point(ids.material_ship)
	game.model.materials = 10000
	game.model.build(Vector2(406, 58), "research_lab")
	game.fleet.diplomacy.inventory.tech = 2
	game.fleet.research.research("teleportation")
	game.model.build(Vector2(-87, -29), "teleport_gate")
	game.fleet._discover_region("venus")
	game.fleet.diplomacy.inventory.xenocrystal = 1
	game.fleet.transport.jump(Vector2(-87, -29), ids.jump_ship, "venus")
	check_steps(ids.jump_ship, "gate approach")
	for i in range(3): game.fleet.tick()
	await tile(ids.jump_ship)
	motion.advance_visual(0.0)
	checks.region_boundary = motion.viewed_region == "venus" and game.fleet.transport.location(ids.jump_ship) == "venus" and motion.position_for(ids.jump_ship).is_finite()
	game.fleet.regions.set_location("home")
	game.model.build(Vector2(0, 116), "mining_ship")
	game.supply._spawn_asteroid(true)
	await settle(2)
	motion.advance_visual(0.0)
	var legacy := Vector2(0, 116)
	var rock: int = game.supply.next_home_id
	checks.legacy_order = game.fleet.dispatch(rock).is_empty() and game.fleet.jobs.has(legacy)
	check_steps(legacy, "legacy miner")
	# Small quantized target changes are eased across frames, not one-frame hops.
	var collector: int = ids.material_ship
	motion.advance_visual(0.016)
	var marker: Vector2 = motion.target_for(collector)
	motion.points[collector] = marker - Vector2(2, 0)
	var first: Vector2 = motion.position_for(collector)
	motion.advance_visual(0.016)
	var second: Vector2 = motion.position_for(collector)
	motion.advance_visual(0.016)
	checks.small_steps_eased = first != second and second != motion.position_for(collector) and second.distance_to(marker) > 0.01
	# Deleted actors leave no visual cache behind.
	game.model.decommission_ship(ids.trader)
	motion.advance_visual(0.016)
	checks.cache_cleanup = not motion.points.has(ids.trader)
	# A large view fixture exercises cache scaling without running the economy.
	for i in range(100):
		game.model.next_ship_id += 1
		game.model.locations.add_ship(game.model.next_ship_id, "scout", game.model.locations.primary_station())
	game.model.recalculate()
	game.model.changed.emit()
	snapshot = game.persistence.snapshot()
	var began: int = Time.get_ticks_usec()
	for i in range(60): motion.advance_visual(1.0 / 60.0)
	report("motion_100_ships_average_ms", float(Time.get_ticks_usec() - began) / 60000.0)
	checks.large_fleet_view_only = game.persistence.snapshot() == snapshot and motion.points.size() <= game.model.ships.size() + 1
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()

func check_steps(id: Variant, label: String) -> void:
	var snapshot: Dictionary = game.persistence.snapshot()
	var first: Vector2 = motion.position_for(id)
	var bounded: bool = true
	for i in range(12):
		var previous: Vector2 = motion.position_for(id)
		motion.advance_visual(1.0 / 60.0)
		bounded = bounded and previous.distance_to(motion.position_for(id)) <= motion.speed_for(id) / 60.0 + 0.001
	checks[label + " bounded"] = bounded
	checks[label + " moves"] = first.distance_to(motion.position_for(id)) > 0.01
	checks[label + " model unchanged"] = game.persistence.snapshot() == snapshot
