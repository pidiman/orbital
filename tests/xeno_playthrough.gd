extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 1000
	for i in range(1, 5): game.model.build(Vector2(i * 58, 0), "solar")
	await use(hud.ship_buttons.xeno_miner)
	var id: int = game.model.next_ship_id
	checks.catalog = game.model.ships[id] == "xeno_miner"
	checks.tray_role = hud.ship_tiles.has(id) and game.model.ship_catalog[game.model.ships[id]].name == "Xeno Miner"
	for kind: String in game.supply.floating_rules.types: game.supply.floating_rules.types[kind].weight = 1 if kind == "xenocrystal" else 0
	game.supply._spawn_debris()
	var piece: int = game.supply.next_debris_id
	var node: int = game.supply.mining_target("home", piece)
	game.supply.floating.home.pieces[piece].position = Vector2(0.85, 0.7)
	await use(hud.capability_buttons[id].mining)
	checks.assign_menu = game.asteroids.selected_ship == id
	game.asteroids._sync_view()
	game.ship_camera.ship_id = -1
	game.ship_camera.position = game.asteroids.rocks[node].point
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport_rect().size * 0.5)
	checks.click_assign = game.fleet.jobs.has(id) and game.fleet.jobs[id].target == node and game.fleet.jobs[id].duration == 20
	await settle(3)
	save_frame("xeno_extraction")
	var path: String = "user://xeno-playthrough-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	await use(hud.save_button)
	var before: Dictionary = game.persistence.snapshot()
	await use(hud.load_button)
	checks.disk_roundtrip = before == game.persistence.snapshot()
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for tick in range(19): game.fleet.tick()
	checks.waits = game.fleet.diplomacy.inventory.xenocrystal == 0
	game.fleet.tick()
	checks.credit = game.fleet.diplomacy.inventory.xenocrystal == 1 and not game.fleet.jobs.has(id)
	# Materials remain click-salvageable through the same field handler.
	for kind: String in game.supply.floating_rules.types: game.supply.floating_rules.types[kind].weight = 1 if kind == "materials" else 0
	game.supply._spawn_debris()
	var material: int = game.supply.next_debris_id
	game.supply.floating.home.pieces[material].position = Vector2(0.2, 0.7)
	game.model.materials = 0
	hud.close_panels()
	game.debris._sync_view()
	game.ship_camera.position = Vector2(0.2 * 900, 145 + 0.7 * 605)
	game.ship_camera.force_update_scroll()
	await settle(2)
	await click(game.get_viewport_rect().size * 0.5)
	checks.material_salvage = game.model.materials > 0
	report("checks", checks)
	finish()
