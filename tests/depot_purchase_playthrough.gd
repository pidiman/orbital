extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	game.save_dialogs.show_new()
	await use(game.save_dialogs.body.get_child(1))
	var m: StationModel = game.model
	checks.starting = m.materials == 130
	checks.no_depot = m.buy_ship("miner") == "Build a Space Depot first."
	checks.infrastructure = m.build(Vector2(58, 0), "solar").is_empty() and m.build(Vector2(116, 0), "space_depot").is_empty() and m.build(Vector2(174, 0), "space_dock").is_empty() and m.materials == 50
	m.materials = 1000 # Fund subsequent ships independently of the starting budget.
	game.hud._buy_ship("miner")
	var first: int = m.next_ship_id
	var origin: Vector2 = game.asteroids.home_position(first)
	checks.spawn_at_depot = game.ship_motion.position_for(first).is_equal_approx(origin)
	await settle(5)
	checks.flies = game.ship_motion.position_for(first).distance_to(origin) > 0.0 and game.ship_motion.position_for(first).distance_to(game.asteroids.dock_point(first)) > 1.0
	for i in range(200): game.ship_motion.advance_visual(0.05)
	checks.docked = game.ship_motion.position_for(first).distance_to(game.asteroids.dock_point(first)) < 1.0
	m.build(Vector2(58, 58), "solar")
	m.buy_ship("scout")
	var second: int = m.next_ship_id
	checks.full_dock = game.fleet.docking.status(second) == "homeless" and game.ship_motion.position_for(second).is_equal_approx(game.asteroids.home_position(second))
	m.buy_ship("jump_ship")
	var founder: int = m.next_ship_id
	game.fleet._discover_region("venus")
	m.locations.ships[founder].region = "venus"
	checks.founded = game.fleet.outposts.found(founder).is_empty()
	game.fleet.regions.set_location("venus")
	checks.remote_no_depot = m.buy_ship("miner") == "Build a Space Depot first."
	var local: StationModel = game.board.model
	checks.remote_build = local.build(Vector2(58, 0), "solar").is_empty() and local.build(Vector2(116, 0), "space_depot").is_empty()
	var home_funds: int = m.materials
	var local_funds: int = local.materials
	await settle(2)
	game.hud._buy_ship("miner")
	var remote: int = m.next_ship_id
	checks.remote_purchase = m.locations.ships[remote].station_id == local.station_id and m.locations.ship_region(remote) == "venus" and m.materials == home_funds and local.materials == local_funds - int(m.ship_catalog.miner.cost)
	checks.remote_homeless = game.fleet.docking.status(remote) == "homeless" and game.ship_motion.position_for(remote).is_equal_approx(game.asteroids.home_position(remote))
	local.recalculate()
	checks.local_power = local.power_use == 1 + 2 + int(m.ship_catalog.miner.power_use)
	local.build(Vector2(174, 0), "space_dock")
	checks.remote_dock = game.fleet.docking.status(remote) == "parked" or game.fleet.docking.status(founder) == "parked"
	var saved: Dictionary = game.persistence.snapshot()
	var error: String = game.persistence.restore(saved)
	checks.roundtrip = error.is_empty() and game.persistence.snapshot() == saved and m.materials == home_funds
	report("restore_error", error)
	var old := StationModel.new()
	var fleet := preload("res://scripts/mining_fleet.gd").new(old)
	var supply := preload("res://scripts/region_supply.gd").new(old, fleet, 0)
	var store := OrbitalSaveStore.new(old, fleet, supply)
	checks.old_save_no_grant = game.persistence.restore(store.snapshot()).is_empty() and m.materials == 40
	report("checks", checks)
	finish()
