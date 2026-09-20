extends RefCounted
const Store = preload("res://scripts/save_store.gd")
const Supply = preload("res://scripts/sector_supply.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	model.ticked.connect(fleet.tick)
	var supply := Supply.new(model, fleet, 78)
	var store := Store.new(model, fleet, supply)
	var gate := Vector2(-87, -29)
	checks.locked = not model.module_unlocked("teleport_gate") and not model.build(gate, "teleport_gate").is_empty()
	checks.no_lab = fleet.research.research_error("teleportation").contains("Research Lab")
	model.materials = 100
	model.build(Vector2(58, 0), "solar")
	model.build(Vector2(116, 0), "solar")
	model.buy_ship("scout")
	var scout: int = model.next_ship_id
	model.collect(100)
	model.buy_ship("trader")
	var trader: int = model.next_ship_id
	fleet.survey(scout, "echo")
	for tick in range(6): model.tick()
	model.add_minerals(60)
	for transaction: Array in [["lumen_envoy", "archive_data"], ["lumen_envoy", "archive_data"], ["prism_envoy", "prism_gift"], ["prism_envoy", "prism_crystals"]]:
		model.collect(100)
		var error: String = fleet.trade(trader, transaction[0], transaction[1])
		checks["trade_" + transaction[1]] = error.is_empty()
		for tick in range(7): model.tick()
	checks.trade_goods = fleet.diplomacy.inventory.tech == 2 and fleet.diplomacy.inventory.xenocrystal == 2
	model.collect(100)
	checks.lab = model.build(Vector2(0, 58), "research_lab").is_empty() and fleet.research.labs.size() == 1
	fleet.diplomacy.inventory.tech = 1
	checks.insufficient_research = fleet.research.research("teleportation").contains("Need 2 Tech") and fleet.diplomacy.inventory.tech == 1
	fleet.diplomacy.inventory.tech = 2
	checks.available = fleet.research.state("teleportation") == "Available"
	checks.research = fleet.research.research("teleportation").is_empty() and fleet.diplomacy.inventory.tech == 0 and model.module_unlocked("teleport_gate")
	var snapshot: Dictionary = store.snapshot()
	checks.research_once = not fleet.research.research("teleportation").is_empty() and store.snapshot() == snapshot
	model.collect(100)
	var before: int = model.materials
	checks.gate_build = model.build(gate, "teleport_gate").is_empty() and model.materials == before - 80 and fleet.diplomacy.inventory.tech == 0
	checks.four_cells = model.footprint_points(gate, "teleport_gate").size() == 4
	model.collect(100)
	for point: Vector2 in model.footprint_points(gate, "teleport_gate"):
		checks["occupied_" + str(point)] = model.placement_error(point, "solar").contains("overlap")
	checks.bounds = model.placement_error(Vector2(232, 232), "teleport_gate").contains("entire footprint")
	checks.fractional_overlap = model.placement_error(gate + Vector2(0.25, 0.25), "storage").contains("overlap")
	checks.insufficient_tech = fleet.research.research_error("teleportation").contains("already researched")
	checks.unknown_region = not fleet.transport.jump(gate, trader, "venus").is_empty()
	fleet.survey_region(scout, "venus")
	for tick in range(6): model.tick()
	fleet.regions.records.pluto.discovered = true
	checks.graph_route = fleet.transport.jump_error(gate, trader, "pluto").contains("direct gate route")
	fleet.regions.records.pluto.discovered = false
	var crystal_before: int = fleet.diplomacy.inventory.xenocrystal
	checks.jump = fleet.transport.jump(gate, trader, "venus").is_empty() and fleet.diplomacy.inventory.xenocrystal == crystal_before - 1
	checks.transit_busy = fleet.unit_busy(trader) and not fleet.trade(trader, "lumen_envoy", "archive_data").is_empty()
	snapshot = store.snapshot()
	checks.spam_atomic = not fleet.transport.jump(gate, trader, "venus").is_empty() and store.snapshot() == snapshot
	store.path = "user://orbital-research-test-%d.json" % OS.get_process_id()
	checks.transit_disk_roundtrip = store.save_game().is_empty() and store.load_game().is_empty() and store.snapshot() == snapshot
	for tick in range(3): model.tick()
	checks.arrival = fleet.transport.location(trader) == "venus" and not fleet.transport.jobs.has(trader) and fleet.regions.current_region == "home" and model.modules.has(Vector2.ZERO)
	checks.remote_work_blocked = fleet.trade(trader, "lumen_envoy", "archive_data").contains("future scope") and not fleet.transport.jump(gate, trader, "venus").is_empty()
	fleet.transport.jump(gate, scout, "venus")
	model.collect(100)
	model.buy_ship("material_ship")
	var collector: int = model.next_ship_id
	fleet.diplomacy.inventory.xenocrystal = 0
	snapshot = store.snapshot()
	checks.insufficient_atomic = fleet.transport.jump(gate, collector, "venus").contains("Xenocrystal") and store.snapshot() == snapshot
	# Zero costs remain valid catalog configuration.
	model.catalog.teleport_gate.teleport.cost.xenocrystal = 0
	checks.zero_cost = fleet.transport.jump(gate, collector, "venus").is_empty()
	model.catalog.teleport_gate.teleport.cost.xenocrystal = 1
	for tick in range(3): model.tick()
	checks.remote_collection_blocked = supply.collection.deploy(collector).contains("future scope")
	snapshot = store.snapshot()
	checks.arrived_disk_roundtrip = store.save_game().is_empty() and store.load_game().is_empty() and store.snapshot() == snapshot
	var bad: Dictionary = snapshot.duplicate(true)
	bad.extensions.research.researched = {}
	checks.corrupt_unlock_atomic = not store.restore(bad).is_empty() and store.snapshot() == snapshot
	before = model.materials
	var refund: int = model.module_refund(gate)
	model.collect(100)
	model.buy_ship("scout")
	var departing: int = model.next_ship_id
	model.catalog.teleport_gate.teleport.cost.xenocrystal = 0
	checks.depart_before_removal = fleet.transport.jump(gate, departing, "venus").is_empty()
	model.catalog.teleport_gate.teleport.cost.xenocrystal = 1
	before = model.materials
	checks.demolish = model.demolish_module(gate).is_empty() and model.materials == before + refund and fleet.transport.gates.is_empty()
	snapshot = store.snapshot()
	checks.demolished_in_transit_roundtrip = store.restore(snapshot).is_empty() and store.snapshot() == snapshot
	for tick in range(3): model.tick()
	checks.demolished_gate_arrival = fleet.transport.location(departing) == "venus"
	model.materials = 500
	checks.freed_four_cells = model.build(Vector2(-58, 0), "solar").is_empty() and model.build(Vector2(-116, 0), "solar").is_empty() and model.build(Vector2(-58, -58), "solar").is_empty() and model.build(Vector2(-116, -58), "solar").is_empty()
	model.demolish_module(Vector2(0, 58))
	checks.permanent = fleet.research.researched.has("teleportation") and model.module_unlocked("teleport_gate")
	# Additional technology defined entirely by data uses existing research/UI logic.
	fleet.research.catalog["storage_design"] = {"id": "storage_design", "name": "Storage Design", "description": "Test", "tech_cost": 0, "requires": ["teleportation"], "unlocks": {"modules": ["storage"]}}
	checks.generic_lab_required = not model.module_unlocked("storage") and fleet.research.research_error("storage_design").contains("Research Lab")
	model.build(Vector2(0, 58), "research_lab")
	checks.generic_unlock = fleet.research.research("storage_design").is_empty() and model.module_unlocked("storage")
	var old_model := StationModel.new()
	var old_fleet := MiningFleet.new(old_model)
	var old_supply := Supply.new(old_model, old_fleet, 1)
	var old := Store.new(old_model, old_fleet, old_supply).snapshot()
	old.extensions.erase("research")
	old.extensions.erase("gate_transport")
	checks.legacy = store.restore(old).is_empty() and fleet.research.researched.is_empty() and fleet.transport.gates.is_empty() and fleet.transport.locations.is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	return checks
