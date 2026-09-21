extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}
var timeline: Array[Dictionary] = []

func mark(label: String) -> void:
	timeline.append({"label": label, "frame": Engine.get_process_frames(), "materials": game.model.materials, "minerals": game.model.minerals, "modules": game.model.modules.size(), "jobs": game.fleet.jobs.size(), "refined": game.model.total_refined})

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	mark("fresh game")
	var first_id: int = game.asteroids.rocks.keys()[0]
	var first_point: Vector2 = game.asteroids.rocks[first_id].point
	await click(first_point)
	checks["asteroid_requires_ship"] = game.model.minerals == 0 and game.fleet.jobs.is_empty()
	await get_tree().create_timer(0.3).timeout
	checks["asteroids_drift"] = game.asteroids.rocks[first_id].point.x > first_point.x
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	await gather(45)
	await select("mining_ship")
	await click(game.board.cell_position(Vector2i(0, 1)))
	checks["ship_built_with_cost_and_power"] = game.model.modules.get(Vector2(0, 58)) == "mining_ship" and game.model.power_balance() == 4
	mark("ship built")
	first_id = await visible_asteroid()
	await click(game.asteroids.rocks[first_id].point)
	checks["asteroid_click_dispatches"] = game.fleet.jobs.size() == 1 and game.model.minerals == 0
	checks["asteroid_click_does_not_build"] = game.model.modules.size() == 3
	mark("mission launched")
	await click(game.asteroids.rocks[first_id].point)
	checks["duplicate_click_no_extra_mission"] = game.fleet.jobs.size() == 1
	await get_tree().create_timer(2.0).timeout
	checks["mining_is_timed"] = game.model.minerals == 0 and game.fleet.jobs.size() == 1
	await settle(2)
	save_frame("mining_in_progress")
	var attempts: int = 0
	while game.model.minerals == 0 and attempts < 120:
		attempts += 1
		await get_tree().create_timer(0.2).timeout
	checks["minerals_delivered"] = game.model.minerals == 18 and game.fleet.jobs.is_empty()
	checks["depleted_asteroid_removed"] = not game.fleet.asteroids.has(first_id)
	checks["minerals_hud_updates"] = game.hud.minerals_label.text == "18"
	mark("mineral delivery")
	await settle(2)
	save_frame("minerals_delivered")
	await gather(40)
	await select("refinery")
	await click(game.board.cell_position(Vector2i(-1, 0)))
	checks["refinery_built_and_powered"] = game.model.modules.get(Vector2(-58, 0)) == "refinery" and game.model.power_balance() == 1
	var material_before: int = game.model.materials
	var mineral_before: int = game.model.minerals
	mark("refinery built")
	await get_tree().create_timer(1.0).timeout
	checks["refining_is_timed"] = game.model.materials == material_before and game.model.minerals == mineral_before
	attempts = 0
	while game.model.total_refined == 0 and attempts < 60:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["refining_converts_exact_resources"] = game.model.materials == material_before + 6 and game.model.minerals == mineral_before - 2
	checks["refined_materials_hud_updates"] = game.hud.materials_label.text.begins_with(str(game.model.materials) + " /")
	mark("first refined batch")
	await settle(2)
	save_frame("refining_complete")
	checks["periodic_asteroids_spawn"] = game.asteroids.next_id >= 2
	# Dispatch again after the first return; normal loop remains repeatable.
	var second_id: int = await visible_asteroid()
	await click(game.asteroids.rocks[second_id].point)
	checks["returned_ship_can_dispatch_again"] = game.fleet.jobs.size() == 1
	# Every catalog entry remains fully visible and clickable above the footer.
	await use(game.hud.menu_buttons.Build)
	var buttons_match_catalog: bool = true
	for kind: String in game.model.catalog:
		buttons_match_catalog = buttons_match_catalog and game.hud.tool_buttons.has(kind) and game.hud.tool_buttons[kind].visible == game.model.module_unlocked(kind)
	checks["module_catalog_reachable_in_build"] = buttons_match_catalog and game.hud.tool_buttons.size() == game.model.catalog.size()
	report("checks", checks)
	report("timeline", timeline)
	finish()

func visible_asteroid() -> int:
	for attempt in range(300):
		for asteroid_id: int in game.asteroids.rocks:
			if game.asteroids.rocks[asteroid_id].point.x > 45 and not game.fleet.asteroids[asteroid_id].claimed:
				return asteroid_id
		await get_tree().create_timer(0.2).timeout
	push_error("No clickable asteroid entered the sector")
	return -1

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
