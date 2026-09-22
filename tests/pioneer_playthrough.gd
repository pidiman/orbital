extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m: StationModel = game.model
	var f = game.fleet
	m.materials = 3000
	for x in range(1, 6): m.build(Vector2(x * 58, 0), "solar")
	m.build(Vector2(0, 58), "space_depot")
	m.build(Vector2(58, 58), "research_lab")
	f.diplomacy.inventory.tech = 20
	f.research.research("teleportation")
	checks.home_gate = m.build(Vector2(-87, -29), "teleport_gate").is_empty()
	m.buy_ship("scout")
	var scout: int = m.next_ship_id
	m.buy_ship("jump_ship")
	var jump: int = m.next_ship_id
	checks.scout_order = f.survey_region(scout, "venus").is_empty()
	for i in range(100): f.tick()
	checks.discovered = f.regions.is_discovered("venus")
	f.diplomacy.inventory.xenocrystal = 10
	checks.normal_blocked = f.transport.jump_error(Vector2(-87, -29), scout, "venus").contains("destination region needs")
	var panel = game.hud.gate_panel
	panel.open_panel()
	for i in range(panel.ship_picker.item_count):
		if panel.ship_picker.get_item_id(i) == jump: panel.ship_picker.select(i)
	for i in range(panel.destination_picker.item_count):
		if panel.destination_picker.get_item_metadata(i) == "venus": panel.destination_picker.select(i)
	panel.refresh()
	checks.pioneer_ui = panel.jump_button.text.contains("Pioneer")
	await use(panel.jump_button)
	checks.warning = game.save_dialogs.screen.visible and game.save_dialogs.body.get_child(0).text.contains("One-way") and not f.transport.jobs.has(jump)
	await use(game.save_dialogs.body.get_child(1))
	checks.cost = f.diplomacy.inventory.xenocrystal == 9
	var transit: Dictionary = game.persistence.snapshot()
	checks.transit_load = game.persistence.restore(transit).is_empty()
	for i in range(10): f.transport.tick()
	checks.arrived = m.locations.ship_region(jump) == "venus"
	checks.no_return = not f.transport.jump_error("", jump, "home").is_empty()
	game.hud._command_ship(jump, "gate_building")
	checks.needs_outpost = game.hud.status_label.text.contains("Found an outpost first")
	checks.founded = f.outposts.found(jump).is_empty()
	f.regions.set_location("venus")
	var local: StationModel = game.board.model
	local.build(Vector2(58, 0), "solar")
	game.hud._command_ship(jump, "gate_building")
	checks.placement_command = game.board.selected == "teleport_gate"
	var funds: int = local.materials
	await settle(3)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(Vector2(-87, -29)))
	report("placement", {"message":game.hud.status_label.text,"modules":str(local.modules),"selected":game.board.selected})
	checks.built_locally = f.transport.has_gate("venus") and local.materials == funds - int(m.catalog.teleport_gate.cost)
	var id: String = local.structure_id_at(Vector2(-87, -29))
	m.locations.stations[local.station_id].inventory.xenocrystal = 2
	checks.return_jump = f.transport.jump(id, jump, "home").is_empty()
	for i in range(10): f.transport.tick()
	checks.returned = m.locations.ship_region(jump) == "home"
	checks.normal_now_allowed = f.transport.jump(Vector2(-87, -29), scout, "venus").is_empty()
	var saved: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(saved).is_empty() and game.persistence.snapshot() == saved
	report("checks", checks)
	finish()
