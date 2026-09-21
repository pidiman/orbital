extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["runtime_entirely_2d"] = no_3d(game)
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	await gather(35)
	await page(1)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await use(game.hud.ship_buttons.scout)
	var scout: int = game.model.next_ship_id
	checks["scout_built"] = game.model.ships.get(scout) == "scout" and game.model.power_balance() == 5
	await use(game.hud.map_button)
	var map: PanelContainer = game.hud.sector_map
	checks["map_open_and_fits"] = map.visible and map.get_global_rect().end.x <= game.get_viewport_rect().size.x - 28 and map.get_global_rect().end.y < 780
	await use(map.sector_buttons.dawn)
	checks["unexplored_contents_hidden"] = map.result_label.text.contains("Contents unknown") and game.fleet.asteroids.size() == game.asteroids.home_asteroid_count()
	checks["scout_and_travel_visible"] = map.scout_picker.get_selected_id() == scout and map.send_button.text.contains("5s")
	await use(map.send_button)
	checks["selected_scout_launched"] = game.fleet.survey_jobs.has(scout) and game.fleet.survey_jobs[scout].sector_id == "dawn"
	checks["exploring_state_and_timer"] = map.state_label.text.contains("EXPLORING") and map.progress.visible and map.send_button.disabled
	await get_tree().create_timer(2.0).timeout
	checks["travel_not_instant"] = game.fleet.sector_state("dawn") == "exploring" and not game.fleet.sector_by_id("dawn").has("asteroid_ids")
	await settle(2)
	save_frame("exploring")
	await wait_reveal("dawn")
	var target: int = game.fleet.sector_by_id("dawn").asteroid_ids[0]
	checks["revealed_report_and_target"] = map.state_label.text == "REVEALED" and map.result_label.text.contains("Dawn deposit") and map.target_buttons.has(target)
	checks["scout_returned_no_duplicate"] = not game.fleet.survey_jobs.has(scout) and map.send_button.disabled
	checks["no_miner_button_disabled"] = map.target_buttons[target].disabled
	save_frame("discovery")
	await use(map.close_button)
	await gather(45)
	game.hud.ship_buttons.miner.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.miner)
	await settle(2)
	await use(game.hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	checks["miner_built"] = game.model.ships.get(miner) == "miner"
	await use(game.hud.map_button)
	await use(map.target_buttons[target])
	checks["miner_assigned_discovery"] = game.fleet.jobs.has(miner) and game.fleet.jobs[miner].target == target and map.target_buttons[target].disabled
	var attempts: int = 0
	while game.fleet.total_mined < 18 and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["discovered_ore_delivered"] = game.model.minerals == 18 and game.fleet.total_mined == 18
	checks["auto_mining_continues"] = game.fleet.jobs.has(miner) and game.fleet.asteroids[target].minerals == 36
	checks["map_ore_updates"] = map.target_buttons[target].text.contains("36 Minerals")
	save_frame("discovery_mining")
	await use(map.sector_buttons.echo)
	await use(map.send_button)
	await wait_reveal("echo")
	checks["anomaly_report"] = map.result_label.text.contains("Anomaly: Quiet signal") and game.fleet.sector_by_id("echo").asteroid_ids.is_empty()
	save_frame("anomaly")
	await use(map.sector_buttons.quiet)
	await use(map.send_button)
	await wait_reveal("quiet")
	checks["empty_report"] = map.result_label.text.contains("Empty sector") and game.fleet.sector_by_id("quiet").asteroid_ids.is_empty()
	await use(map.close_button)
	checks["map_closes"] = not map.visible
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
