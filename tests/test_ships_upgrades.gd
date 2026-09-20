extends SceneTree
const Fleet = preload("res://scripts/mining_fleet.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func fund(model: StationModel) -> void:
	model.collect(1000)
	model.add_minerals(100)

func _initialize() -> void:
	var model := StationModel.new()
	var fleet := Fleet.new(model)
	model.ticked.connect(fleet.tick)
	check(not model.buy_ship("miner").is_empty() and model.materials == 40, "unaffordable ship is atomic")
	model.collect(20)
	check(not model.buy_ship("miner").is_empty() and model.ships.is_empty(), "underpowered ship is atomic")
	check(model.build(Vector2(58, 0), "solar").is_empty(), "solar bootstrap")
	fund(model)
	var before: int = model.materials
	check(model.buy_ship("miner").is_empty(), "build independent miner")
	check(model.materials == before - 45 and model.power_balance() == 4, "miner costs and power")
	check(model.modules.size() == 2 and model.level == 1, "ships don't occupy cells or award colony levels")
	var miner: int = model.next_ship_id
	fleet.register_asteroid(1, 45)
	check(fleet.dispatch(1, miner).is_empty(), "specific miner assignment")
	check(not fleet.dispatch(1, miner).is_empty(), "duplicate assignment refused")
	var minerals_before: int = model.minerals
	for i in range(8):
		model.tick()
	check(model.minerals == minerals_before + 18 and fleet.jobs.has(miner), "first auto cycle retains assignment")
	check(fleet.asteroids[1].claimed and not fleet.remove_asteroid(1), "assigned asteroid remains reserved")
	for i in range(8):
		model.tick()
	check(model.minerals == minerals_before + 36 and fleet.jobs.has(miner), "second cycle runs without input")
	for i in range(8):
		model.tick()
	check(model.minerals == minerals_before + 45 and fleet.jobs.is_empty() and not fleet.asteroids.has(1), "final partial payload no overdraw")
	model.tick()
	check(model.minerals == minerals_before + 45, "no duplicate depleted credit")
	fund(model)
	check(model.buy_ship("scout").is_empty() and model.power_balance() == 3, "scout purchase power")
	var scout: int = model.next_ship_id
	check(fleet.survey(scout).is_empty(), "scout survey starts")
	check(not fleet.survey(scout).is_empty(), "busy scout can't duplicate survey")
	for i in range(4):
		model.tick()
	check(fleet.revealed_count() == 1, "survey timer required")
	model.tick()
	check(fleet.revealed_count() == 2 and fleet.survey_jobs.is_empty(), "adjacent sector revealed")
	check(fleet.survey(scout).is_empty(), "next sector can be surveyed")
	for i in range(int(fleet.survey_jobs[scout].duration)):
		model.tick()
	while fleet.revealed_count() < fleet.sectors.size():
		check(fleet.survey(scout).is_empty(), "remaining sector survey")
		for i in range(int(fleet.survey_jobs[scout].duration)):
			model.tick()
	check(fleet.revealed_count() == fleet.sectors.size() and not fleet.survey(scout).is_empty(), "all sectors revealed once")
	var solar := Vector2(58, 0)
	model.materials = 0
	var mineral_snapshot: int = model.minerals
	check(not model.upgrade_module(solar).is_empty() and model.tier_at(solar) == 1 and model.minerals == mineral_snapshot, "upgrade insufficient funds atomic")
	model.materials = 100
	model.minerals = 0
	check(not model.upgrade_module(solar).is_empty() and model.materials == 100 and model.tier_at(solar) == 1, "mineral-short upgrade is atomic")
	fund(model)
	var power_before: int = model.power_balance()
	before = model.materials
	minerals_before = model.minerals
	check(model.upgrade_module(solar).is_empty(), "solar upgrade")
	check(model.tier_at(solar) == 2 and model.power_balance() == power_before + 4, "solar output increases")
	check(model.materials == before - 30 and model.minerals == minerals_before - 8, "upgrade exact dual-resource cost")
	before = model.materials
	minerals_before = model.minerals
	check(not model.upgrade_module(solar).is_empty() and model.materials == before and model.minerals == minerals_before, "max tier no double spend")
	fund(model)
	check(model.upgrade_module(Vector2.ZERO).is_empty() and model.capacity == 125, "habitat extra capacity")
	fund(model)
	check(model.build(Vector2(0, 58), "storage").is_empty(), "build storage")
	fund(model)
	check(model.upgrade_module(Vector2(0, 58)).is_empty() and model.capacity == 275, "storage tier doubles bonus")
	fund(model)
	check(model.build(Vector2(-58, 0), "refinery").is_empty(), "build refinery")
	fund(model)
	check(model.upgrade_module(Vector2(-58, 0)).is_empty(), "refinery upgrade")
	model.materials = 0
	model.minerals = 10
	model.refinery_progress.clear()
	model.tick()
	check(model.materials == 0, "upgraded refinery waits")
	model.tick()
	check(model.materials == 6 and model.minerals == 8, "upgraded refinery converts after two ticks")
	# Extra tiers and ship types plug into the existing algorithms through data.
	model.catalog.solar.upgrades.append({"cost":{"materials":1,"minerals":1},"stats":{"power_output":12},"description":"test tier"})
	fund(model)
	check(model.upgrade_module(solar).is_empty() and model.tier_at(solar) == 3 and model.definition_at(solar).power_output == 12, "future tier needs only data")
	model.ship_catalog["custom_miner"] = model.ship_catalog.miner.duplicate(true)
	fund(model)
	check(model.buy_ship("custom_miner").is_empty() and fleet.mining_units().has(model.next_ship_id), "future ship capability works")
	fund(model)
	check(model.build(Vector2(116, 0), "mining_ship").is_empty(), "legacy mining dock alongside fleet")
	fleet.register_asteroid(101, 18)
	fleet.register_asteroid(102, 18)
	check(fleet.dispatch(101, miner).is_empty() and fleet.jobs.has(miner), "explicit assignment ignores legacy docks")
	check(fleet.dispatch(102).is_empty() and fleet.jobs.has(Vector2(116, 0)), "legacy shortcut still dispatches dock")
	model.ticked.disconnect(fleet.tick)
	check_continuous_positions()
	preload("res://tests/exploration_checks.gd").new().run(check)
	print("Ships/upgrades checks: %d passed / %d total" % [checks - failures.size(), checks])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check_continuous_positions() -> void:
	var station := StationModel.new()
	var solar := Vector2(58.0, 12.25)
	check(station.build(solar, "solar").is_empty(), "fractional edge placement accepted")
	check(station.modules.has(solar) and not station.modules.has(Vector2(58, 0)), "world coordinate stored without quantization")
	var before: int = station.materials
	check(not station.build(Vector2(57.5, 12.25), "solar").is_empty() and station.materials == before, "fractional overlap rejected atomically")
	check(not station.build(Vector2(116.25, 12.25), "solar").is_empty(), "fractional gap rejected")
	check(not station.build(Vector2.INF, "solar").is_empty(), "nonfinite position rejected")
	fund(station)
	check(station.upgrade_module(solar).is_empty() and station.definition_at(solar).power_output == 10, "fractional module upgrade works")
	fund(station)
	var refinery := Vector2(-58.0, -7.5)
	check(station.build(refinery, "refinery").is_empty(), "fractional refinery placement")
	station.materials = 0
	station.minerals = 2
	for index in range(3):
		station.tick()
	check(station.materials == 6 and station.refinery_progress.has(refinery), "fractional refinery ticks")
	fund(station)
	var dock := Vector2(0.25, 70.25)
	check(station.build(dock, "mining_ship").is_empty(), "fractional dock edge connection")
	var fleet := Fleet.new(station)
	fleet.register_asteroid(999, 18)
	check(fleet.dispatch(999).is_empty() and fleet.jobs.has(dock), "fractional dock dispatch")
	for index in range(8):
		fleet.tick()
	check(fleet.total_mined == 18 and fleet.jobs.is_empty(), "fractional dock completes mission")
