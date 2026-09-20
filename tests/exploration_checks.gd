extends RefCounted

func run(check: Callable) -> void:
	var model := StationModel.new()
	model.build(Vector2(58, 0), "solar")
	model.collect(1000)
	model.buy_ship("scout")
	var scout: int = model.next_ship_id
	model.buy_ship("scout")
	var scout2: int = model.next_ship_id
	model.collect(1000)
	model.buy_ship("miner")
	var miner: int = model.next_ship_id
	var fleet := MiningFleet.new(model)
	check.call(fleet.asteroids.is_empty() and fleet.sector_state("dawn") == "unexplored", "hidden sectors have no mineable targets")
	check.call(not fleet.survey(miner, "dawn").is_empty(), "only Scouts explore")
	check.call(not fleet.survey(scout, "missing").is_empty() and fleet.survey_jobs.is_empty(), "unknown destination rejected")
	check.call(not fleet.survey(scout, "home").is_empty(), "home cannot be resurveyed")
	check.call(fleet.survey(scout, "dawn").is_empty() and fleet.sector_state("dawn") == "exploring", "selected destination reserves mission")
	check.call(not fleet.survey(scout, "echo").is_empty() and not fleet.survey(scout2, "dawn").is_empty(), "busy Scout and duplicate destination rejected")
	check.call(fleet.survey(scout2, "quiet").is_empty(), "different Scouts explore concurrently")
	for i in range(4):
		fleet.tick()
	check.call(fleet.sector_state("quiet") == "revealed" and fleet.sector_by_id("quiet").asteroid_ids.is_empty(), "empty sector reveals no ore")
	check.call(fleet.sector_state("dawn") == "exploring" and fleet.asteroids.is_empty() and fleet.survey_jobs[scout].remaining == 1, "no early discovery before travel ends")
	fleet.tick()
	var ids: Array = fleet.sector_by_id("dawn").asteroid_ids
	check.call(fleet.sector_state("dawn") == "revealed" and ids.size() == 1 and not fleet.survey_jobs.has(scout), "arrival reveals exactly one deposit and frees Scout")
	var target: int = ids[0]
	check.call(fleet.asteroids[target].sector_id == "dawn" and fleet.asteroids[target].minerals == 54, "discovery records sector provenance and ore")
	check.call(not fleet.remove_asteroid(target), "discovered deposits persist without rendering")
	check.call(not fleet.survey(scout, "dawn").is_empty() and fleet.asteroids.size() == 1, "revealed sectors cannot duplicate rewards")
	check.call(fleet.dispatch(target, miner).is_empty(), "Miner accepts discovered sector target")
	for i in range(8):
		fleet.tick()
	check.call(model.minerals == 18 and fleet.jobs.has(miner), "discovery delivers Minerals and repeats")
	for i in range(16):
		fleet.tick()
	check.call(model.minerals == 54 and not fleet.asteroids.has(target) and fleet.jobs.is_empty(), "sector deposit depletes exactly once")
	check.call(fleet.survey(scout, "echo").is_empty(), "Scout reusable for anomaly survey")
	for i in range(6):
		fleet.tick()
	check.call(fleet.sector_state("echo") == "revealed" and fleet.sector_by_id("echo").contents[0].type == "anomaly" and fleet.asteroids.is_empty(), "anomaly logged without false ore reward")
	fleet.sectors.append({"id":"test","name":"Extra sector","revealed":false,"reachable_from":[],"travel_seconds":2,"contents":[{"type":"asteroid","minerals":9},{"type":"asteroid","minerals":11}]})
	check.call(not fleet.survey(scout, "test").is_empty(), "unreachable sector rejected")
	fleet.sector_by_id("test").reachable_from.append("home")
	check.call(fleet.survey(scout, "test").is_empty(), "data-only new route works")
	fleet.tick()
	fleet.tick()
	check.call(fleet.sector_by_id("test").asteroid_ids.size() == 2 and fleet.asteroids.size() == 2, "data-only multiple discoveries receive distinct IDs")
