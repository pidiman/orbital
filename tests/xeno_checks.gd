extends RefCounted
const Supply = preload("res://scripts/sector_supply.gd")
const Store = preload("res://scripts/save_store.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var stock := Supply.new(model, fleet, 44)
	var store := Store.new(model, fleet, stock)
	model.materials = 1000
	for i in range(1, 5): model.build(Vector2(i * 58, 0), "solar")
	var before: int = model.materials
	var power: int = model.power_use
	checks.buy = model.buy_ship("xeno_miner").is_empty() and before - model.materials == 70 and model.power_use - power == 3
	var xeno: int = model.next_ship_id
	model.buy_ship("miner")
	var miner: int = model.next_ship_id
	checks.homeless = fleet.docking.ships[xeno].state == "homeless"
	checks.dock = model.build(Vector2(0, 58), "xeno_miner_dock").is_empty()
	checks.parked = fleet.docking.ships[xeno].state == "parked"
	for kind: String in stock.floating_rules.types: stock.floating_rules.types[kind].weight = 1 if kind == "xenocrystal" else 0
	stock.floating_rules.types.xenocrystal.amount_min = 3
	stock.floating_rules.types.xenocrystal.amount_max = 3
	stock._spawn_debris()
	var piece: int = stock.next_debris_id
	var target: int = stock.mining_target("home", piece)
	checks.no_click_credit = stock.salvage(piece) == 0 and fleet.diplomacy.inventory.xenocrystal == 0
	checks.ore_rejects_xeno = not fleet.dispatch(target, miner).is_empty()
	checks.xeno_rejects_ore = not fleet.dispatch(1, xeno).is_empty()
	checks.assign = fleet.dispatch(target, xeno).is_empty()
	checks.slot_freed = fleet.docking.ships[xeno].state == "working"
	checks.timers = fleet.jobs[xeno].duration == 20 and model.ship_catalog.miner.mining.seconds == 8
	checks.ore_assign = fleet.dispatch(1, miner).is_empty()
	for tick in range(8): fleet.tick()
	checks.ore_unchanged = model.minerals == 18 and fleet.diplomacy.inventory.xenocrystal == 0 and fleet.jobs[xeno].remaining == 12
	var snapshot: Dictionary = store.snapshot()
	var error: String = store.restore(snapshot)
	checks.roundtrip = error.is_empty() and snapshot == store.snapshot()
	print("Xeno restore: ", error)
	var invalid: Dictionary = snapshot.duplicate(true)
	# Change the saved ship's target resource binding without changing its pool.
	var decoded: Dictionary = store._decode(invalid.extensions.resource_mining.resource_targets)
	decoded[target].resource = "minerals"
	invalid.extensions.resource_mining.resource_targets = store._encode(decoded)
	checks.corrupt_atomic = not store.restore(invalid).is_empty() and snapshot == store.snapshot()
	# Freeze mission ticks while supply advances: a reserved node cannot expire.
	stock.floating_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/floating_resources.json"))
	stock.advance(65)
	checks.claimed_lifetime = fleet.asteroids.has(target) and stock.floating.home.pieces.has(piece)
	for tick in range(11): fleet.tick()
	checks.no_early_yield = fleet.diplomacy.inventory.xenocrystal == 0
	fleet.tick()
	checks.first_yield = fleet.diplomacy.inventory.xenocrystal == 1 and fleet.jobs[xeno].remaining == 20 and stock.floating.home.pieces[piece].amount == 2
	for tick in range(40): fleet.tick()
	checks.repeat_depleted = fleet.diplomacy.inventory.xenocrystal == 3 and not fleet.jobs.has(xeno) and not fleet.asteroids.has(target) and not stock.floating.home.pieces.has(piece)
	checks.parks_again = fleet.docking.ships[xeno].state == "parked"
	var legacy: Dictionary = store.snapshot()
	legacy.extensions.erase("resource_mining")
	checks.old_extension_optional = store.restore(legacy).is_empty()
	# Remote mining still requires physical travel and credits local storage.
	model.materials = 1000
	model.build(Vector2(0, -58), "research_lab")
	fleet.diplomacy.inventory.tech = 2
	fleet.research.research("teleportation")
	model.build(Vector2(-87, -29), "teleport_gate")
	model.buy_ship("jump_ship")
	var founder: int = model.next_ship_id
	fleet._discover_region("venus")
	fleet.diplomacy.inventory.xenocrystal = 100
	var gate := Vector2(-87, -29)
	checks.remote_launch = fleet.transport.jump(gate, founder, "venus").is_empty() and fleet.transport.jump(gate, xeno, "venus").is_empty()
	for tick in range(20): fleet.tick()
	checks.remote_found = fleet.outposts.found(founder).is_empty()
	stock.ensure_floating_region("venus")
	for kind: String in stock.floating_rules.types: stock.floating_rules.types[kind].weight = 1 if kind == "xenocrystal" else 0
	stock._spawn_debris(false, "venus")
	var remote_target: int = stock.mining_target("venus", stock.next_debris_id)
	checks.remote_assign = fleet.dispatch(remote_target, xeno).is_empty()
	var home_crystals: int = fleet.diplomacy.inventory.xenocrystal
	for tick in range(20): fleet.tick()
	var outpost: String = model.locations.outpost_at("venus", model.locations.rules.primary_station.owner)
	checks.remote_local_credit = model.locations.stations[outpost].inventory.xenocrystal == 1 and fleet.diplomacy.inventory.xenocrystal == home_crystals
	checks.remote_roundtrip = store.restore(store.snapshot()).is_empty()
	# Data-only hybrid uses the same resource filter and timer machinery.
	model.ship_catalog["hybrid"] = model.ship_catalog.xeno_miner.duplicate(true)
	model.ship_catalog.hybrid.mining.seconds = 25
	model.materials = 1000
	checks.hybrid = model.buy_ship("hybrid").is_empty()
	return checks
