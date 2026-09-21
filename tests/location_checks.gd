extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Supply = preload("res://scripts/sector_supply.gd")
const Locations = preload("res://scripts/world_locations.gd")

static func make_store() -> Store:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	model.ticked.connect(fleet.tick)
	return Store.new(model, fleet, Supply.new(model, fleet, 17))

static func tick(store: Store, count: int) -> void:
	for index in range(count): store.model.tick()

static func legacy(store: Store) -> Dictionary:
	var result: Dictionary = store.snapshot()
	result.extensions.erase("world_locations")
	result.extensions.erase("outposts")
	var jobs: Dictionary = store.supply.collection.jobs.duplicate(true)
	for job: Dictionary in jobs.values():
		job.erase("depot_id")
		job.erase("destination")
	result.extensions.material_collection.jobs = store._encode(jobs)
	jobs = store.fleet.transport.jobs.duplicate(true)
	for job: Dictionary in jobs.values(): job.erase("gate_id")
	result.extensions.gate_transport.jobs = store._encode(jobs)
	return result

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var store: Store = make_store()
	var model: StationModel = store.model
	var fleet: MiningFleet = store.fleet
	var world: RefCounted = model.locations
	model.materials = 2000
	model.minerals = 100
	for point: Vector2 in [Vector2(58, 0), Vector2(116, 0), Vector2(174, 0), Vector2(232, 0)]:
		checks["solar_" + str(point)] = model.build(point, "solar").is_empty()
	var dock := Vector2(0, -58)
	var depot := Vector2(58, 58)
	var lab := Vector2(116, 58)
	var gate := Vector2(-87, -29)
	checks.dock = model.build(dock, "mining_ship").is_empty()
	checks.depot = model.build(depot, "space_depot").is_empty()
	checks.lab = model.build(lab, "research_lab").is_empty()
	fleet.diplomacy.inventory.tech = 2
	checks.research = fleet.research.research("teleportation").is_empty()
	checks.gate = model.build(gate, "teleport_gate").is_empty()
	for kind: String in ["miner", "material_ship", "scout", "miner"]:
		checks["buy_" + kind] = model.buy_ship(kind).is_empty()
	var miner: int = 1
	var collector: int = 2
	var departing: int = 4
	var solar_id: String = model.structure_id_at(Vector2(58, 0))
	checks.upgrade_identity = model.upgrade_module(Vector2(58, 0)).is_empty() and model.structure_id_at(Vector2(58, 0)) == solar_id and world.structures[solar_id].state.tier == 2
	checks.explicit_structures = world.structures.values().all(func(record: Dictionary) -> bool: return record.region == "home" and record.owner == "player" and record.station_id == "station:home" and record.id is String)
	checks.explicit_ships = world.ships.values().all(func(record: Dictionary) -> bool: return record.region == "home" and record.owner == "player" and record.station_id == "station:home" and record.transit.is_empty())
	# Identity-only model fixture: no construction API or new outpost gameplay.
	var isolated := Locations.new()
	isolated.stations["station:test"] = {"id": "station:test", "owner": "player", "region": "venus"}
	var home_id: String = isolated.add_structure("station:home", "habitat", Vector2.ZERO)
	var other_id: String = isolated.add_structure("station:test", "habitat", Vector2.ZERO)
	checks.same_position_distinct_identity = home_id != other_id and isolated.structure_at("station:test", Vector2.ZERO) == other_id and isolated.structure_at("station:home", Vector2.ZERO) == home_id
	fleet._discover_region("venus")
	fleet._discover_region("mars")
	fleet._discover_region("pluto")
	fleet.regions.jump("mars")
	fleet.regions.jump("pluto")
	checks.view_is_not_location = fleet.regions.viewed_region == "pluto" and world.ship_region(miner) == "home" and world.structures[solar_id].region == "home"
	checks.remote_construction_still_blocked = not model.build(Vector2(174, 58), "solar").is_empty()
	var target: int = fleet.regions.records.pluto.asteroid_ids[0]
	checks.cross_region_dispatch_rejected = not fleet.dispatch(target, miner).is_empty()
	store.supply._spawn_asteroid()
	target = store.supply.next_home_id
	fleet.asteroids[target].minerals = 90
	checks.home_dispatch_while_viewing_remote = fleet.dispatch(target, miner).is_empty()
	var route: Dictionary = fleet.mining_assignment(miner)
	checks.explicit_home_route = route.policy == "local" and route.origin_region == "home" and route.target.region == "home" and route.destination == {"station_id": "station:home", "region": "home"} and route.cargo.minerals == 0
	var ore: int = model.minerals
	var amount: int = mini(fleet.asteroids[target].minerals, route.job.yield)
	tick(store, int(route.job.duration) - 1)
	checks.no_early_payment = model.minerals == ore
	tick(store, 1)
	checks.same_yield_and_timing = model.minerals == ore + amount and world.ship_region(miner) == "home"
	store.supply._spawn_asteroid()
	checks.dock_dispatch = fleet.dispatch(store.supply.next_home_id).is_empty()
	checks.stable_dock_assignment = fleet.mining_assignments.has("structure/" + model.structure_id_at(dock)) and fleet.mining_assignment(dock).policy == "local"
	checks.collection_deploy = store.supply.collection.deploy(collector).is_empty()
	store.supply.debris = {1: {"position": Vector2(0.5, 0.5), "velocity": Vector2.ZERO, "amount": 10}}
	store.supply.floating.clear()
	store.supply.next_debris_id = 1
	store.supply.collection.advance(0.1)
	var job: Dictionary = store.supply.collection.jobs[collector]
	checks.collection_binding = job.depot_id == model.structure_id_at(depot) and job.destination == world.ship_destination(collector) and job.region == world.ship_region(collector) and job.cargo == 1
	checks.region_supply_isolation = store.supply.debris_in("venus").is_empty() and store.supply.debris_in("home").size() == 1
	model.materials = model.capacity
	store.supply.collection.advance(10)
	checks.wait_unchanged = job.waiting and job.cargo == 1 and store.supply.collection.waiting_message().contains("storage full")
	fleet.diplomacy.inventory.xenocrystal = 1
	checks.gate_launch = fleet.transport.jump(gate, departing, "venus").is_empty() and fleet.diplomacy.inventory.xenocrystal == 0
	checks.canonical_transit = world.ships[departing].transit == {"origin": "home", "destination": "venus"} and world.ship_region(departing) == "home" and fleet.transport.jobs[departing].gate_id == model.structure_id_at(gate)
	var saved: Dictionary = store.snapshot()
	var loaded: Store = make_store()
	var restore_error: String = loaded.restore(JSON.parse_string(JSON.stringify(saved)))
	if not restore_error.is_empty(): push_error(restore_error)
	checks.new_roundtrip = restore_error.is_empty() and loaded.snapshot() == saved
	var old: Dictionary = legacy(store)
	restore_error = loaded.restore(old)
	if not restore_error.is_empty():
		push_error(restore_error)
		checks.legacy_active_migration = false
		return checks
	checks.legacy_active_migration = restore_error.is_empty() and loaded.snapshot().state == saved.state and loaded.model.locations.ships[departing].transit == world.ships[departing].transit
	checks.legacy_collection_migration = loaded.supply.collection.jobs[collector].waiting and loaded.supply.collection.jobs[collector].cargo == 1 and loaded.supply.collection.jobs[collector].depot_id == loaded.model.structure_id_at(depot)
	checks.legacy_routes_migrate = loaded.fleet.mining_assignment(miner).policy == "local" and loaded.fleet.mining_assignment(dock).actor.id == loaded.model.structure_id_at(dock)
	var migrated: Dictionary = loaded.snapshot()
	checks.migrated_roundtrip = loaded.restore(migrated).is_empty() and loaded.snapshot() == migrated
	# Compare migrated legacy execution with the same active canonical checkpoint.
	checks.reload_reference = store.restore(saved).is_empty()
	model.materials -= 2
	loaded.model.materials -= 2
	store.supply.collection.advance(0.1)
	loaded.supply.collection.advance(0.1)
	tick(store, 8)
	tick(loaded, 8)
	checks.migration_continuation = store.snapshot() == loaded.snapshot()
	checks.arrived_location = world.ship_region(departing) == "venus" and world.ships[departing].transit.is_empty() and fleet.regions.viewed_region == "pluto"
	checks.remote_miner_still_blocked = not fleet.dispatch(target, departing).is_empty()
	checks.resume_unchanged = store.supply.collection.jobs[collector].cargo == 0 and model.structure_state(depot).material_depot.delivered == 1
	checks.legacy_arrival_preserved = loaded.restore(legacy(store)).is_empty() and loaded.model.locations.ship_region(departing) == "venus"
	# Stable IDs survive demolition, reuse of a cell, and save/load allocator recovery.
	fleet.regions.current_region = "home"
	model.materials = 200
	checks.alternate_depot = model.build(Vector2(174, 58), "space_depot").is_empty()
	var old_depot_id: String = model.structure_id_at(depot)
	checks.demolish = model.demolish_module(depot).is_empty()
	model.materials = 200
	checks.rebuild_new_identity = model.build(depot, "space_depot").is_empty() and model.structure_id_at(depot) != old_depot_id
	store.supply.collection.advance(0.01)
	checks.rebind_rebuilt_depot = store.supply.collection.jobs[collector].depot_id == model.structure_id_at(depot) and store.supply.collection.jobs[collector].depot == depot
	checks.remove_alternate_depot = model.demolish_module(Vector2(174, 58)).is_empty()
	saved = store.snapshot()
	checks.stable_ids_roundtrip = loaded.restore(saved).is_empty() and loaded.model.locations.structures == world.structures and loaded.model.locations.next_structure_id == world.next_structure_id
	store.path = "user://orbital-location-test-%d.json" % OS.get_process_id()
	loaded.path = store.path
	checks.identity_disk_roundtrip = store.save_game().is_empty() and loaded.load_game().is_empty() and loaded.snapshot() == saved
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	var baseline: Dictionary = loaded.snapshot()
	var bad: Dictionary = saved.duplicate(true)
	bad.extensions.world_locations.structures[solar_id].region = "venus"
	checks.corrupt_region_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == baseline
	bad = saved.duplicate(true)
	bad.extensions.world_locations.structures[solar_id].owner = "other"
	checks.corrupt_owner_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == baseline
	bad = saved.duplicate(true)
	bad.extensions.world_locations.next_structure_id = 0
	checks.corrupt_allocator_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == baseline
	bad = saved.duplicate(true)
	bad.extensions.world_locations.mining_assignments = {}
	checks.corrupt_assignment_atomic = not loaded.restore(bad).is_empty() and loaded.snapshot() == baseline
	# Pre-refactor saves could retain launch/drop-off positions after demolition,
	# including positions now occupied by another kind of module.
	fleet.diplomacy.inventory.xenocrystal = 1
	checks.second_transit = fleet.transport.jump(gate, 3, "venus").is_empty()
	checks.remove_in_transit = model.demolish_module(gate).is_empty()
	model.materials = 200
	checks.reuse_gate_cell = model.build(Vector2(-58, 0), "solar").is_empty()
	checks.legacy_removed_gate = loaded.restore(legacy(store)).is_empty() and loaded.fleet.transport.jobs[3].gate_id == ""
	tick(loaded, 3)
	checks.legacy_removed_gate_arrives = loaded.model.locations.ship_region(3) == "venus"
	checks.remove_active_depot = model.demolish_module(depot).is_empty()
	model.materials = 200
	checks.reuse_depot_cell = model.build(depot, "solar").is_empty()
	checks.legacy_removed_depot = loaded.restore(legacy(store)).is_empty() and loaded.supply.collection.jobs[collector].depot_id == ""
	loaded.supply.collection.advance(0.1)
	checks.migrated_missing_depot_waits = loaded.supply.collection.jobs[collector].waiting
	var fresh: Store = make_store()
	fresh.model.materials = 100
	fresh.model.build(Vector2(58, 0), "solar")
	fresh.model.buy_ship("miner")
	old = legacy(fresh)
	old.extensions.erase("gate_transport")
	old.extensions.erase("regions")
	checks.old_home_defaults = loaded.restore(old).is_empty() and loaded.model.locations.structures.values().all(func(record: Dictionary) -> bool: return record.region == "home") and loaded.fleet.regions.viewed_region == "home" and loaded.model.locations.ship_region(1) == "home" and loaded.model.locations.ships[1].station_id == "station:home"
	return checks
