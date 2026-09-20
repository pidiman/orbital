extends SceneTree
const Fleet = preload("res://scripts/mining_fleet.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func fund_and_build(model: StationModel, cell: Vector2, kind: String) -> void:
	model.collect(1000)
	check(model.build(cell, kind).is_empty(), "build " + kind)

func _initialize() -> void:
	var model := StationModel.new()
	var fleet := Fleet.new(model)
	model.ticked.connect(fleet.tick)
	fleet.register_asteroid(1, 18)
	check(not fleet.dispatch(1).is_empty(), "no ship rejection")
	fund_and_build(model, Vector2(58, 0), "solar")
	fund_and_build(model, Vector2(0, 58), "mining_ship")
	check(model.power_balance() == 4, "ship consumes two power")
	check(fleet.dispatch(1).is_empty(), "dispatch succeeds")
	check(not fleet.dispatch(1).is_empty(), "duplicate target rejected")
	check(not fleet.remove_asteroid(1), "active target held in sector")
	fleet.register_asteroid(2, 18)
	check(not fleet.dispatch(2).is_empty(), "busy ship rejected")
	for i in range(7):
		model.tick()
	check(model.minerals == 0 and fleet.jobs.size() == 1, "no early reward")
	model.tick()
	check(model.minerals == 18 and fleet.jobs.is_empty(), "timed reward and ship return")
	check(not fleet.asteroids.has(1), "depleted target removed")
	model.tick()
	check(model.minerals == 18, "completion credited once")
	check(fleet.remove_asteroid(2), "unclaimed target can leave")
	check(not fleet.dispatch(2).is_empty(), "departed target rejected")
	fund_and_build(model, Vector2(-58, 0), "refinery")
	check(model.power_balance() == 1, "refinery consumes three power")
	var before: int = model.materials
	model.tick()
	model.tick()
	check(model.materials == before and model.minerals == 18, "refining waits three ticks")
	model.tick()
	check(model.materials == before + 6 and model.minerals == 16, "exact conversion")
	model.collect(1000)
	for i in range(10):
		model.tick()
	check(model.materials == model.capacity and model.minerals == 16, "full storage loses no minerals")
	model.materials = 97
	for i in range(3):
		model.tick()
	check(model.materials == 97 and model.minerals == 16, "partial output room does not waste minerals")
	model.materials = 94
	for i in range(3):
		model.tick()
	check(model.materials == 100 and model.minerals == 14, "resumes when output fits")
	model.materials = 20
	model.minerals = 1
	for i in range(10):
		model.tick()
	check(model.materials == 20 and model.minerals == 1, "insufficient input never goes negative")
	# Optional capabilities work on new catalog IDs, without hard-coded module names.
	model.catalog["second_ship"] = model.catalog.mining_ship.duplicate(true)
	fund_and_build(model, Vector2(0, -58), "solar")
	fund_and_build(model, Vector2(58, 58), "second_ship")
	fleet.register_asteroid(3, 18)
	fleet.register_asteroid(4, 18)
	check(fleet.dispatch(3).is_empty() and fleet.dispatch(4).is_empty(), "parallel ships reserve separate targets")
	check(fleet.jobs.size() == 2 and fleet.idle_count() == 0, "fleet counts")
	# Remove minerals to isolate mission totals from automatic refining.
	model.materials = model.capacity
	model.minerals = 0
	for i in range(8):
		model.tick()
	check(model.minerals == 36 and fleet.jobs.is_empty(), "two missions complete independently")
	fund_and_build(model, Vector2(-58, 58), "refinery")
	model.materials = 20
	model.minerals = 4
	model.refinery_progress = {}
	for i in range(3):
		model.tick()
	check(model.materials == 32 and model.minerals == 0, "parallel refineries consume exact input")
	print("Mining checks: %d passed / %d total" % [checks - failures.size(), checks])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	model.ticked.disconnect(fleet.tick)
	quit(0 if failures.is_empty() else 1)
