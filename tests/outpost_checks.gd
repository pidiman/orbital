extends RefCounted
const Setup = preload("res://tests/location_checks.gd")
const Store = preload("res://scripts/save_store.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var store: Store = Setup.make_store()
	var model: StationModel = store.model
	var fleet: MiningFleet = store.fleet
	model.materials = 2000
	for point: Vector2 in [Vector2(58, 0), Vector2(116, 0), Vector2(174, 0), Vector2(232, 0)]: model.build(point, "solar")
	model.build(Vector2(0, 58), "research_lab")
	fleet.diplomacy.inventory.tech = 2
	fleet.research.research("teleportation")
	var gate := Vector2(-87, -29)
	checks.gate_built = model.build(gate, "teleport_gate").is_empty()
	var materials: int = model.materials
	var power: int = model.power_use
	checks.buy_jump = model.buy_ship("jump_ship").is_empty() and model.materials == materials - int(model.ship_catalog.jump_ship.cost) and model.power_use == power + int(model.ship_catalog.jump_ship.power_use)
	var jump: int = model.next_ship_id
	model.buy_ship("miner")
	var miner: int = model.next_ship_id
	checks.cannot_found_home = fleet.outposts.found(jump).contains("non-Home")
	checks.cannot_found_wrong_role = not fleet.outposts.found(miner).is_empty()
	checks.undiscovered = not fleet.transport.jump(gate, jump, "venus").is_empty()
	fleet._discover_region("venus")
	fleet._discover_region("mars")
	fleet._discover_region("pluto")
	fleet.diplomacy.inventory.xenocrystal = 3
	checks.graph = fleet.transport.jump(gate, jump, "pluto").contains("direct gate route")
	checks.jump = fleet.transport.jump(gate, jump, "venus").is_empty() and fleet.diplomacy.inventory.xenocrystal == 2
	var before: Dictionary = store.snapshot()
	checks.transit_blocks_founding = not fleet.outposts.found(jump).is_empty() and store.snapshot() == before
	checks.transit_roundtrip = store.restore(before).is_empty() and store.snapshot() == before
	Setup.tick(store, 3)
	checks.location = model.locations.ship_region(jump) == "venus" and fleet.regions.viewed_region == "home"
	model.materials = 59
	before = store.snapshot()
	checks.cost_rejection_atomic = fleet.outposts.found(jump).contains("60 Home Materials") and store.snapshot() == before
	model.materials = 100
	checks.found = fleet.outposts.found(jump).is_empty() and model.materials == 40
	var outpost_id: String = model.locations.outpost_at("venus", "player")
	checks.own_identity = outpost_id != "station:home" and not outpost_id.is_empty()
	if outpost_id.is_empty(): return checks
	var station: Dictionary = model.locations.stations[outpost_id]
	checks.local_inventory = station.inventory == {"minerals": 0} and station.region == "venus" and station.owner == "player"
	checks.structure_identity = model.locations.structures[station.structure_id].station_id == outpost_id and model.locations.structures[station.structure_id].region == "venus"
	checks.founding_state = station.founding.state == "established" and station.founding.ship_id == jump and station.founding.paid.materials == 60 and model.locations.ships[jump].founding.station_id == outpost_id
	checks.hull_survives = model.ships.has(jump) and model.locations.ships[jump].station_id == "station:home"
	before = store.snapshot()
	for i in range(10): fleet.outposts.found(jump)
	checks.duplicate_atomic = store.snapshot() == before
	checks.founding_roundtrip = store.restore(before).is_empty() and store.snapshot() == before
	var target: int = fleet.regions.records.venus.asteroid_ids[0]
	checks.home_cannot_mine_remote = fleet.dispatch(target, miner).contains("Teleport Gate")
	checks.miner_jump = fleet.transport.jump(gate, miner, "venus").is_empty() and fleet.diplomacy.inventory.xenocrystal == 1
	checks.transit_cannot_mine = not fleet.dispatch(target, miner).is_empty()
	Setup.tick(store, 3)
	checks.wrong_region_rejected = not fleet.dispatch(fleet.regions.records.mars.asteroid_ids[0], miner).is_empty()
	fleet.asteroids[target].minerals = 54 # Three complete cycles for the persistence fixture.
	checks.remote_dispatch = fleet.dispatch(target, miner).is_empty()
	var route: Dictionary = fleet.mining_assignment(miner)
	checks.local_route = route.policy == "local_outpost" and route.destination.station_id == outpost_id and route.origin_region == "venus" and route.target.region == "venus"
	var home_ore: int = model.minerals
	var initial_ore: int = fleet.asteroids[target].minerals
	Setup.tick(store, 7)
	checks.no_early_credit = model.locations.stations[outpost_id].inventory.minerals == 0
	Setup.tick(store, 1)
	checks.local_credit_only = model.locations.stations[outpost_id].inventory.minerals == 18 and model.minerals == home_ore and fleet.asteroids[target].minerals == initial_ore - 18
	before = store.snapshot()
	var loaded: Store = Setup.make_store()
	var error: String = loaded.restore(JSON.parse_string(JSON.stringify(before)))
	if not error.is_empty(): push_error(error)
	checks.mining_roundtrip = error.is_empty() and loaded.snapshot() == before
	if not error.is_empty(): return checks
	Setup.tick(store, 8)
	Setup.tick(loaded, 8)
	checks.deterministic_continuation = loaded.snapshot() == store.snapshot()
	checks.repeat_local_only = model.locations.stations[outpost_id].inventory.minerals == 36 and model.minerals == home_ore
	fleet.cancel_unit(miner)
	checks.cancel_stays_local = model.locations.ship_region(miner) == "venus" and not fleet.asteroids[target].claimed
	checks.no_remote_building = fleet.regions.jump("venus").is_empty() and not model.build(Vector2(58, 58), "solar").is_empty()
	checks.no_material_hauling = store.supply.debris_in("venus").is_empty()
	fleet.regions.jump("home")
	model.materials = 100
	model.buy_ship("miner")
	var home_miner: int = model.next_ship_id
	store.supply._spawn_asteroid()
	checks.home_dispatch = fleet.dispatch(store.supply.next_home_id, home_miner).is_empty()
	Setup.tick(store, 8)
	checks.home_credit = model.minerals == home_ore + 18 and model.locations.stations[outpost_id].inventory.minerals == 36
	before = store.snapshot()
	store.path = "user://orbital-outpost-%d.json" % OS.get_process_id()
	loaded.path = store.path
	checks.disk_roundtrip = store.save_game().is_empty() and loaded.load_game().is_empty() and loaded.snapshot() == before
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	var bad: Dictionary = before.duplicate(true)
	bad.extensions.world_locations.stations[outpost_id].inventory.minerals = -1
	checks.bad_inventory_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == before
	bad = before.duplicate(true)
	bad.extensions.world_locations.stations[outpost_id].region = "home"
	checks.bad_ownership_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == before
	bad = before.duplicate(true)
	bad.extensions.erase("outposts")
	checks.missing_extension_rejected = not loaded.restore(bad).is_empty() and loaded.snapshot() == before
	# A second region gets a distinct owner and never shares Venus inventory.
	model.materials = 300
	model.buy_ship("jump_ship")
	var second_jump: int = model.next_ship_id
	fleet.diplomacy.inventory.xenocrystal = 2
	checks.second_jump = fleet.transport.jump(gate, second_jump, "mars").is_empty()
	Setup.tick(store, 3)
	checks.second_found = fleet.outposts.found(second_jump).is_empty()
	var second_outpost: String = model.locations.outpost_at("mars", "player")
	checks.separate_stores = second_outpost != outpost_id and model.locations.stations[second_outpost].inventory.minerals == 0 and model.locations.stations[outpost_id].inventory.minerals == 36
	model.buy_ship("miner")
	var second_miner: int = model.next_ship_id
	checks.second_miner_jump = fleet.transport.jump(gate, second_miner, "mars").is_empty()
	Setup.tick(store, 3)
	var second_target: int = fleet.regions.records.mars.asteroid_ids[0]
	checks.second_local_dispatch = fleet.dispatch(second_target, second_miner).is_empty()
	home_ore = model.minerals
	Setup.tick(store, 8)
	checks.second_local_credit = model.locations.stations[second_outpost].inventory.minerals == 18 and model.locations.stations[outpost_id].inventory.minerals == 36 and model.minerals == home_ore
	before = store.snapshot()
	checks.multiple_outposts_roundtrip = loaded.restore(before).is_empty() and loaded.snapshot() == before
	checks.decommission_founder = model.decommission_ship(jump).is_empty() and model.locations.stations.has(outpost_id)
	before = store.snapshot()
	checks.historical_founder_roundtrip = loaded.restore(before).is_empty() and loaded.snapshot() == before
	# Build a genuine pre-outpost snapshot with an active legacy remote route.
	var old: Store = Setup.make_store()
	old.model.materials = 100
	old.model.build(Vector2(58, 0), "solar")
	old.model.buy_ship("miner")
	old.fleet._discover_region("venus")
	var old_target: int = old.fleet.regions.records.venus.asteroid_ids[0]
	old.fleet.jobs = {1: {"target": old_target, "remaining": 3, "duration": 8, "yield": 18, "repeat": true}}
	old.fleet.asteroids[old_target].claimed = true
	var legacy: Dictionary = old.snapshot()
	legacy.extensions.erase("outposts")
	legacy.extensions.erase("docking")
	checks.old_graph_migration = loaded.restore(legacy).is_empty() and loaded.fleet.jobs.is_empty() and not loaded.fleet.asteroids[old_target].claimed and loaded.model.locations.stations.size() == 1 and loaded.model.minerals == old.model.minerals and loaded.fleet.asteroids[old_target].minerals == old.fleet.asteroids[old_target].minerals
	checks.migration_notice = loaded.migration_notice.contains("ore preserved")
	legacy.extensions.erase("world_locations")
	checks.old_v2_migration = loaded.restore(legacy).is_empty() and loaded.fleet.jobs.is_empty() and loaded.model.locations.ship_region(1) == "home"
	before = loaded.snapshot()
	checks.migration_resave = loaded.restore(before).is_empty() and loaded.snapshot() == before and loaded.migration_notice.is_empty()
	var hybrid: Store = Setup.make_store()
	hybrid.model.materials = 100
	hybrid.model.build(Vector2(58, 0), "solar")
	hybrid.model.ship_catalog["hybrid"] = hybrid.model.ship_catalog.miner.duplicate(true)
	hybrid.model.ship_catalog.hybrid["founding"] = {"outpost": "mining_outpost"}
	hybrid.model.buy_ship("hybrid")
	hybrid.fleet._discover_region("venus")
	hybrid.model.locations.ships[1].region = "venus"
	hybrid.model.locations.outpost_catalog.mining_outpost.cost.materials = 0
	checks.data_only_hybrid_founding = hybrid.fleet.outposts.found(1).is_empty()
	checks.data_only_hybrid_mining = hybrid.fleet.dispatch(hybrid.fleet.regions.records.venus.asteroid_ids[0], 1).is_empty()
	return checks
