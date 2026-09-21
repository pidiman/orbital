extends RefCounted
const Supply = preload("res://scripts/region_supply.gd")
const Store = preload("res://scripts/save_store.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var stock := Supply.new(model, fleet, 11)
	var store := Store.new(model, fleet, stock)
	model.materials = 1000
	model.build(Vector2(58, 0), "solar")
	model.build(Vector2(116, 0), "solar")
	checks.retired_build_blocked = not model.build(Vector2(-58, 0), "mining_ship").is_empty()
	# Author a genuine old-layout fixture using the prior buildability rule.
	model.catalog.mining_ship.buildable = true
	model.build(Vector2(-58, 0), "mining_ship")
	model.build(Vector2(-116, 0), "storage")
	model.build(Vector2(0, 58), "miner_dock")
	fleet.dispatch(1)
	model.buy_ship("miner")
	var active: int = model.next_ship_id
	stock._spawn_asteroid()
	fleet.dispatch(stock.next_home_id, active)
	model.buy_ship("miner")
	var parked: int = model.next_ship_id
	var positions: Array = model.modules.keys()
	var identities: Dictionary = {}
	for point: Vector2 in positions: identities[point] = model.structure_id_at(point)
	var job: Dictionary = fleet.jobs[active].duplicate(true)
	var materials: int = model.materials
	var snapshot: Dictionary = store.snapshot()
	var error: String = store.restore(snapshot)
	checks.loads = error.is_empty()
	checks.converts_in_place = model.modules[Vector2(-58, 0)] == "miner_dock" and model.modules.keys() == positions and positions.all(func(point: Vector2) -> bool: return model.structure_id_at(point) == identities[point])
	checks.refund = model.materials == materials + 20
	checks.module_job_released = not fleet.jobs.has(Vector2(-58, 0)) and not fleet.asteroids[1].claimed and fleet.asteroids[1].minerals == 18
	checks.ship_job_untouched = fleet.jobs[active] == job
	checks.existing_dock_untouched = model.modules[Vector2(0, 58)] == "miner_dock" and fleet.docking.ships[parked].dock_id == identities[Vector2(0, 58)]
	checks.notice = store.migration_notice.contains("refunded 20")
	var migrated: Dictionary = store.snapshot()
	checks.idempotent = store.restore(migrated).is_empty() and store.snapshot() == migrated
	var old: Dictionary = snapshot.duplicate(true)
	old.extensions.erase("world_locations")
	old.extensions.erase("docking")
	old.extensions.erase("outposts")
	var legacy_error: String = store.restore(old)
	print("Pre-location migration: ", legacy_error)
	checks.pre_location_save = legacy_error.is_empty() and model.modules[Vector2(-58, 0)] == "miner_dock" and model.materials == materials + 20
	for tick in range(int(job.remaining)): fleet.tick()
	checks.ore_ship_yield = model.minerals == 18
	print("Retirement migration error: ", error)
	return checks
