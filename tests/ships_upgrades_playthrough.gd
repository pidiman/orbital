extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}
var timeline: Array[Dictionary] = []

func mark(label: String) -> void:
	timeline.append({"label": label, "frame": Engine.get_process_frames(), "materials": game.model.materials, "minerals": game.model.minerals, "modules": game.model.modules.size(), "ships": game.model.ships.size(), "power": game.model.power_balance(), "mined": game.fleet.total_mined})

func page(index: int) -> void:
	var menu: String = "Build" if index == 0 else "Ships"
	if game.hud.active_menu != menu: await click(game.hud.menu_buttons[menu].get_global_rect().get_center())

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["runtime_entirely_2d"] = no_3d(game)
	var board: Node2D = game.board
	var fractional := Vector2(58.0, 12.25)
	checks["world_projection_roundtrip"] = board.screen_to_world(board.world_to_screen(fractional)).is_equal_approx(fractional)
	checks["default_grid_snap_unchanged"] = board.placement_position(board.world_to_screen(fractional)) == Vector2(58, 0)
	board.snap_enabled = false
	checks["snap_can_be_disabled"] = board.placement_position(board.world_to_screen(fractional)).is_equal_approx(fractional)
	board.snap_enabled = true
	var saved_size: float = board.cell_size
	var saved_center: Vector2 = board.center
	board.cell_size = 35.0
	board.center += Vector2(30, 20)
	checks["projection_resize_independent"] = board.screen_to_world(board.world_to_screen(fractional)).is_equal_approx(fractional) and game.model.modules.has(Vector2.ZERO)
	board.cell_size = saved_size
	board.center = saved_center
	mark("fresh game")
	await select("solar")
	await click(game.get_viewport().get_canvas_transform() * (game.board.cell_position(Vector2i(1, 0))))
	await gather(45)
	await page(1)
	checks["ships_have_separate_page"] = game.hud.tabs.current_tab == 1 and game.hud.ship_buttons.size() == game.model.ship_catalog.size() and game.hud.ship_buttons.has("trader")
	var materials_before: int = game.model.materials
	game.hud.ship_buttons.miner.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.miner)
	await settle(2)
	await use(game.hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	checks["independent_miner_purchased"] = game.model.ships.get(miner) == "miner" and game.model.materials == materials_before - 45
	checks["ship_uses_power_not_grid"] = game.model.power_balance() == 4 and game.model.modules.size() == 2 and game.model.level == 1
	mark("miner purchased")
	await gather(35)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await use(game.hud.ship_buttons.scout)
	var scout: int = game.model.next_ship_id
	checks["scout_purchased"] = game.model.ships.get(scout) == "scout" and game.model.power_balance() == 3
	await use(game.hud.command_buttons[scout])
	checks["scout_survey_started"] = game.fleet.survey_jobs.has(scout)
	await gather(30)
	var attempts: int = 0
	while game.fleet.revealed_count() < 2 and attempts < 200:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["scout_reveals_sector"] = game.fleet.revealed_count() == 2
	var rich_target: int = -1
	for asteroid_id: int in game.fleet.asteroids:
		if game.fleet.asteroids[asteroid_id].minerals == 54:
			rich_target = asteroid_id
	checks["scout_reveals_rich_asteroid"] = rich_target != -1
	if rich_target == -1:
		report("checks", checks)
		finish()
		return
	await use(game.hud.command_buttons[miner])
	checks["explicit_miner_selected"] = game.asteroids.selected_ship == miner
	await click(game.get_viewport().get_canvas_transform() * (game.asteroids.rocks[rich_target].point))
	checks["assigned_target_reserved"] = game.fleet.jobs.has(miner) and game.fleet.jobs[miner].target == rich_target and game.fleet.asteroids[rich_target].claimed
	mark("assigned rich asteroid")
	await get_tree().create_timer(2.0).timeout
	checks["not_instant_mining"] = game.fleet.total_mined == 0
	await settle(2)
	save_frame("miner_assigned")
	attempts = 0
	while game.fleet.total_mined < 18 and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["first_cycle_credited"] = game.fleet.total_mined == 18 and game.model.minerals == 18
	checks["assignment_retained"] = game.fleet.jobs.has(miner) and game.fleet.asteroids[rich_target].claimed
	mark("first automatic cycle")
	attempts = 0
	while game.fleet.total_mined < 36 and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["second_cycle_without_click"] = game.fleet.total_mined == 36 and game.model.minerals == 36
	mark("second cycle without input")
	# Click existing Solar in inspect mode; no build tool remains selected after purchase.
	await click(game.get_viewport().get_canvas_transform() * (game.board.cell_position(Vector2i(1, 0))))
	checks["module_inspector_opens"] = game.hud.tabs.current_tab == 2 and game.hud.upgrade_title.text.contains("Tier 1")
	checks["upgrade_cost_visible"] = game.hud.upgrade_button.text.contains("30 Materials + 8 Minerals") and not game.hud.upgrade_button.disabled
	await settle(2)
	save_frame("upgrade_before")
	materials_before = game.model.materials
	var mineral_before: int = game.model.minerals
	var power_before: int = game.model.power_balance()
	await use(game.hud.upgrade_button)
	checks["upgrade_applies_stats"] = game.model.tier_at(Vector2(58, 0)) == 2 and game.model.power_balance() == power_before + 4
	checks["upgrade_pays_both_costs"] = game.model.materials == materials_before - 30 and game.model.minerals == mineral_before - 8
	checks["tier_and_next_shown"] = game.hud.upgrade_title.text.contains("Tier 2") and game.hud.upgrade_button.text.contains("Upgrade to T3") and game.hud.upgrade_detail.text.contains("T5")
	checks["no_upgrade_module_count_bonus"] = game.model.modules.size() == 2 and game.model.level == 1
	mark("solar upgraded")
	await settle(2)
	save_frame("upgrade_after")
	report("checks", checks)
	report("timeline", timeline)
	finish()

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
			var candidates: Array = game.debris.pieces.filter(func(piece: Dictionary) -> bool:
				var screen: Vector2 = game.get_viewport().get_canvas_transform() * piece.point
				return screen.x > 30 and screen.x < 780 and screen.y > 275 and screen.y < game.get_viewport_rect().size.y - 85)
			if candidates.is_empty():
				await get_tree().create_timer(0.3).timeout
				continue
			var point: Vector2 = candidates[0].point
			if point.x < 30:
				await get_tree().create_timer(0.3).timeout
				continue
			var before: int = game.model.materials
			await click(game.get_viewport().get_canvas_transform() * point)
			if game.model.materials > before:
				checks["debris_collection"] = true

func use(button: Control) -> void:
	if game.hud.ship_context.is_ancestor_of(button) and not button.is_visible_in_tree():
		for ship_id: int in game.hud.ship_entries:
			if game.hud.ship_entries[ship_id].is_ancestor_of(button):
				game.hud.ship_tray.ensure_control_visible(game.hud.ship_tiles[ship_id])
				await settle(2)
				await click(game.hud.ship_tiles[ship_id].get_global_rect().get_center())
				break
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
