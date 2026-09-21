extends RefCounted
const Supply = preload("res://scripts/region_supply.gd")
const Store = preload("res://scripts/save_store.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var stock := Supply.new(model, fleet, 42)
	var store := Store.new(model, fleet, stock)
	model.materials = 100
	model.build(Vector2(58, 0), "solar")
	model.buy_ship("material_ship")
	var id: int = model.next_ship_id
	checks.no_depot = stock.collection.deploy(id).contains("Space Depot")
	model.materials = 100
	checks.build = model.build(Vector2(-58, 0), "space_depot").is_empty() and model.capacity == 150
	checks.deploy = stock.collection.deploy(id).is_empty()
	stock.debris = {1: {"position": Vector2(0.5, 0.5), "velocity": Vector2.ZERO, "amount": 10}}
	for target: int in stock.fleet.resource_targets: stock.fleet.asteroids.erase(target)
	stock.fleet.resource_targets.clear()
	stock.floating.clear()
	stock.next_debris_id = 1
	var before: int = model.materials
	stock.collection.advance(0.1)
	checks.one_unit = stock.collection.jobs[id].cargo == 1 and stock.debris[1].amount == 9 and model.materials == before
	var snapshot: Dictionary = store.snapshot()
	checks.cargo_roundtrip = store.restore(snapshot).is_empty() and store.snapshot() == snapshot
	model.materials = model.capacity
	stock.collection.advance(10)
	checks.wait = stock.collection.jobs[id].waiting and stock.collection.jobs[id].cargo == 1 and stock.collection.waiting_message().contains("storage full")
	snapshot = store.snapshot()
	checks.wait_roundtrip = store.restore(snapshot).is_empty() and store.snapshot() == snapshot
	store.path = "user://collection-check-%d.json" % OS.get_process_id()
	checks.disk_roundtrip = store.save_game().is_empty() and store.load_game().is_empty() and store.snapshot() == snapshot
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	model.materials -= 2
	stock.collection.advance(0.1)
	checks.resume = not stock.collection.jobs[id].waiting and stock.collection.jobs[id].cargo == 0 and stock.collection.depots[Vector2(-58, 0)].delivered == 1
	stock.collection.advance(10)
	stock.collection.advance(10)
	checks.repeat = stock.collection.depots[Vector2(-58, 0)].delivered == 2
	var invalid: Dictionary = store.snapshot()
	invalid.extensions.material_collection.jobs = {"bad": {}}
	var stable: Dictionary = store.snapshot()
	checks.reject_atomic = not store.restore(invalid).is_empty() and store.snapshot() == stable
	stock.collection.advance(10)
	model.demolish_module(Vector2(-58, 0))
	stock.collection.advance(0.1)
	checks.removed_depot = stock.collection.jobs[id].waiting and stock.collection.jobs[id].cargo == 1
	before = model.materials
	var refund: int = model.ship_refund(id)
	model.decommission_ship(id)
	checks.cargo_recovery = model.materials == before + refund + 1 and stock.collection.jobs.is_empty()
	model.materials = 100
	model.build(Vector2(-58, 0), "space_depot")
	model.materials = 100
	model.buy_ship("material_ship")
	var first: int = model.next_ship_id
	model.buy_ship("material_ship")
	var second: int = model.next_ship_id
	stock.collection.deploy(first)
	stock.collection.deploy(second)
	stock.debris = {2: {"position": Vector2(0.6, 0.5), "velocity": Vector2.ZERO, "amount": 10}, 3: {"position": Vector2(0.8, 0.5), "velocity": Vector2.ZERO, "amount": 10}}
	stock.collection.advance(0.01)
	checks.reservations = stock.collection.jobs[first].target == 2 and stock.collection.jobs[second].target == 3
	checks.double_deploy = not stock.collection.deploy(first).is_empty()
	checks.shared_occupancy = fleet.unit_busy(first) and not fleet.trade(first, "missing", "missing").is_empty()
	stock.salvage(2)
	stock.collection.advance(0.01)
	checks.manual_race = stock.collection.jobs[first].target == -1 and stock.collection.jobs[first].cargo == 0
	fleet.regions.current_region = "mars"
	stock.collection.advance(10)
	stock.collection.advance(10)
	checks.home_background = stock.collection.jobs[second].region == "home" and stock.collection.depots[Vector2(-58, 0)].delivered > 0
	var old_model := StationModel.new()
	var old_fleet := MiningFleet.new(old_model)
	var old_stock := Supply.new(old_model, old_fleet, 1)
	var old_store := Store.new(old_model, old_fleet, old_stock)
	var old: Dictionary = old_store.snapshot()
	old.extensions.erase("material_collection")
	checks.old_save = store.restore(old).is_empty() and stock.collection.jobs.is_empty() and stock.collection.depots.is_empty()
	return checks
