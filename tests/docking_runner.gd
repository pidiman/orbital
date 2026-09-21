extends SceneTree
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/sector_supply.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	var model := StationModel.new()
	var fleet := Fleet.new(model)
	var supply := Supply.new(model, fleet)
	var store := Store.new(model, fleet, supply)
	model.materials = 10000
	for x in range(1, 9): model.build(Vector2(x * 58, 0), "solar")
	model.buy_ship("miner")
	checks.no_dock_homeless = fleet.docking.status(1) == "homeless"
	var funds: int = model.materials
	var power: int = model.power_use
	checks.build = model.build(Vector2(0, 58), "miner_dock").is_empty()
	checks.cost_and_power = model.materials == funds - 25 and model.power_use == power + 1
	var dock_id: String = model.structure_id_at(Vector2(0, 58))
	checks.parked = fleet.docking.status(1) == "parked" and fleet.docking.ships[1].dock_id == dock_id
	model.buy_ship("miner")
	model.buy_ship("miner")
	checks.capacity = fleet.docking.usage[dock_id].size() == 2 and fleet.docking.status(3) == "homeless"
	checks.message = fleet.docking.waiting_message().contains("no free Miner dock")
	fleet.register_asteroid(999, 18)
	checks.dispatch_parked = fleet.dispatch(999, 1).is_empty()
	checks.release_and_waiter = fleet.docking.status(1) == "working" and fleet.docking.status(3) == "parked" and fleet.docking.usage[dock_id].size() == 2
	var minerals: int = model.minerals
	for i in range(8): fleet.tick()
	checks.exact_mining = model.minerals == minerals + 18 and not fleet.jobs.has(1)
	checks.completed_full = fleet.docking.status(1) == "homeless"
	fleet.register_asteroid(1000, 18)
	checks.homeless_can_work = fleet.dispatch(1000, 1).is_empty()
	fleet.cancel_unit(1)
	fleet.remove_asteroid(1000)
	var before: Dictionary = store.snapshot()
	var error: String = store.restore(before)
	checks.roundtrip = error.is_empty() and store.snapshot() == before
	var bad: Dictionary = before.duplicate(true)
	var records: Dictionary = store._decode(bad.extensions.docking.ships)
	records[2].slot = 999
	bad.extensions.docking.ships = store._encode(records)
	checks.corruption_atomic = not store.restore(bad).is_empty() and store.snapshot() == before
	bad = before.duplicate(true)
	bad.extensions.docking.usage = store._encode({})
	checks.usage_validation = not store.restore(bad).is_empty() and store.snapshot() == before
	funds = model.materials
	var refund: int = model.module_refund(Vector2(0, 58))
	checks.demolition = model.demolish_module(Vector2(0, 58)).is_empty()
	checks.demolition_homeless = fleet.docking.usage.is_empty() and fleet.docking.status(2) == "homeless" and fleet.docking.status(3) == "homeless" and model.materials == funds + refund
	# Old saves have no dedicated docks or extension; the original Mining Ship
	# remains an autonomous mining module, not an extra parking/economy upgrade.
	model.build(Vector2(0, 58), "mining_ship")
	var legacy: Dictionary = store.snapshot()
	legacy.extensions.erase("docking")
	error = store.restore(legacy)
	checks.old_load = error.is_empty() and fleet.docking.docks().is_empty() and fleet.docking.status(1) == "homeless"
	checks.legacy_module_mines = fleet.mining_units().has(Vector2(0, 58))
	for id: int in model.ships.keys(): model.decommission_ship(id)
	# Every type is resolved from data, including a new synthetic role.
	var x: int = 1
	for kind: String in model.ship_catalog:
		model.build(Vector2(x * 58, 58), kind + "_dock")
		model.buy_ship(kind)
		checks["type " + kind] = fleet.docking.status(model.next_ship_id) == "parked"
		x += 1
	checks.scout_leaves = fleet.survey(5, "echo").is_empty() and fleet.docking.status(5) == "working"
	for i in range(6): fleet.tick()
	checks.scout_returns = fleet.docking.status(5) == "parked"
	model.add_minerals(18)
	checks.trade_leaves = fleet.trade(6, "lumen_envoy", "archive_data").is_empty() and fleet.docking.status(6) == "working"
	for i in range(7): fleet.tick()
	checks.trade_returns = fleet.docking.status(6) == "parked" and fleet.diplomacy.inventory.tech == 1
	model.build(Vector2(406, 58), "space_depot")
	checks.collector_leaves = fleet.collection.deploy(7).is_empty() and fleet.docking.status(7) == "working"
	fleet.cancel_unit(7)
	checks.collector_returns = fleet.docking.status(7) == "parked"
	model.build(Vector2(464, 58), "research_lab")
	fleet.diplomacy.inventory.tech = 2
	fleet.research.research("teleportation")
	model.build(Vector2(-87, -29), "teleport_gate")
	fleet._discover_region("venus")
	fleet.diplomacy.inventory.xenocrystal = 1
	checks.jump_leaves = fleet.transport.jump(Vector2(-87, -29), 8, "venus").is_empty() and fleet.docking.status(8) == "working"
	before = store.snapshot()
	checks.transit_roundtrip = store.restore(before).is_empty() and store.snapshot() == before
	for i in range(3): fleet.tick()
	checks.jump_arrival_homeless = fleet.docking.status(8) == "homeless" and fleet.docking.ships[8].region == "venus"
	checks.founding_still_works = fleet.outposts.found(8).is_empty() and fleet.docking.status(8) == "homeless"
	before = store.snapshot()
	checks.remote_roundtrip = store.restore(before).is_empty() and store.snapshot() == before
	model.ship_catalog["test_role"] = model.ship_catalog.scout.duplicate(true)
	model.ship_catalog.test_role.dock_type = "new_type"
	model.catalog["test_dock"] = model.catalog.scout_dock.duplicate(true)
	model.catalog.test_dock.docking = {"ship_type": "new_type", "capacity": 1}
	model.build(Vector2(348, 58), "test_dock")
	model.buy_ship("test_role")
	checks.data_only = fleet.docking.status(model.next_ship_id) == "parked"
	# Remote/foreign structures are fixtures only: no new remote-building command.
	fleet._discover_region("venus")
	model.locations.ships[4].region = "venus"
	fleet.changed.emit()
	checks.remote_no_home_parking = fleet.docking.status(4) == "homeless" and model.locations.ship_region(4) == "venus"
	model.locations.stations["fixture"] = {"id": "fixture", "owner": "player", "region": "venus"}
	var remote_id: String = model.locations.add_structure("fixture", "miner_dock", Vector2.ZERO)
	fleet.changed.emit()
	checks.remote_local_parking = fleet.docking.status(4) == "parked" and fleet.docking.ships[4].dock_id == remote_id
	model.locations.structures[remote_id].owner = "alien"
	fleet.changed.emit()
	checks.owner_required = fleet.docking.status(4) == "homeless"
	var failed: Array = []
	for name: String in checks:
		if not checks[name]: failed.append(name)
	print("Docking checks: ", checks.size() - failed.size(), "/", checks.size(), "; failures: ", failed)
	quit(0 if failed.is_empty() else 1)
