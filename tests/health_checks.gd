extends RefCounted
const Supply = preload("res://scripts/sector_supply.gd")

func run(check: Callable) -> void:
	_recovery(check)
	_supply(check)

func _recovery(check: Callable) -> void:
	var model := StationModel.new()
	var positions: Array[Vector2] = []
	for x in range(-4, 5):
		for y in range(-4, 5):
			if x != 0 or y != 0:
				positions.append(Vector2(x * 58, y * 58))
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.x) + absf(a.y) < absf(b.x) + absf(b.y))
	var built: bool = true
	for point: Vector2 in positions:
		model.collect(10000)
		built = built and model.build(point, "solar").is_empty()
	for index in range(66):
		built = built and model.demolish_module(positions[index]).is_empty()
		model.collect(10000)
		built = built and model.build(positions[index], "storage").is_empty()
	for index in range(5):
		model.collect(10000)
		built = built and model.buy_ship("scout").is_empty()
	model.materials = 0
	check.call(built and model.modules.size() == 81 and model.power_balance() == 0 and model.minerals == 0, "reproduce full station zero-power without Minerals using legal builds")
	var all_blocked: bool = true
	for point: Vector2 in positions:
		all_blocked = all_blocked and not model.placement_error(point, "solar").is_empty()
	check.call(all_blocked, "full station initially cannot place solar")
	var removed: Vector2 = positions[0]
	check.call(model.demolish_module(removed).is_empty() and model.materials == 12 and model.power_balance() == 1 and not model.modules.has(removed), "interior demolition frees space power and refund")
	model.collect(8)
	check.call(model.build(removed, "solar").is_empty() and model.power_balance() == 6 and model.modules.size() == 81, "full station recovers through salvage and replacement solar")
	check.call(not model.demolish_module(Vector2.ZERO).is_empty(), "starting core protected from refund exploit")
	var poor := StationModel.new()
	poor.buy_ship("scout")
	var scout: int = poor.next_ship_id
	poor.materials = 0
	check.call(poor.power_balance() == 0 and not poor.buy_ship("miner").is_empty(), "reproduce ship power exhaustion")
	check.call(poor.decommission_ship(scout).is_empty() and poor.power_balance() == 1 and poor.materials == 17, "ship sale frees power with exact refund")
	check.call(not poor.decommission_ship(scout).is_empty() and poor.materials == 17, "duplicate ship sale cannot mint materials")
	poor.collect(3)
	check.call(poor.build(Vector2(58, 0), "solar").is_empty(), "power-exhausted colony can bootstrap solar again")
	poor.collect(1000)
	poor.buy_ship("miner")
	var miner: int = poor.next_ship_id
	var fleet := MiningFleet.new(poor)
	fleet.register_asteroid(123, 18)
	fleet.dispatch(123, miner)
	check.call(poor.decommission_ship(miner).is_empty() and fleet.jobs.is_empty() and not fleet.asteroids[123].claimed, "busy miner sale cancels mission and releases target")
	for index in range(10):
		fleet.tick()
	check.call(poor.minerals == 0, "cancelled mission never awards ghost Minerals")
	poor.collect(1000)
	poor.buy_ship("scout")
	scout = poor.next_ship_id
	fleet.survey(scout, "dawn")
	poor.decommission_ship(scout)
	check.call(fleet.survey_jobs.is_empty() and fleet.sector_state("dawn") == "unexplored", "busy Scout sale releases sector")
	poor.collect(1000)
	poor.build(Vector2(0, 58), "mining_ship")
	fleet.dispatch(123)
	poor.demolish_module(Vector2(0, 58))
	check.call(fleet.jobs.is_empty() and not fleet.asteroids[123].claimed, "mining dock demolition releases mission")
	poor.collect(1000)
	poor.build(Vector2(0, 58), "refinery")
	poor.refinery_progress[Vector2(0, 58)] = 2
	poor.demolish_module(Vector2(0, 58))
	check.call(not poor.refinery_progress.has(Vector2(0, 58)), "demolition removes refinery progress")
	poor.collect(1000)
	poor.minerals = 8
	poor.upgrade_module(Vector2(58, 0))
	check.call(poor.module_refund(Vector2(58, 0)) == 25, "Materials investment includes upgrade refund")
	poor.demolish_module(Vector2(58, 0))
	check.call(not poor.module_tiers.has(Vector2(58, 0)) and not poor.demolish_module(Vector2(58, 0)).is_empty(), "tier cleanup and duplicate demolition rejection")
	var storage := StationModel.new()
	storage.collect(1000)
	storage.build(Vector2(58, 0), "storage")
	storage.collect(1000)
	storage.demolish_module(Vector2(58, 0))
	check.call(storage.capacity == 100 and storage.materials == 187 and storage.collect(8) == 0 and storage.materials == 187, "capacity loss preserves stock/refund and never causes negative salvage")
	var powered := StationModel.new()
	powered.build(Vector2(58, 0), "solar")
	powered.collect(1000)
	powered.build(Vector2(0, 58), "refinery")
	var before: int = powered.materials
	check.call(not powered.demolish_module(Vector2(58, 0)).is_empty() and powered.materials == before and powered.power_balance() == 3, "unsafe generator removal rejected atomically")
	powered.catalog.refinery.refund_ratio = 0.25
	check.call(powered.module_refund(Vector2(0, 58)) == 10, "per-definition refund policy is data driven")

func _supply(check: Callable) -> void:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var supply := Supply.new(model, fleet, 42)
	check.call(supply is RefCounted and supply.debris.size() == 5 and supply.home_asteroids.size() == 1, "headless supply initializes without nodes")
	var amounts_valid: bool = true
	for piece: Dictionary in supply.debris.values():
		amounts_valid = amounts_valid and piece.amount >= 8 and piece.amount <= 14
	check.call(amounts_valid and fleet.asteroids[1].minerals == 18, "configured salvage and ore amounts")
	var before: Vector2 = supply.home_asteroids[1].position
	supply.advance(2.95)
	check.call(supply.debris.size() == 5 and supply.home_asteroids[1].position.x > before.x, "headless drift and spawn delay")
	supply.advance(0.05)
	check.call(supply.next_debris_id == 6, "debris spawns at three seconds")
	supply.advance(9.0)
	check.call(supply.next_home_id == 2 and supply.home_asteroids.size() == 2, "home asteroid spawns at twelve seconds")
	var id: int = supply.debris.keys()[0]
	var amount: int = supply.debris[id].amount
	model.materials = model.capacity - 3
	check.call(supply.salvage(id) == 3 and supply.debris[id].amount == amount - 3, "partial salvage preserves remainder")
	check.call(supply.salvage(id) == 0 and supply.debris[id].amount == amount - 3, "full storage preserves salvage")
	model.materials = 0
	check.call(supply.salvage(id) == amount - 3 and not supply.debris.has(id) and supply.salvage(id) == 0, "salvage removes exhausted debris without duplicate award")
	var expiring_id: int = supply.debris.keys()[0]
	supply.debris[expiring_id].position.x = 2.0
	supply.advance(0.05)
	check.call(not supply.debris.has(expiring_id) and supply.salvage(expiring_id) == 0, "expired debris cannot pay out")
	fleet.asteroids[1].claimed = true
	supply.home_asteroids[1].position.x = 2.0
	supply.advance(1.0)
	check.call(supply.home_asteroids.has(1) and fleet.asteroids.has(1), "claimed asteroid cannot expire")
	fleet.asteroids[1].claimed = false
	supply.advance(0.05)
	check.call(not supply.home_asteroids.has(1) and not fleet.asteroids.has(1), "unclaimed asteroid expires in logic")
	fleet.asteroids.erase(2)
	supply.advance(0.05)
	check.call(not supply.home_asteroids.has(2), "mined asteroid cleaned without rendering")
	var same_model := StationModel.new()
	var same_fleet := MiningFleet.new(same_model)
	var first := Supply.new(same_model, same_fleet, 100)
	var other_model := StationModel.new()
	var second := Supply.new(other_model, MiningFleet.new(other_model), 100)
	first.advance(30.0)
	for index in range(600):
		second.advance(0.05)
	check.call(first.debris == second.debris and first.home_asteroids == second.home_asteroids, "seeded supply independent of frame subdivision")
	first.advance(1000.0)
	check.call(first.debris.size() <= int(first.rules.debris.max_count) and first.home_asteroids.size() <= int(first.rules.asteroids.max_count) and first.next_home_id > 3, "long-run population caps and replenishment")
	var config: Dictionary = supply.rules.duplicate(true)
	config.debris.amount_min = 27
	config.debris.amount_max = 27
	config.debris.initial_count = 2
	config.asteroids.minerals = 36
	var custom_model := StationModel.new()
	var custom_fleet := MiningFleet.new(custom_model)
	var custom := Supply.new(custom_model, custom_fleet, 0, config)
	check.call(custom.debris.size() == 2 and custom.debris[1].amount == 27 and custom_fleet.asteroids[1].minerals == 36, "supply amounts and populations data driven")
