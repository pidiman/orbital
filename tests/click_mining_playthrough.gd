extends "res://tests/outpost_playthrough.gd"

func click_target(target: int) -> void:
	game.asteroids._sync_view()
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[target].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport_rect().size * 0.5)

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	checks.build_catalog = not hud.tool_buttons.has("mining_ship") and hud.tool_buttons.has("space_dock")
	game.model.materials = 1000
	for i in range(1, 5): game.model.build(Vector2(i * 58, 0), "solar")
	game.model.build(Vector2(0, 58), "space_dock")
	await use(hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	checks.parks = game.fleet.docking.ships[miner].state == "parked"
	await use(hud.ship_tiles[miner])
	checks.no_assign_mode = game.asteroids.selected_ship == -1
	await click_target(1)
	checks.direct_click = game.fleet.jobs.has(miner) and game.fleet.jobs[miner].target == 1
	checks.dock_freed = game.fleet.docking.ships[miner].state == "working"
	for tick in range(8): game.fleet.tick()
	checks.unchanged_yield = game.model.minerals == 18 and not game.fleet.jobs.has(miner)
	checks.returns_to_dock = game.fleet.docking.ships[miner].state == "parked"
	game.supply._spawn_asteroid()
	var ore: int = game.supply.next_home_id
	await use(hud.capability_buttons[miner].mining)
	await click_target(ore)
	checks.assign_command = game.fleet.jobs.has(miner) and game.fleet.jobs[miner].target == ore
	await use(hud.ship_buttons.xeno_miner)
	var xeno: int = game.model.next_ship_id
	for kind: String in game.supply.floating_rules.types: game.supply.floating_rules.types[kind].weight = 1 if kind == "xenocrystal" else 0
	game.supply._spawn_debris()
	var piece: int = game.supply.next_debris_id
	game.supply.floating.home.pieces[piece].position = Vector2(0.3, 0.75)
	var node: int = game.supply.mining_target("home", piece)
	await use(hud.ship_tiles[xeno])
	await click_target(node)
	checks.xeno_direct = game.fleet.jobs.has(xeno) and game.fleet.jobs[xeno].target == node and game.fleet.jobs[xeno].duration == 20
	for tick in range(20): game.fleet.tick()
	checks.xeno_yield = game.fleet.diplomacy.inventory.xenocrystal == 1
	# No highlighted ship retains the existing auto-dispatch behavior.
	hud.close_panels()
	hud.deselect_ship()
	game.supply._spawn_asteroid()
	await click_target(game.supply.next_home_id)
	checks.unselected_auto_dispatch = game.fleet.jobs.has(miner)
	for kind: String in game.supply.floating_rules.types: game.supply.floating_rules.types[kind].weight = 1 if kind == "materials" else 0
	game.supply._spawn_debris()
	var material: int = game.supply.next_debris_id
	game.supply.floating.home.pieces[material].position = Vector2(0.6, 0.6)
	game.model.materials = 0
	game.ship_camera.position = Vector2(0.6 * 900, 145 + 0.6 * 605)
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport_rect().size * 0.5)
	checks.salvage = game.model.materials > 0
	await use(hud.menu_buttons.Build)
	save_frame("ships_only_mining")
	report("checks", checks)
	finish()
