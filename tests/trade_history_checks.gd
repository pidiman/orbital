extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Supply = preload("res://scripts/region_supply.gd")
const TRADE_COUNT: int = 24000
const EXPECTED_LIMIT: int = 256

func run(check: Callable) -> void:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var supply := Supply.new(model, fleet, 71)
	var store := Store.new(model, fleet, supply)
	model.build(Vector2(58, 0), "solar")
	model.collect(100)
	model.buy_ship("trader")
	var trader: int = model.next_ship_id
	fleet._discover_region("venus")
	fleet._discover_region("mars")
	var discovery_tech: int = int(fleet.diplomacy.inventory.tech)
	model.minerals = TRADE_COUNT * 18
	var trade: RefCounted = fleet.diplomacy
	var all_launched: bool = true
	for index in range(TRADE_COUNT):
		all_launched = fleet.trade(trader, "lumen_envoy", "archive_data").is_empty() and all_launched
		if index % 2 == 0:
			for tick in range(7): trade.tick()
		else:
			trade.cancel(trader)
	check.call(all_launched, "24,000 legal completed/cancelled trades simulated")
	check.call(trade.history.size() == EXPECTED_LIMIT, "trade log bounded to 256 entries")
	check.call(trade.history[0].id == TRADE_COUNT - EXPECTED_LIMIT + 1 and trade.history.back().id == TRADE_COUNT, "only oldest history trimmed; latest IDs and order retained")
	check.call(trade.history[-2].result == "completed" and trade.history.back().result == "cancelled", "recent completion and cancellation details retained")
	check.call(trade.inventory.tech == TRADE_COUNT / 2 + discovery_tech and trade.factions.lumen.standing == 100 and model.minerals == TRADE_COUNT * 9, "rewards standing and cancellation refunds survive trimming")
	# Include active escrow in the checkpoint: it must never be part of the log cap.
	fleet.trade(trader, "lumen_envoy", "archive_data")
	var expected: Dictionary = store.snapshot()
	store.path = "user://orbital-history-test-%d.json" % OS.get_process_id()
	check.call(store.save_game().is_empty(), "long-running colony saves to actual JSON")
	var file := FileAccess.open(store.path, FileAccess.READ)
	var bytes: int = file.get_length()
	file.close()
	print("Trade history soak: %d trades; %d retained; save %d bytes (8 MiB loader limit)" % [TRADE_COUNT, trade.history.size(), bytes])
	check.call(bytes < 256 * 1024, "trade-heavy save remains below 256 KiB, far below 8 MiB limit")
	check.call(store.load_game().is_empty() and store.snapshot() == expected, "trade-heavy save round-trips exactly, including active escrow")
	var goods_before: Dictionary = trade.inventory.duplicate(true)
	var flags_before: Array = trade.processed_anomalies.duplicate()
	for region_id: String in fleet.regions.records: trade.discover_region(region_id, fleet.regions.records[region_id])
	check.call(trade.inventory == goods_before and trade.processed_anomalies == flags_before, "trim/load never repeats one-time anomaly rewards")
	# A valid older v2 log is accepted, then reduced to the same recent window.
	var legacy: Dictionary = store.snapshot()
	legacy.extensions.alien_trade.history = []
	for index in range(600):
		var entry: Dictionary = legacy.extensions.alien_trade.jobs["$entries"][0].value.duplicate(true)
		entry.id = index + 1
		entry.remaining = 0
		entry.result = "completed"
		entry.tick = 0
		entry.standing_delta = 0
		legacy.extensions.alien_trade.history.append(entry)
	var intact: Dictionary = store.snapshot()
	var corrupt: Dictionary = legacy.duplicate(true)
	corrupt.extensions.alien_trade.history[0].result = "invalid"
	check.call(not store.restore(corrupt).is_empty() and store.snapshot() == intact, "old log validated before trimming; corrupt discarded prefix rejected atomically")
	check.call(store.restore(legacy).is_empty() and trade.history.size() == EXPECTED_LIMIT and trade.history[0].id == 345 and trade.history.back().id == 600, "oversized legacy log normalized to latest 256 on load")
	check.call(trade.inventory == goods_before and trade.processed_anomalies == flags_before and trade.next_trade_id == TRADE_COUNT + 1 and trade.jobs.has(trader), "legacy trim preserves progression allocator and active trade")
	expected = store.snapshot()
	check.call(store.save_game().is_empty() and store.load_game().is_empty() and store.snapshot() == expected, "trimmed legacy history saves and reloads exactly")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
