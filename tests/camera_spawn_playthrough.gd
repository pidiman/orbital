extends "res://tests/menu_controls_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	game.camera_input.set_process(false)
	var hud = game.hud
	var camera = game.ship_camera
	game.model.materials = 10000
	for i in range(1, 7): game.model.build(Vector2(i * 58, 0), "solar")
	game.model.build(Vector2(0, 58), "research_lab")
	game.fleet.diplomacy.inventory.tech = 2
	game.fleet.research.research("teleportation")
	game.model.build(Vector2(-87, -29), "teleport_gate")
	game.model.buy_ship("miner")
	var miner: int = game.model.next_ship_id
	await settle(2)
	camera.zoom_view(0.63)
	game.asteroids._sync_view()
	camera.position = game.asteroids.rocks[1].point + Vector2(-80, 0)
	camera.force_update_scroll()
	var position_before: Vector2 = camera.position
	var zoom_before: Vector2 = camera.zoom
	await use(hud.ship_tiles[miner])
	checks.same_region_tile = camera.position == position_before and camera.zoom == zoom_before and hud.selected_ship_id == miner
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.rocks[1].point)
	await settle(10)
	checks.dispatch_static = game.fleet.jobs.has(miner) and camera.position == position_before and camera.zoom == zoom_before
	hud.close_panels()
	camera.position = camera.ship_point(miner) + Vector2(-100, 0)
	camera.force_update_scroll()
	position_before = camera.position
	await click(game.get_viewport().get_canvas_transform() * camera.ship_point(miner))
	checks.same_region_sprite = camera.position == position_before and camera.zoom == zoom_before and hud.selected_ship_id == miner
	game.model.buy_ship("scout")
	var scout: int = game.model.next_ship_id
	game.fleet._discover_region("venus")
	game.fleet.diplomacy.inventory.xenocrystal = 1
	game.fleet.transport.jump(Vector2(-87, -29), scout, "venus")
	for tick in range(20): game.fleet.transport.tick()
	await use(hud.ship_tiles[scout])
	checks.remote_center = game.fleet.regions.current_region == "venus" and camera.position.is_equal_approx(camera.ship_point(scout))
	checks.remote_zoom = camera.zoom == zoom_before
	position_before = camera.position
	await settle(10)
	checks.no_follow = camera.position == position_before and camera.ship_id == -1
	checks.label_order = hud.zoom_label.get_index() == hud.grid_buttons["−"].get_index() + 1 and hud.grid_buttons["+"].get_index() == hud.zoom_label.get_index() + 1
	await use(hud.grid_buttons["+"])
	await settle(2)
	checks.button_label = hud.zoom_label.text == ("%.2f" % camera.zoom.x).trim_suffix("0") + "x"
	await zoom_key(KEY_BRACKETLEFT, 4)
	await settle(2)
	checks.keyboard_label = hud.zoom_label.text == ("%.2f" % camera.zoom.x).trim_suffix("0") + "x"
	checks.centered_footer = is_equal_approx(hud.status_label.get_global_rect().get_center().x, hud.footer.get_global_rect().get_center().x)
	save_frame("zoom_readout")
	# A fresh seeded supply fixture; normal production weights/caps/timing, no forced type.
	game.fleet.regions.set_location("home")
	hud.close_panels()
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	fleet.regions.records = RegionModel.new(0).records
	var supply := SectorSupply.new(model, fleet, 0)
	supply.advance(180.0)
	checks.natural_xeno = not fleet.resource_targets.is_empty()
	var target: int = fleet.resource_targets.keys()[0]
	var binding: Dictionary = fleet.resource_targets[target]
	checks.rare_small = fleet.asteroids[target].minerals == 1 and supply.floating_rules.types.xenocrystal.weight < supply.floating_rules.types.minerals.weight
	checks.lifetime = supply.floating.home.pieces[binding.piece_id].remaining > 60.0
	# Load the naturally generated fixture into the visible game through normal restore.
	model.materials = 1000
	model.build(Vector2(58, 0), "solar")
	model.buy_ship("xeno_miner")
	var store = preload("res://scripts/save_store.gd").new(model, fleet, supply)
	var restore_error: String = game.persistence.restore(store.snapshot())
	checks.fixture_restore = restore_error.is_empty()
	report("restore_error", restore_error)
	if not restore_error.is_empty():
		report("checks", checks)
		finish()
		return
	await settle(3)
	checks.node_drawn = game.asteroids.rocks.has(target)
	camera.position = game.asteroids.rocks[target].point
	camera.force_update_scroll()
	await use(hud.ship_tiles[game.model.next_ship_id])
	await click(game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point)
	checks.natural_node_assigned = game.fleet.jobs.has(game.model.next_ship_id)
	var snapshot: Dictionary = game.persistence.snapshot()
	checks.node_save_roundtrip = game.persistence.restore(snapshot).is_empty() and game.persistence.snapshot() == snapshot
	for tick in range(20): game.fleet.tick()
	checks.natural_node_mined = game.fleet.diplomacy.inventory.xenocrystal == 1
	report("checks", checks)
	finish()
