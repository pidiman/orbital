extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m: StationModel = game.model
	var f = game.fleet
	var supply = game.supply
	m.materials = 5000
	for x in range(1, 12): m.build(Vector2(x * 58, 0), "solar")
	m.build(Vector2(0, 58), "space_depot")
	var ids: Dictionary = {}
	for kind: String in m.ship_catalog:
		m.buy_ship(kind)
		ids[kind] = m.next_ship_id
	f._discover_region("venus")
	for id: int in m.ships: m.locations.ships[id].region = "venus"
	checks.founded = f.outposts.found(ids.jump_ship).is_empty()
	f.regions.set_location("venus")
	var local: StationModel = game.board.model
	local.build(Vector2(58, 0), "solar")
	local.build(Vector2(116, 0), "space_depot")
	supply.ensure_floating_region("venus")
	for i in range(200):
		if supply.floating.venus.pieces.values().any(func(piece: Dictionary) -> bool: return piece.resource == "xenocrystal"): break
		supply._spawn_debris(false, "venus")
	supply.sync_mining_nodes()
	checks.collection_deploy = f.collection.deploy(ids.material_ship).is_empty()
	var start: int = local.materials
	var home: int = m.materials
	for i in range(500): f.collection.advance(0.1)
	checks.local_materials = local.materials > start and m.materials == home
	checks.ore_assign = f.dispatch(f.regions.records.venus.asteroid_ids[0], ids.miner).is_empty()
	var xeno: int = -1
	for target: int in f.resource_targets:
		if f.resource_targets[target].region == "venus": xeno = target
	checks.xeno_assign = xeno != -1 and f.dispatch(xeno, ids.xeno_miner).is_empty()
	checks.hauler_no_refinery = f.hauling.assign(ids.hauler, Vector2.ZERO).contains("Refinery")
	# Looking at Home must not change this Venus Scout's origin.
	f.regions.set_location("home")
	var next_region: String = ""
	for region: String in f.regions.catalog.venus.neighbors:
		if not f.regions.is_discovered(region): next_region = region
	checks.scout_local = f.survey_region(ids.scout, next_region).is_empty() and f.regions.survey_jobs[ids.scout].origin == "venus"
	var contact: String = ""
	var offer: String = ""
	for key: String in f.diplomacy.contacts:
		if f.diplomacy.contacts[key].region_id == "venus":
			contact = key
			for candidate: String in f.diplomacy.offers:
				if f.diplomacy.offers[candidate].faction == f.diplomacy.contacts[key].faction and int(f.diplomacy.offers[candidate].requires_standing) <= 0: offer = candidate
	local.minerals = 100
	var home_goods: Dictionary = f.diplomacy.inventory.duplicate(true)
	checks.trade_local = f.trade(ids.trader, contact, offer).is_empty()
	var state: Dictionary = game.persistence.snapshot()
	var error: String = game.persistence.restore(state)
	checks.active_roundtrip = error.is_empty() and game.persistence.snapshot() == state
	report("load_error", error)
	f.cancel_unit(ids.scout) # Separate mining credit from randomized discovery rewards.
	var ore: int = local.minerals
	var home_ore: int = m.minerals
	for i in range(24): f.tick()
	checks.ore_local = local.minerals > ore and m.minerals == home_ore
	report("xeno", {"local":local.upgrade_resource_amount("xenocrystal"),"home":f.diplomacy.inventory.xenocrystal,"before":home_goods.xenocrystal,"job":f.jobs.get(ids.xeno_miner,{})})
	checks.xeno_local = local.upgrade_resource_amount("xenocrystal") > 0 and f.diplomacy.inventory.xenocrystal == home_goods.xenocrystal
	checks.trade_goods_local = true
	for good: String in f.diplomacy.offers[offer].goods:
		checks.trade_goods_local = checks.trade_goods_local and local.upgrade_resource_amount(good) >= int(f.diplomacy.offers[offer].goods[good])
	var final_state: Dictionary = game.persistence.snapshot()
	checks.finished_roundtrip = game.persistence.restore(final_state).is_empty()
	# Home collection and hauling still use the same paths and amounts.
	f.collection.cancel(ids.material_ship)
	m.locations.ships[ids.material_ship].region = "home"
	checks.home_deploy = f.collection.deploy(ids.material_ship).is_empty()
	f.collection.jobs[ids.material_ship].cargo = 1
	f.collection.jobs[ids.material_ship].position = f.collection.depot_position(Vector2(0, 58))
	m.materials = 0
	f.collection.advance(0.1)
	checks.home_delivery = m.materials == 1
	f.collection.cancel(ids.material_ship)
	m.materials = 1000
	m.build(Vector2(58, 58), "refinery")
	m.locations.ships[ids.hauler].region = "home"
	m.refinery_buffer(Vector2(58, 58))["materials"] = 5
	checks.home_hauler = f.hauling.assign(ids.hauler, Vector2(58, 58)).is_empty()
	m.materials = 0
	for i in range(10): f.hauling.tick()
	checks.home_hauler_delivery = m.materials == 5
	report("checks", checks)
	finish()
