extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 10000
	for i in range(1, 12): game.model.build(Vector2(i * 58, 0), "solar")
	for kind: String in game.model.ship_catalog: game.model.buy_ship(kind)
	await settle(3)
	checks.three_primary = hud.toolbar.get_child_count() == 4 and not hud.menu_buttons["Gate/Travel"].is_visible_in_tree()
	checks.seven_roles = hud.ship_tiles.size() == game.model.ship_catalog.size()
	checks.compact_height = hud.ship_tray.get_global_rect().end.y <= 134
	checks.resources_beside_menu = hud.compact_resources.position.x >= hud.menu_scroll.get_global_rect().end.x
	checks.status_above_tray = hud.resource_status.get_global_rect().end.y < hud.ship_tray.position.y
	checks.menus_reachable = true
	for name: String in hud.menu_buttons:
		await use(hud.menu_buttons[name])
		var count: int = 0
		for panel: PanelContainer in hud.managed_panels:
			if panel.visible: count += 1
		checks.menus_reachable = checks.menus_reachable and count == 1
		hud.close_panels()
	var miner: int = game.model.ships.keys()[0]
	var before: Dictionary = game.persistence.snapshot()
	var camera: Vector2 = game.ship_camera.position
	var zoom: Vector2 = game.ship_camera.zoom
	await use(hud.ship_tiles[miner])
	checks.selection = hud.selected_ship_id == miner and hud.ship_tiles[miner].selected_ship and hud.ship_context.visible
	checks.camera_unchanged = game.ship_camera.position == camera and game.ship_camera.zoom == zoom
	checks.model_unchanged = before == game.persistence.snapshot()
	checks.small_tiles = hud.ship_tiles[miner].size.y == 28 and hud.ship_tiles[miner].role == "Miner 1"
	hud.close_panels()
	await use(hud.menu_buttons.Ships)
	var count: int = game.model.ships.size()
	await use(hud.ship_buttons.miner)
	checks.buy_reachable = game.model.ships.size() == count + 1
	hud.close_panels()
	checks.resources_live = hud.materials_label.text.contains(str(game.model.materials)) and hud.power_label.tooltip_text.contains("generated")
	save_frame("compact_hud")
	report("checks", checks)
	finish()
