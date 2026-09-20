extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	summer_max_seconds = 180
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["isolated_from_player_checkpoint"] = not game.persistence.enabled
	var test_path: String = "user://orbital-research-ui-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	await gather(35)
	await page(1)
	await click(game.hud.ship_buttons.scout.get_global_rect().get_center())
	var scout: int = game.model.next_ship_id
	await gather(45)
	await click(game.hud.ship_buttons.miner.get_global_rect().get_center())
	var miner: int = game.model.next_ship_id
	await gather(50)
	await click(game.hud.ship_buttons.trader.get_global_rect().get_center())
	var trader: int = game.model.next_ship_id
	checks["trader_built_cost_power"] = game.model.ships.get(trader) == "trader" and game.model.power_balance() == 1
	checks["trade_has_own_action"] = game.hud.capability_buttons[trader].has("trade") and not game.hud.capability_buttons[trader].has("survey")
	await gather(45)
	await click(game.hud.map_button.get_global_rect().get_center())
	var map: PanelContainer = game.hud.sector_map
	await click(map.sector_buttons.dawn.get_global_rect().get_center())
	await click(map.send_button.get_global_rect().get_center())
	await wait_reveal("dawn")
	var target: int = game.fleet.sector_by_id("dawn").asteroid_ids[0]
	await click(map.target_buttons[target].get_global_rect().get_center())
	checks["mining_still_works"] = game.fleet.jobs.has(miner)
	await click(map.sector_buttons.echo.get_global_rect().get_center())
	await click(map.send_button.get_global_rect().get_center())
	checks["anomaly_travel_timer"] = game.fleet.survey_jobs.has(scout) and game.fleet.diplomacy.contacts.is_empty()
	await wait_reveal("echo")
	checks["alien_anomaly_reveals_contacts"] = game.fleet.diplomacy.contacts.size() == 2 and map.result_label.text.contains("alien envoys")
	await click(map.contacts_button.get_global_rect().get_center())
	report("stage", "trade")
	var panel: PanelContainer = game.hud.trade_panel
	var attempts: int = 0
	while game.model.minerals < 48 and attempts < 900:
		attempts += 1
		await get_tree().physics_frame
	for trade: Array in [["lumen_envoy", "archive_data"], ["lumen_envoy", "archive_data"], ["prism_envoy", "prism_gift"], ["prism_envoy", "prism_crystals"]]:
		for index in range(panel.contact_picker.item_count):
			if panel.contact_picker.get_item_metadata(index) == trade[0]:
				panel.contact_picker.select(index)
		panel.refresh()
		await settle(3)
		panel.offer_rows.get_parent().ensure_control_visible(panel.offer_buttons[trade[1]])
		await settle(2)
		await click(panel.offer_buttons[trade[1]].get_global_rect().get_center())
		checks["trade_launch_" + trade[1]] = game.fleet.diplomacy.jobs.has(trader)
		attempts = 0
		while game.fleet.diplomacy.jobs.has(trader) and attempts < 400:
			attempts += 1
			await get_tree().physics_frame
	report("stage", "goods acquired")
	checks.trade_acquired_goods = game.fleet.diplomacy.inventory.tech == 2 and game.fleet.diplomacy.inventory.xenocrystal == 2
	await click(panel.close_button.get_global_rect().get_center())
	await click(game.hud.research_button.get_global_rect().get_center())
	var research: PanelContainer = game.hud.research_panel
	checks.gate_hidden = not game.hud.tool_buttons.teleport_gate.visible
	await click(research.research_buttons.teleportation.get_global_rect().get_center())
	checks.no_lab_message = game.hud.status_label.text.contains("Research Lab")
	await click(research.close_button.get_global_rect().get_center())
	await page(0)
	await gather(20)
	await select("solar")
	await click(game.board.cell_position(Vector2i(2, 0)))
	await gather(40)
	await select("research_lab")
	await click(game.board.cell_position(Vector2i(0, 1)))
	checks.lab_built = game.model.modules.get(Vector2(0, 58)) == "research_lab"
	await click(game.hud.research_button.get_global_rect().get_center())
	checks.available = research.research_labels.teleportation.text.contains("Available")
	await click(research.research_buttons.teleportation.get_global_rect().get_center())
	checks.research_spent_tech = game.fleet.diplomacy.inventory.tech == 0 and game.fleet.research.researched.has("teleportation")
	checks.unlocked_in_ui = game.hud.tool_buttons.teleport_gate.visible and research.research_labels.teleportation.text.contains("Researched")
	checks.panel_fits = research.get_global_rect().end.y < 790 and research.get_global_rect().end.x < game.hud.panel.get_global_rect().position.x
	save_frame("research_unlocked")
	await click(research.close_button.get_global_rect().get_center())
	await gather(80)
	await select("teleport_gate")
	var gate := Vector2(-87, -29)
	var before: int = game.model.materials
	await click(game.board.world_to_screen(gate))
	checks.gate_cost = game.model.modules.get(gate) == "teleport_gate" and game.model.materials == before - 80 and game.fleet.diplomacy.inventory.tech == 0
	checks.reserved_four_cells = true
	for cell: Vector2 in game.model.footprint_points(gate, "teleport_gate"):
		checks.reserved_four_cells = checks.reserved_four_cells and game.model.placement_error(cell, "solar").contains("overlap") and game.board.module_at_screen(game.board.world_to_screen(cell)) == gate
	game.hud.choose("")
	await settle(3)
	save_frame("gate_built_2x2")
	await click(game.hud.region_navigation.region_buttons.venus.get_global_rect().get_center())
	await click(game.hud.region_navigation.send_button.get_global_rect().get_center())
	attempts = 0
	while not game.fleet.regions.is_discovered("venus") and attempts < 500:
		attempts += 1
		await get_tree().physics_frame
	await click(game.hud.region_navigation.close_button.get_global_rect().get_center())
	await click(game.hud.research_button.get_global_rect().get_center())
	pick_ship(research, trader)
	game.get_node("ResourceClock").set_process(false)
	before = game.fleet.diplomacy.inventory.xenocrystal
	await click(research.jump_button.get_global_rect().get_center())
	checks.jump_spends_crystal = game.fleet.transport.jobs.has(trader) and game.fleet.diplomacy.inventory.xenocrystal == before - 1
	checks.transit_visible = research.locations_label.text.contains("In transit to Venus")
	save_frame("gate_in_transit")
	await click(game.hud.save_button.get_global_rect().get_center())
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.fleet.research.researched.clear()
	await click(game.hud.load_button.get_global_rect().get_center())
	checks.transit_save_load = game.persistence.snapshot() == expected
	game.get_node("ResourceClock").set_process(true)
	attempts = 0
	while game.fleet.transport.jobs.has(trader) and attempts < 300:
		attempts += 1
		await get_tree().physics_frame
	checks.arrived_only_ship = game.fleet.transport.location(trader) == "venus" and game.fleet.regions.current_region == "home" and game.model.modules.has(Vector2.ZERO)
	await click(game.hud.region_navigation.region_buttons.venus.get_global_rect().get_center())
	await settle(3)
	checks.arrived_region_view = game.fleet.regions.current_region == "venus" and not game.board.visible and game.fleet.transport.location(trader) == "venus"
	save_frame("ship_arrived_venus")
	await click(game.hud.region_navigation.region_buttons.home.get_global_rect().get_center())
	await click(game.hud.research_button.get_global_rect().get_center())
	pick_ship(research, scout)
	await click(research.jump_button.get_global_rect().get_center())
	# Spend any anomaly crystals on further idle ships so insufficient balance is real.
	await click(research.close_button.get_global_rect().get_center())
	await gather(40)
	await page(1)
	await click(game.hud.ship_buttons.material_ship.get_global_rect().get_center())
	var material_ship: int = game.model.next_ship_id
	await click(game.hud.research_button.get_global_rect().get_center())
	pick_ship(research, material_ship)
	game.get_node("ResourceClock").set_process(false)
	game.fleet.diplomacy.inventory.xenocrystal = 0
	before = game.fleet.diplomacy.inventory.xenocrystal
	await click(research.jump_button.get_global_rect().get_center())
	checks.insufficient_message = game.hud.status_label.text.contains("Xenocrystal") and not game.fleet.transport.jobs.has(material_ship) and game.fleet.diplomacy.inventory.xenocrystal == before
	game.get_node("ResourceClock").set_process(false)
	await click(game.hud.save_button.get_global_rect().get_center())
	expected = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.fleet.transport.locations.clear()
	await click(game.hud.load_button.get_global_rect().get_center())
	checks.arrived_save_load = game.persistence.snapshot() == expected
	await click(game.hud.research_button.get_global_rect().get_center())
	checks.location_restored_ui = research.locations_label.text.contains("Trade Ship #%d · Venus" % trader)
	save_frame("research_gate_restored")
	await click(research.close_button.get_global_rect().get_center())
	game.hud.choose("")
	await click(game.board.world_to_screen(gate + Vector2(29, 29)))
	checks.inspect_from_any_cell = game.hud.selected_position == gate
	await click(game.hud.demolish_button.get_global_rect().get_center())
	checks.demolish_frees_footprint = not game.model.modules.has(gate) and game.fleet.transport.gates.is_empty()
	for cell: Vector2 in game.model.footprint_points(gate, "teleport_gate"):
		checks.demolish_frees_footprint = checks.demolish_frees_footprint and game.board.module_at_screen(game.board.world_to_screen(cell)) == Vector2.INF
	checks.only_2d = no_3d(game)
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	report("checks", checks)
	finish()

func pick_ship(panel: PanelContainer, ship_id: int) -> void:
	for index in range(panel.ship_picker.item_count):
		if panel.ship_picker.get_item_id(index) == ship_id:
			panel.ship_picker.select(index)
	panel.refresh()

func wait_reveal(sector_id: String) -> void:
	var attempts: int = 0
	while game.fleet.sector_state(sector_id) != "revealed" and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	await settle(2)

func page(index: int) -> void:
	var bar: TabBar = game.hud.tabs.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(index).get_center())

func no_3d(node: Node) -> bool:
	if node.is_class("Node3D"):
		return false
	for child: Node in node.get_children():
		if not no_3d(child):
			return false
	return true

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up, true)
	await settle(2)

func select(kind: String) -> void:
	var button: Button = game.hud.tool_buttons[kind]
	game.hud.tabs.get_child(0).ensure_control_visible(button)
	await settle(2)
	await click(button.get_global_rect().get_center())

func gather(target: int) -> void:
	var attempts: int = 0
	while game.model.materials < target and attempts < 500:
		attempts += 1
		if game.debris.pieces.is_empty():
			await get_tree().create_timer(0.4).timeout
		else:
			var point: Vector2 = game.debris.pieces[0].point
			if point.x < 30 or point.x > 800 or point.y < 180 or point.y > 760:
				await get_tree().create_timer(0.3).timeout
				continue
			var before: int = game.model.materials
			await click(point)
			if game.model.materials > before:
				checks["debris_collection"] = true

func _on_deadline() -> void:
	report("checks", checks)
	save_frame("timeout_state")
	super._on_deadline()
