extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["isolated_from_player_checkpoint"] = not game.persistence.enabled
	var test_path: String = "user://orbital-trade-ui-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	await gather(35)
	await page(1)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await use(game.hud.ship_buttons.scout)
	var scout: int = game.model.next_ship_id
	await gather(45)
	game.hud.ship_buttons.miner.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.miner)
	await settle(2)
	await use(game.hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	await gather(50)
	game.hud.ship_buttons.trader.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.trader)
	await settle(2)
	await use(game.hud.ship_buttons.trader)
	var trader: int = game.model.next_ship_id
	checks["trader_built_cost_power"] = game.model.ships.get(trader) == "trader" and game.model.power_balance() == 1
	checks["trade_has_own_action"] = game.hud.capability_buttons[trader].has("trade") and not game.hud.capability_buttons[trader].has("survey")
	await use(game.hud.map_button)
	var map: PanelContainer = game.hud.sector_map
	await use(map.sector_buttons.dawn)
	await use(map.send_button)
	await wait_reveal("dawn")
	var target: int = game.fleet.sector_by_id("dawn").asteroid_ids[0]
	await use(map.target_buttons[target])
	checks["mining_still_works"] = game.fleet.jobs.has(miner)
	await use(map.sector_buttons.echo)
	await use(map.send_button)
	checks["anomaly_travel_timer"] = game.fleet.survey_jobs.has(scout) and game.fleet.diplomacy.contacts.is_empty()
	await wait_reveal("echo")
	checks["alien_anomaly_reveals_contacts"] = game.fleet.diplomacy.contacts.size() == 2 and map.result_label.text.contains("alien envoys")
	await use(map.contacts_button)
	var panel: PanelContainer = game.hud.trade_panel
	checks["contact_ui_visible_and_fits"] = panel.visible and panel.get_global_rect().end.x <= game.get_viewport_rect().size.x - 28 and panel.get_global_rect().end.y < 790
	checks["neutral_standing_visible"] = panel.standing_label.text.contains("Standing 0 / 100")
	var attempts: int = 0
	while game.model.minerals < 18 and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	game.get_node("ResourceClock").set_process(false)
	var ore_before: int = game.model.minerals
	await use(panel.offer_buttons.archive_data)
	checks["trade_launch_spends_minerals"] = game.fleet.diplomacy.jobs.has(trader) and game.model.minerals == ore_before - 18
	checks["travel_ui_and_no_early_reward"] = panel.mission_label.text.contains("7s") and game.fleet.diplomacy.inventory.tech == 0
	for i in range(3):
		await use(panel.offer_buttons.archive_data)
	checks["busy_button_prevents_double_spend"] = game.model.minerals == ore_before - 18 and game.fleet.diplomacy.next_trade_id == 1
	await settle(3)
	save_frame("trade_in_transit")
	await use(game.hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.model.materials += 1
	await use(game.hud.load_button)
	checks["active_trade_save_load_exact"] = game.persistence.snapshot() == expected
	panel = game.hud.trade_panel
	map = game.hud.sector_map
	await use(game.hud.map_button)
	await use(map.contacts_button)
	checks["load_rebuilds_contacts_and_timer"] = panel.mission_label.text.contains("7s") and panel.contact_picker.item_count == 2
	game.get_node("ResourceClock").set_process(true)
	attempts = 0
	while game.fleet.diplomacy.history.is_empty() and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["completed_trade_rewards"] = game.fleet.diplomacy.inventory.tech == 1 and game.fleet.diplomacy.factions.lumen.standing == 4
	checks["standing_inventory_history_visible"] = panel.standing_label.text.contains("Standing 4") and panel.inventory_label.text.contains("Tech: 1") and panel.history_label.text.contains("Completed")
	checks["completion_autosaved"] = not game.persistence.dirty and game.persistence.last_error.is_empty()
	game.get_node("ResourceClock").set_process(false)
	await settle(3)
	save_frame("alien_trade_complete")
	await use(game.hud.save_button)
	expected = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.fleet.diplomacy.factions.lumen.standing = 99
	await use(game.hud.load_button)
	checks["completed_trade_save_load_exact"] = game.persistence.snapshot() == expected
	checks["version_remains_v2"] = expected.version == 2 and expected.extensions.alien_trade.schema_version == 1
	checks["entire_runtime_2d"] = no_3d(game)
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	# UI composition for a future hybrid, confined to this disposable instance.
	game.model.ship_catalog.trader["mining"] = game.model.ship_catalog.miner.mining.duplicate(true)
	game.model.ship_catalog.trader["survey"] = game.model.ship_catalog.scout.survey.duplicate(true)
	game.hud.reset_after_load()
	await settle(3)
	checks["hybrid_has_three_independent_commands"] = game.hud.capability_buttons[trader].size() == 3
	report("checks", checks)
	finish()

func wait_reveal(sector_id: String) -> void:
	var attempts: int = 0
	while game.fleet.sector_state(sector_id) != "revealed" and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	await settle(2)

func page(index: int) -> void:
	var menu: String = "Build" if index == 0 else "Ships"
	if game.hud.active_menu != menu: await click(game.hud.menu_buttons[menu].get_global_rect().get_center())

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
	await use(button)

func gather(target: int) -> void:
	var attempts: int = 0
	while game.model.materials < target and attempts < 500:
		attempts += 1
		if game.debris.pieces.is_empty():
			await get_tree().create_timer(0.4).timeout
		else:
			var point: Vector2 = game.debris.pieces[0].point
			if point.x < 30:
				await get_tree().create_timer(0.3).timeout
				continue
			var before: int = game.model.materials
			await click(point)
			if game.model.materials > before:
				checks["debris_collection"] = true

func use(button: Control) -> void:
	var hud = game.hud
	if not button.is_visible_in_tree():
		var menu: String = ""
		if hud.tool_buttons.values().has(button): menu = "Build"
		elif hud.region_navigation.panel.is_ancestor_of(button) or button == hud.map_button: menu = "Outposts/Regions"
		elif hud.panel.is_ancestor_of(button): menu = "Ships"
		elif hud.gate_panel.is_ancestor_of(button): menu = "Gate/Travel"
		elif hud.research_panel.is_ancestor_of(button): menu = "Research"
		elif hud.trade_panel.is_ancestor_of(button): menu = "Trade/Contacts"
		if not menu.is_empty():
			if hud.active_menu == menu: await click(hud.menu_buttons[menu].get_global_rect().get_center())
			await click(hud.menu_buttons[menu].get_global_rect().get_center())
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle(2)
	await click(button.get_global_rect().get_center())
