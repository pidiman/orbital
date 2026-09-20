extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Supply = preload("res://scripts/sector_supply.gd")

func make_store() -> Store:
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	model.ticked.connect(fleet.tick)
	return Store.new(model, fleet, Supply.new(model, fleet, 78231))

func run(check: Callable) -> void:
	var store: Store = make_store()
	var model: StationModel = store.model
	var fleet: MiningFleet = store.fleet
	var diplomacy: RefCounted = fleet.diplomacy
	model.build(Vector2(58, 0), "solar")
	model.collect(100)
	model.buy_ship("scout")
	var scout: int = model.next_ship_id
	model.collect(100)
	check.call(model.buy_ship("trader").is_empty() and model.power_balance() == 3, "Trade Ship costs materials and consumes power without a grid cell")
	var trader: int = model.next_ship_id
	check.call(diplomacy.contacts.is_empty() and not fleet.trade(trader, "lumen_envoy", "archive_gift").is_empty(), "no trade before alien discovery")
	check.call(fleet.survey(scout, "echo").is_empty(), "Scout sent to alien anomaly")
	for i in range(5):
		model.tick()
	check.call(diplomacy.contacts.is_empty(), "alien contacts hidden until arrival")
	model.tick()
	check.call(diplomacy.contacts.size() == 2 and diplomacy.factions.lumen.met and diplomacy.factions.concord.met, "anomaly establishes two faction contacts")
	check.call(diplomacy.factions.lumen.standing == 0 and diplomacy.history.is_empty(), "initial standing neutral")
	check.call(not fleet.trade(scout, "lumen_envoy", "archive_gift").is_empty(), "Scout cannot trade without capability")
	check.call(not fleet.survey(trader, "dawn").is_empty(), "Trade Ship is not implicitly a Scout")
	var before: Dictionary = store.snapshot()
	check.call(not fleet.trade(trader, "lumen_envoy", "archive_data").is_empty() and before == store.snapshot(), "insufficient cargo rejected atomically")
	model.add_minerals(60)
	check.call(fleet.trade(trader, "lumen_envoy", "archive_data").is_empty() and model.minerals == 42, "trade launches and escrows exact cargo")
	check.call(store.dirty and diplomacy.jobs[trader].remaining == 7 and diplomacy.inventory.tech == 0, "trade triggers autosave and waits for travel")
	before = store.snapshot()
	check.call(not fleet.trade(trader, "lumen_envoy", "archive_data").is_empty() and before == store.snapshot(), "trade spam cannot double charge")
	model.tick()
	model.tick()
	store.path = "user://orbital-trade-test-%d.json" % OS.get_process_id()
	check.call(store.save_game().is_empty(), "active trade written to actual v2 JSON")
	var restored: Store = make_store()
	restored.path = store.path
	check.call(restored.load_game().is_empty() and restored.snapshot() == store.snapshot(), "active cargo timer factions and extension round trip exactly")
	for i in range(5):
		model.tick()
		restored.model.tick()
	check.call(restored.snapshot() == store.snapshot(), "original and restored trade complete identically")
	check.call(diplomacy.inventory.tech == 1 and diplomacy.factions.lumen.standing == 4 and diplomacy.history.size() == 1 and diplomacy.jobs.is_empty(), "delivery grants Tech standing and one history entry")
	model.tick()
	check.call(diplomacy.inventory.tech == 1 and diplomacy.history.size() == 1, "no duplicate reward after arrival")
	check.call(store.save_game().is_empty() and restored.load_game().is_empty() and restored.snapshot() == store.snapshot(), "completed trade round trip")
	model.collect(100)
	before = store.snapshot()
	check.call(not fleet.trade(trader, "prism_envoy", "prism_crystals").is_empty() and before == store.snapshot(), "standing gate blocks rare exchange atomically")
	check.call(fleet.trade(trader, "prism_envoy", "prism_gift").is_empty(), "Materials cargo earns goodwill")
	for i in range(7):
		model.tick()
	check.call(diplomacy.factions.concord.standing == 8, "goodwill unlocks advanced offer")
	check.call(fleet.trade(trader, "prism_envoy", "prism_crystals").is_empty(), "unlocked dual-resource exchange launches")
	for i in range(7):
		model.tick()
	check.call(diplomacy.inventory.xenocrystal == 2 and diplomacy.factions.concord.standing == 11, "rare goods and standing delivered")
	# Hybrid capabilities compose: all dispatch paths share one occupancy rule.
	model.ship_catalog.trader["survey"] = model.ship_catalog.scout.survey.duplicate(true)
	model.ship_catalog.trader["mining"] = model.ship_catalog.miner.mining.duplicate(true)
	model.collect(100)
	fleet.trade(trader, "lumen_envoy", "archive_gift")
	fleet.register_asteroid(998, 30)
	check.call(not fleet.survey(trader, "dawn").is_empty() and not fleet.dispatch(998, trader).is_empty() and fleet.idle_count() == 0, "trading hybrid cannot mine or survey")
	var materials_before: int = model.materials
	var refund: int = model.ship_refund(trader)
	model.decommission_ship(trader)
	check.call(model.materials == materials_before + refund + 20 and diplomacy.jobs.is_empty() and diplomacy.history.back().result == "cancelled", "decommission refunds escrow plus hull and frees power")
	for i in range(10):
		model.tick()
	check.call(diplomacy.inventory.tech == 1 and diplomacy.factions.lumen.standing == 4, "cancelled trade never pays out")
	model.collect(100)
	model.buy_ship("trader")
	trader = model.next_ship_id
	fleet.survey(trader, "dawn")
	check.call(not fleet.trade(trader, "lumen_envoy", "archive_gift").is_empty() and not fleet.dispatch(998, trader).is_empty(), "surveying hybrid cannot trade or mine")
	fleet.cancel_unit(trader)
	fleet.dispatch(998, trader)
	check.call(not fleet.trade(trader, "lumen_envoy", "archive_gift").is_empty() and not fleet.survey(trader, "dawn").is_empty(), "mining hybrid cannot trade or survey")
	fleet.cancel_unit(trader)
	fleet.remove_asteroid(998)
	model.ship_catalog.trader.erase("survey")
	model.ship_catalog.trader.erase("mining")
	# An old v2 save with previously logged anomalies receives contacts once.
	var legacy: Dictionary = store.snapshot()
	legacy.extensions.erase("alien_trade")
	for sector: Dictionary in legacy.state.fleet.sectors:
		sector.contents = sector.contents.filter(func(content: Dictionary) -> bool: return content.get("anomaly_id", "") != "ion_chorus")
		for content: Dictionary in sector.contents:
			content.erase("anomaly_id")
	var legacy_error: String = restored.restore(legacy)
	if not legacy_error.is_empty(): print("LEGACY ERROR: " + legacy_error)
	check.call(legacy_error.is_empty() and restored.fleet.diplomacy.contacts.size() == 2, "old v2 logged anomaly acquires contacts without resurvey")
	var upgraded: Dictionary = restored.snapshot()
	check.call(upgraded.version == 2 and upgraded.extensions.alien_trade.schema_version == 1 and restored.restore(upgraded).is_empty() and upgraded == restored.snapshot(), "additive v2 upgrade is stable and idempotent")
	fleet.survey(scout, "twilight")
	for i in range(7):
		model.tick()
	check.call(diplomacy.inventory.tech == 2, "non-alien anomaly has a one-time research reward")
	diplomacy.discover(fleet.sector_by_id("twilight"))
	check.call(diplomacy.inventory.tech == 2, "anomaly rewards never duplicate")
	var valid: Dictionary = store.snapshot()
	valid.extensions.alien_trade["future_relations"] = {"treaty": "preserve"}
	var extension_error: String = restored.restore(valid)
	if not extension_error.is_empty(): print("EXTENSION ERROR: " + extension_error)
	check.call(extension_error.is_empty() and restored.snapshot().extensions.alien_trade.future_relations.treaty == "preserve", "unknown extension fields preserved")
	var intact: Dictionary = restored.snapshot()
	var broken: Dictionary = valid.duplicate(true)
	broken.extensions.alien_trade.factions.lumen.standing = "bad"
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "invalid standing rejected atomically")
	broken = valid.duplicate(true)
	broken.extensions.alien_trade.schema_version = 999
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "future breaking trade schema rejected atomically")
	model.collect(100)
	fleet.trade(trader, "lumen_envoy", "archive_gift")
	broken = store.snapshot()
	broken.extensions.alien_trade.jobs["$entries"][0].value.remaining = -1
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "invalid trade timer rejected atomically")
	broken = store.snapshot()
	broken.extensions.alien_trade.jobs["$entries"][0].value.cost = {"power": 3}
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "invalid escrow resource rejected atomically")
	broken = store.snapshot()
	broken.extensions.alien_trade.contacts.erase("lumen_envoy")
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "orphaned trade contact rejected atomically")
	broken = store.snapshot()
	broken.extensions.alien_trade = {}
	check.call(not restored.restore(broken).is_empty() and restored.snapshot() == intact, "empty present extension is corruption, not a legacy reset")
	# Recovery retains all escrow even if normal storage is full at cancellation.
	model.collect(100)
	materials_before = model.materials
	refund = model.ship_refund(trader)
	model.decommission_ship(trader)
	check.call(model.materials == materials_before + refund + 20 and model.materials > model.capacity, "full-storage decommission preserves cargo and hull refund")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
