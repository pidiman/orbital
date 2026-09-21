extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	var fleet = game.fleet
	m.materials = 3000
	for x in range(1, 5): m.build(Vector2(x * 58, 0), "solar")
	m.build(Vector2(0, 58), "research_lab")
	fleet.diplomacy.inventory.tech = 20
	fleet.research.research("teleportation")
	checks.home_gate = m.build(Vector2(-87, -29), "teleport_gate").is_empty()
	m.buy_ship("jump_ship")
	var jump: int = m.next_ship_id
	m.buy_ship("miner")
	var miner: int = m.next_ship_id
	fleet._discover_region("venus")
	fleet.diplomacy.inventory.xenocrystal = 10
	checks.outbound = fleet.transport.jump(Vector2(-87, -29), jump, "venus").is_empty()
	for i in range(10): fleet.transport.tick()
	m.materials = 359
	checks.founding_blocked = not fleet.outposts.found(jump).is_empty() and m.materials == 359
	m.materials = 1000
	checks.founding = fleet.outposts.found(jump).is_empty()
	var id: String = m.locations.outpost_at("venus", "player")
	var legacy: Dictionary = game.persistence.snapshot()
	checks.transfer = m.materials == 640 and m.locations.stations[id].inventory.materials == 300
	fleet.regions.set_location("venus")
	await settle(3)
	var local: StationModel = game.board.model
	checks.local_model = local.station_id == id and game.board.visible
	checks.no_power = not local.build(Vector2(58, 0), "space_dock").is_empty()
	await use(game.hud.tool_buttons.solar)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(Vector2(58, 0)))
	checks.solar = local.modules.get(Vector2(58, 0)) == "solar"
	checks.storage = local.build(Vector2(116, 0), "storage").is_empty()
	checks.dock = local.build(Vector2(0, 58), "space_dock").is_empty()
	checks.gate = local.build(Vector2(-87, -29), "teleport_gate").is_empty()
	checks.local_cost = m.materials == 640 and local.materials == 300 - int(m.catalog.solar.cost) - int(m.catalog.storage.cost) - int(m.catalog.space_dock.cost) - int(m.catalog.teleport_gate.cost)
	checks.capacity_power = local.capacity > 300 and local.power_output == int(m.catalog.solar.power_output) and local.power_balance() >= 0
	checks.identity = local.structure_id_at(Vector2(58, 0)) != m.structure_id_at(Vector2(58, 0)) and m.locations.structures[local.structure_id_at(Vector2(58, 0))].region == "venus"
	checks.guardrail = not local.build(Vector2(174, 0), "refinery").is_empty()
	fleet.docking.reconcile()
	checks.parked = fleet.docking.ships[jump].dock_id == local.structure_id_at(Vector2(0, 58))
	checks.miner_jump = fleet.transport.jump(Vector2(-87, -29), miner, "venus").is_empty()
	for i in range(10): fleet.transport.tick()
	var target: int = fleet.regions.records.venus.asteroid_ids[0]
	checks.local_mining = fleet.dispatch(target, miner).is_empty()
	var home_ore: int = m.minerals
	for i in range(8): fleet.tick()
	checks.local_credit = local.minerals == 18 and m.minerals == home_ore
	m.locations.stations[id].inventory.xenocrystal = 2
	var gate: String = local.structure_id_at(Vector2(-87, -29))
	m.locations.stations[id].inventory.xenocrystal = 0
	checks.local_jump_cost_block = not fleet.transport.jump(gate, jump, "home").is_empty()
	m.locations.stations[id].inventory.xenocrystal = 2
	await use(game.hud.menu_buttons["Gate/Travel"])
	var panel = game.hud.gate_panel
	for index in range(panel.gate_picker.item_count):
		if panel.gate_picker.get_item_metadata(index) == gate: panel.gate_picker.select(index)
	for index in range(panel.ship_picker.item_count):
		if panel.ship_picker.get_item_id(index) == jump: panel.ship_picker.select(index)
	for index in range(panel.destination_picker.item_count):
		if panel.destination_picker.get_item_metadata(index) == "home": panel.destination_picker.select(index)
	panel.refresh()
	await use(panel.jump_button)
	checks.return_gate = fleet.transport.jobs.has(jump) and m.locations.stations[id].inventory.xenocrystal == 1
	game.hud.close_panels()
	var before: Dictionary = game.persistence.snapshot()
	var error: String = game.persistence.restore(before)
	report("restore_error", error)
	checks.transit_roundtrip = error.is_empty() and before == game.persistence.snapshot()
	for i in range(10): fleet.transport.tick()
	checks.returned = m.locations.ship_region(jump) == "home"
	local = game.board.model
	local.materials = 300
	game.hud.inspect_module(Vector2(0, 58))
	await use(game.hud.upgrade_button)
	checks.upgrade = local.definition_at(Vector2(0, 58)).docking.capacity == 2
	var home_stock: int = m.materials
	game.hud.inspect_module(Vector2(-87, -29))
	await use(game.hud.demolish_button)
	checks.demolish = not local.modules.has(Vector2(-87, -29)) and m.materials == home_stock
	game.hud.inspect_module(Vector2(0, 58))
	await settle(3)
	save_frame("outpost_base")
	var path: String = "user://outpost-base-test-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	checks.disk_save = game.persistence.save_game().is_empty()
	before = game.persistence.snapshot()
	checks.disk_load = game.persistence.load_game().is_empty() and before == game.persistence.snapshot()
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var legacy_stations: Dictionary = game.persistence._decode(legacy.extensions.world_locations.stations)
	legacy_stations[id].inventory.erase("materials")
	legacy_stations[id].inventory.minerals = 18
	legacy_stations[id].founding.erase("starter_transfer")
	legacy.extensions.world_locations.stations = game.persistence._encode(legacy_stations)
	checks.legacy_load = game.persistence.restore(legacy).is_empty()
	checks.no_retroactive_transfer = m.locations.stations[id].inventory.materials == 0 and m.locations.stations[id].inventory.minerals == 18 and m.locations.legacy_modules(id).size() == 1
	before = game.persistence.snapshot()
	checks.migrated_roundtrip = game.persistence.restore(before).is_empty() and before == game.persistence.snapshot()
	fleet.regions.set_location("home")
	checks.home_unchanged = game.board.model == m and game.board.visible and m.locations.station_region(m.locations.primary_station()) == "home"
	report("checks", checks)
	finish()
