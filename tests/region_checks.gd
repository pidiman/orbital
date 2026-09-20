extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Regions = preload("res://scripts/region_model.gd")
const Supply = preload("res://scripts/sector_supply.gd")

func make_store() -> Store:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	model.ticked.connect(fleet.tick)
	return Store.new(model, fleet, Supply.new(model, fleet, 92))

func tick(store: Store, count: int) -> void:
	for index in range(count):
		store.model.tick()

func run(check: Callable) -> void:
	var first := Regions.new(42)
	var second := Regions.new(42)
	first.generate("venus")
	first.generate("mars")
	second.generate("mars")
	second.generate("venus")
	check.call(first.records == second.records, "per-region RNG independent of discovery order")
	var before: Dictionary = first.records.duplicate(true)
	check.call(not first.generate("venus") and first.records == before, "region content generated only once")
	var different := Regions.new(43)
	different.generate("venus")
	check.call(different.records.venus.contents != first.records.venus.contents, "different seeds produce different regional content")
	check.call(first.catalog.mars.coordinate is Array and first.catalog.home.structures.primary_station and not first.allows_outposts("venus") and first.records.venus.structures.is_empty(), "abstract coordinates and separate future structure slots")
	var store: Store = make_store()
	var model: StationModel = store.model
	var fleet: MiningFleet = store.fleet
	var regions: RefCounted = fleet.regions
	model.build(Vector2(58, 0), "solar")
	model.collect(100)
	model.buy_ship("scout")
	var scout: int = model.next_ship_id
	model.collect(100)
	model.buy_ship("miner")
	var miner: int = model.next_ship_id
	model.collect(100)
	model.buy_ship("scout")
	var scout2: int = model.next_ship_id
	fleet.survey(scout, "dawn")
	tick(store, 5)
	var legacy: Dictionary = store.snapshot()
	legacy.extensions.erase("regions")
	var old_core: Dictionary = legacy.state.duplicate(true)
	check.call(regions.current_region == "home" and regions.is_discovered("home") and not regions.is_discovered("mars"), "new session at fixed unlocked Home")
	before = store.snapshot()
	check.call(not regions.jump("venus").is_empty() and store.snapshot() == before, "undiscovered jump rejected atomically")
	check.call(not fleet.survey_region(scout, "pluto").is_empty() and regions.survey_jobs.is_empty(), "Pluto not adjacent to Home")
	check.call(not fleet.survey_region(miner, "venus").is_empty(), "only survey-capable ships discover regions")
	check.call(fleet.survey_region(scout, "venus").is_empty() and regions.survey_jobs[scout].origin == "home", "adjacent region survey records origin")
	check.call(not fleet.survey_region(scout2, "venus").is_empty(), "duplicate region survey reservation blocked")
	check.call(not fleet.survey(scout, "echo").is_empty() and fleet.unit_busy(scout), "regional Scout cannot start a legacy mission")
	tick(store, 2)
	check.call(not regions.is_discovered("venus") and regions.records.venus.contents.is_empty(), "regional content remains hidden during travel")
	store.path = "user://orbital-regions-test-%d.json" % OS.get_process_id()
	check.call(store.save_game().is_empty(), "regional survey saves to actual JSON")
	var loaded: Store = make_store()
	loaded.path = store.path
	check.call(loaded.load_game().is_empty() and loaded.snapshot() == store.snapshot(), "in-flight regional survey RNG and origin round trip")
	tick(store, 4)
	tick(loaded, 4)
	check.call(loaded.snapshot() == store.snapshot(), "restored survey generates identical content and rewards")
	check.call(regions.is_discovered("venus") and regions.records.venus.asteroid_ids.size() >= 2 and regions.records.venus.contents.size() >= 3 and regions.survey_jobs.is_empty(), "Scout arrival unlocks deposits and anomalies")
	check.call(fleet.diplomacy.inventory.tech + fleet.diplomacy.inventory.xenocrystal > 0, "regional anomalies award useful trade inventory once")
	before = store.snapshot()
	fleet._discover_region("venus")
	check.call(before == store.snapshot(), "repeated discovery cannot duplicate ore or anomaly rewards")
	var modules: Dictionary = model.modules.duplicate(true)
	check.call(regions.jump("venus").is_empty() and regions.current_region == "venus" and model.modules == modules, "jump changes location while station stays anchored")
	var resources_before: int = model.materials
	check.call(not model.build(Vector2(0, 58), "solar").is_empty() and model.materials == resources_before and model.modules == modules, "construction rejected away from Home at model boundary")
	var target: int = regions.records.venus.asteroid_ids[0]
	check.call(fleet.dispatch(target, miner).is_empty(), "regional deposits use existing Miner mechanics")
	tick(store, 3)
	model.tick_elapsed = 0.375
	check.call(store.save_game().is_empty() and loaded.load_game().is_empty() and loaded.snapshot() == store.snapshot(), "remote location active mining and fractional phase round trip")
	check.call(loaded.fleet.regions.current_region == "venus" and loaded.fleet.regions.records.venus == regions.records.venus, "load restores current region content and RNG bits")
	check.call(regions.jump("home").is_empty(), "unlocked adjacent return route")
	var minerals_before: int = model.minerals
	tick(store, 5)
	check.call(model.minerals > minerals_before and regions.current_region == "home", "regional mining continues after leaving region")
	check.call(fleet.survey_region(scout, "mars").is_empty(), "Mars reachable from Home graph")
	tick(store, 7)
	check.call(regions.jump("mars").is_empty() and fleet.survey_region(scout, "pluto").is_empty(), "Mars unlocks non-Home multi-hop Pluto route")
	check.call(regions.jump("home").is_empty(), "can move while Scout follows recorded route")
	tick(store, 9)
	check.call(regions.is_discovered("pluto") and not regions.jump("pluto").is_empty(), "survey completes from original route; jumps still obey graph")
	regions.jump("mars")
	check.call(regions.jump("pluto").is_empty() and not regions.jump("home").is_empty(), "multi-hop movement requires adjacent unlocked legs")
	check.call(store.save_game().is_empty() and loaded.load_game().is_empty() and loaded.snapshot() == store.snapshot(), "all planets generated and Pluto location persist")
	var stable: Dictionary = regions.records.duplicate(true)
	for i in range(5):
		regions.jump("mars")
		regions.jump("pluto")
	check.call(stable == regions.records, "repeated jumps never reroll or reset content")
	check.call(loaded.restore(legacy).is_empty() and loaded.fleet.regions.current_region == "home" and loaded.snapshot().state == old_core, "old v2 defaults Home with existing content exactly intact")
	loaded.fleet.sectors.append({"id":"chain","name":"Linked sector","revealed":false,"travel_seconds":2,"reachable_from":["dawn"],"contents":[]})
	check.call(loaded.fleet.sector_reachable("chain") and loaded.fleet.survey(scout, "chain").is_empty(), "legacy sector reachability uses revealed predecessors, not Home literal")
	loaded.fleet.cancel_unit(scout)
	check.call(loaded.fleet.survey_region(scout, "venus").is_empty(), "old-save Scouts can explore new graph")
	loaded.model.decommission_ship(scout)
	check.call(loaded.fleet.regions.survey_jobs.is_empty() and not loaded.fleet.regions.is_discovered("venus") and loaded.fleet.regions.state("venus") == "unknown", "decommission cancels regional mission and frees reservation")
	var good: Dictionary = store.snapshot()
	good.extensions.regions["future_navigation"] = {"mode":"preserved"}
	check.call(loaded.restore(good).is_empty() and loaded.snapshot().extensions.regions.future_navigation.mode == "preserved", "unknown region extension fields retained")
	var intact: Dictionary = loaded.snapshot()
	var bad: Dictionary = good.duplicate(true)
	bad.extensions.regions.current_region = "missing"
	check.call(not loaded.restore(bad).is_empty() and loaded.snapshot() == intact, "unknown current region rejected atomically")
	bad = good.duplicate(true)
	bad.extensions.regions.records.venus.rng_state = "invalid"
	check.call(not loaded.restore(bad).is_empty() and loaded.snapshot() == intact, "invalid regional RNG rejected atomically")
	bad = good.duplicate(true)
	bad.extensions.regions.records.venus.asteroid_ids[0] = -999999
	check.call(not loaded.restore(bad).is_empty() and loaded.snapshot() == intact, "orphaned regional deposit IDs rejected atomically")
	bad = good.duplicate(true)
	bad.extensions.regions.schema_version = 999
	check.call(not loaded.restore(bad).is_empty() and loaded.snapshot() == intact, "unsupported regional extension rejected atomically")
	bad = good.duplicate(true)
	bad.extensions.erase("regions")
	check.call(not loaded.restore(bad).is_empty() and loaded.snapshot() == intact, "regional ore cannot exist without its ownership extension")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
