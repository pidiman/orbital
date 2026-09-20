extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Supply = preload("res://scripts/sector_supply.gd")

func make_store() -> Store:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	model.ticked.connect(fleet.tick)
	return Store.new(model, fleet, Supply.new(model, fleet, 78231))

func step(store: Store, delta: float) -> void:
	store.supply.advance(delta)
	store.model.tick_elapsed += delta
	while store.model.tick_elapsed >= 1.0:
		store.model.tick_elapsed -= 1.0
		store.model.tick()

func fund(store: Store) -> void:
	store.model.collect(10000)

func run(check: Callable) -> void:
	var original: Store = make_store()
	original.path = "user://orbital-persistence-test-%d.json" % OS.get_process_id()
	var model: StationModel = original.model
	model.build(Vector2(58, 12.25), "solar")
	fund(original)
	model.build(Vector2(-58, -7.5), "solar")
	fund(original)
	model.build(Vector2(0, -58), "refinery")
	fund(original)
	model.build(Vector2(0, 58), "storage")
	fund(original)
	model.build(Vector2(116, 12.25), "mining_ship")
	fund(original)
	model.buy_ship("miner")
	var miner: int = model.next_ship_id
	fund(original)
	model.buy_ship("scout")
	var scout: int = model.next_ship_id
	original.fleet.survey(scout, "dawn")
	step(original, 5.0)
	var target: int = original.fleet.sector_by_id("dawn").asteroid_ids[0]
	original.fleet.survey(scout, "echo")
	original.fleet.dispatch(target, miner)
	original.fleet.dispatch(1)
	model.minerals = 30
	fund(original)
	model.upgrade_module(Vector2(58, 12.25))
	step(original, 1.375)
	original.preserved = {"extensions": {"alien_relations": {"test_faction": 12}, "trade_history": [{"resource":"minerals", "amount":4}]}, "future_metadata": {"retained": true}}
	var before: Dictionary = original.snapshot()
	check.call(model.tick_elapsed > 0 and original.fleet.jobs.size() == 2 and original.fleet.survey_jobs.size() == 1 and not model.refinery_progress.is_empty(), "save fixture includes concurrent dock/Miner/Scout/refinery jobs")
	check.call(original.save_game().is_empty() and FileAccess.file_exists(original.path), "JSON file written in user directory")
	var loaded: Store = make_store()
	loaded.path = original.path
	var error: String = loaded.load_game()
	check.call(error.is_empty(), "load versioned file: " + error)
	if loaded.snapshot() != before:
		print("ROUNDTRIP DIFF: " + difference(before, loaded.snapshot()))
	check.call(loaded.snapshot() == before, "exact canonical model state round trip through JSON file")
	check.call(loaded.model.modules.has(Vector2(58, 12.25)) and loaded.model.tier_at(Vector2(58, 12.25)) == 2, "fractional world positions and tiers preserved")
	check.call(loaded.model.power_balance() == model.power_balance() and loaded.model.level == model.level and loaded.model.materials == model.materials and loaded.model.minerals == model.minerals, "resources power capacity and colony level restored")
	check.call(loaded.supply.rng.seed == original.supply.rng.seed and loaded.supply.rng.state == original.supply.rng.state, "64-bit random seed/state exact")
	for index in range(25):
		step(original, 0.5)
		step(loaded, 0.5)
	if loaded.snapshot() != original.snapshot():
		print("EVOLUTION DIFF: " + difference(original.snapshot(), loaded.snapshot()))
	check.call(loaded.snapshot() == original.snapshot(), "resumed jobs and future random supply evolve identically")
	check.call(loaded.fleet.sector_state("echo") == "revealed" and loaded.model.total_refined > 0 and loaded.fleet.total_mined > 0, "loaded mining refining and survey jobs finish")
	var future: Dictionary = before.duplicate(true)
	future.version = 3
	future.min_reader_version = 2
	future.state.station["future_optional_field"] = {"kept":true}
	check.call(loaded.restore(future).is_empty() and loaded.snapshot().state.station.future_optional_field.kept and loaded.snapshot().version == 3 and loaded.snapshot().extensions == future.extensions, "compatible future additions preserved without downgrade")
	var legacy: Dictionary = before.duplicate(true)
	legacy.version = 1
	legacy.min_reader_version = 1
	legacy.state.station.erase("tick_elapsed")
	legacy.erase("extensions")
	check.call(loaded.restore(legacy).is_empty() and loaded.model.tick_elapsed == 0 and loaded.snapshot().version == 2 and loaded.snapshot().extensions.alien_trade.schema_version == 1, "v1 to v2 migration adds clock phase and extensions")
	var intact: Dictionary = loaded.snapshot()
	var incompatible: Dictionary = before.duplicate(true)
	incompatible.version = 3
	incompatible.min_reader_version = 3
	check.call(not loaded.restore(incompatible).is_empty() and loaded.snapshot() == intact, "incompatible future version rejected atomically")
	var broken: Dictionary = before.duplicate(true)
	broken.state.station.materials = "broken"
	check.call(not loaded.restore(broken).is_empty() and loaded.snapshot() == intact, "wrong typed resource rejected without partial load")
	broken = before.duplicate(true)
	broken.state.fleet.jobs["$entries"][0].value.target = 987654
	check.call(not loaded.restore(broken).is_empty() and loaded.snapshot() == intact, "orphaned mining reservation rejected atomically")
	broken = before.duplicate(true)
	broken.state.station.tick_elapsed = 1.5
	check.call(not loaded.restore(broken).is_empty() and loaded.snapshot() == intact, "invalid clock phase rejected")
	broken = before.duplicate(true)
	broken.state.station.modules["$entries"][0].key.value["$vector2"] = [0]
	check.call(not loaded.restore(broken).is_empty() and loaded.snapshot() == intact, "malformed Vector2 rejected")
	# Real corrupt-file path must not be overwritten by automatic saves.
	var file := FileAccess.open(original.path, FileAccess.WRITE)
	file.store_string("{ damaged")
	file.close()
	check.call(not loaded.load_game().is_empty() and loaded.autosave_blocked and loaded.snapshot() == intact, "corrupt JSON preserves session and pauses autosave")
	loaded.request_autosave()
	loaded.advance(20)
	check.call(FileAccess.get_file_as_string(original.path) == "{ damaged", "autosave cannot overwrite failed-load checkpoint")
	check.call(loaded.save_game().is_empty() and not loaded.autosave_blocked, "explicit Save can replace a damaged checkpoint")
	loaded.model.collect(8)
	loaded.request_autosave()
	loaded.advance(0.01)
	var resumed: Store = make_store()
	resumed.path = original.path
	check.call(resumed.load_game().is_empty() and resumed.snapshot() == loaded.snapshot(), "deferred autosave captures current complete models")
	var missing: Store = make_store()
	missing.path = "user://no-orbital-save-%d.json" % OS.get_process_id()
	check.call(not missing.load_game().is_empty(), "missing save gives recoverable error")
	check.call(not FileAccess.file_exists(original.path + ".tmp"), "successful atomic save leaves no temporary file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(original.path))
	print("Persistence user directory: " + ProjectSettings.globalize_path("user://"))

func difference(a: Variant, b: Variant, path: String = "root") -> String:
	if a == b:
		return ""
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not b.has(key):
				return path + ".missing " + str(key)
			var diff: String = difference(a[key], b[key], path + "." + str(key))
			if not diff.is_empty():
				return diff
		return path + ": extra keys " + str(b.keys())
	if a is Array and b is Array:
		if a.size() != b.size():
			return path + ": length mismatch"
		for index in range(a.size()):
			var diff: String = difference(a[index], b[index], path + "[%d]" % index)
			if not diff.is_empty():
				return diff
	return "%s: %s (%s) != %s (%s)" % [path, JSON.stringify(a, "", false, true), typeof(a), JSON.stringify(b, "", false, true), typeof(b)]
