extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["runtime_2d"] = no_3d(game)
	await select("storage")
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks["zero_power_reproduced"] = game.model.power_balance() == 0
	await click(game.hud.root.find_child("CancelButton", true, false).get_global_rect().get_center())
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks["demolish_action_available_at_zero_power"] = not game.hud.demolish_button.disabled and game.hud.demolish_button.text.contains("12 M")
	save_frame("decommission_module")
	var before: int = game.model.materials
	await click(game.hud.demolish_button.get_global_rect().get_center())
	checks["ui_demolition_refund_and_space"] = game.model.materials == before + 12 and game.model.power_balance() == 1 and not game.model.modules.has(Vector2(58, 0))
	await page(0)
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks["ui_rebuild_solar_recovery"] = game.model.modules.get(Vector2(58, 0)) == "solar" and game.model.power_balance() == 6
	await gather(45)
	await page(1)
	game.hud.ship_buttons.miner.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.miner)
	await settle(2)
	await click(game.hud.ship_buttons.miner.get_global_rect().get_center())
	var miner: int = game.model.next_ship_id
	var target: int = game.asteroids.rocks.keys()[0]
	await click(game.hud.command_buttons[miner].get_global_rect().get_center())
	await click(game.asteroids.rocks[target].point)
	checks["busy_miner_before_sale"] = game.fleet.jobs.has(miner)
	before = game.model.materials
	save_frame("decommission_ship")
	await click(game.hud.sell_buttons[miner].get_global_rect().get_center())
	checks["ui_ship_sale"] = not game.model.ships.has(miner) and game.model.materials == before + 22 and game.model.power_balance() == 6
	checks["ui_busy_mission_release"] = not game.fleet.asteroids[target].claimed and game.fleet.jobs.is_empty() and not game.hud.command_buttons.has(miner)
	await gather(35)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await click(game.hud.ship_buttons.scout.get_global_rect().get_center())
	var scout: int = game.model.next_ship_id
	await click(game.hud.command_buttons[scout].get_global_rect().get_center())
	await click(game.hud.sell_buttons[scout].get_global_rect().get_center())
	checks["ui_scout_sale_releases_sector"] = game.fleet.survey_jobs.is_empty() and game.fleet.sector_state("dawn") == "unexplored"
	# Removing both visual fields must not stop supply simulation or create duplicate spawns.
	var supply_time: float = game.supply.elapsed
	var debris_ids: Array = game.supply.debris.keys()
	game.remove_child(game.debris)
	game.remove_child(game.asteroids)
	await get_tree().create_timer(3.2).timeout
	checks["supply_advances_without_views"] = game.supply.elapsed > supply_time + 3.0 and game.supply.next_debris_id > debris_ids.back()
	var count_before: int = game.supply.debris.size()
	game.add_child(game.debris)
	game.add_child(game.asteroids)
	await settle(2)
	checks["views_rehydrate_without_spawning"] = game.debris.pieces.size() == count_before and game.debris.pieces.size() == game.supply.debris.size()
	# Legal model API setup of the audited 81-module case; recovery itself uses mouse input.
	var positions: Array[Vector2] = []
	for x in range(-4, 5):
		for y in range(-4, 5):
			if x != 0 or y != 0:
				positions.append(Vector2(x * 58, y * 58))
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.x) + absf(a.y) < absf(b.x) + absf(b.y))
	for point: Vector2 in positions:
		if game.model.modules.has(point):
			continue
		game.model.collect(10000)
		game.model.build(point, "solar")
	for index in range(66):
		game.model.demolish_module(positions[index])
		game.model.collect(10000)
		game.model.build(positions[index], "storage")
	for index in range(5):
		game.model.collect(10000)
		game.model.buy_ship("scout")
	game.model.materials = 0
	game.model.changed.emit()
	checks["full_station_at_zero"] = game.model.modules.size() == 81 and game.model.power_balance() == 0
	await click(game.board.world_to_screen(positions[0]))
	await click(game.hud.demolish_button.get_global_rect().get_center())
	checks["full_station_ui_demolition"] = game.model.modules.size() == 80 and game.model.power_balance() == 1
	await gather(20)
	await page(0)
	await select("solar")
	await click(game.board.world_to_screen(positions[0]))
	checks["full_station_ui_recovered"] = game.model.modules.size() == 81 and game.model.power_balance() == 6
	save_frame("full_station_recovered")
	report("checks", checks)
	finish()

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
	await click(button.get_global_rect().get_center())

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
