extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var stock = game.supply
	var hud = game.hud
	game.model.materials = 0
	for kind: String in ["materials", "minerals", "xenocrystal"]:
		stock.floating.home.pieces.clear()
		stock._spawn_debris()
		var piece: Dictionary = stock.floating.home.pieces[stock.next_debris_id]
		piece.position = Vector2(0.88, 0.8)
		piece.resource = kind
		piece.amount = 1
		game.debris._sync_view()
		game.ship_camera.position = game.debris.pieces[0].point
		game.ship_camera.force_update_scroll()
		await settle(2)
		var before: int = game.model.materials if kind == "materials" else (game.model.minerals if kind == "minerals" else game.fleet.diplomacy.inventory.xenocrystal)
		await click(game.get_viewport_rect().size * 0.5)
		var after: int = game.model.materials if kind == "materials" else (game.model.minerals if kind == "minerals" else game.fleet.diplomacy.inventory.xenocrystal)
		checks["click_" + kind] = after == before + 1
	game.fleet._discover_region("venus")
	game.fleet.regions.set_location("venus")
	stock.advance(0.05)
	await settle(2)
	checks.remote_visible = game.debris.visible and game.debris.pieces.size() == 5
	game.fleet.regions.set_location("home")
	game.model.materials = 1000
	game.model.build(Vector2(58, 0), "solar")
	game.model.build(Vector2(-58, 0), "space_depot")
	game.model.buy_ship("material_ship")
	var id: int = game.model.next_ship_id
	stock.floating.home.pieces.clear()
	for kind: String in ["minerals", "xenocrystal", "materials"]:
		stock._spawn_debris()
		var piece: Dictionary = stock.floating.home.pieces[stock.next_debris_id]
		piece.resource = kind
		piece.position = Vector2(0.5, 0.5)
		piece.amount = 3 if kind == "materials" else 1
	checks.deploy = stock.collection.deploy(id).is_empty()
	stock.collection.advance(0.1)
	checks.material_only_one = stock.collection.jobs[id].cargo == 1 and stock.floating.home.pieces[stock.next_debris_id].amount == 2 and stock.floating.home.pieces.size() == 3
	game.model.materials = 0
	stock.collection.advance(10)
	checks.deposit = game.model.materials == 1 and stock.collection.jobs[id].cargo == 0
	await use(hud.menu_buttons.Menu)
	checks.menu_styles = hud.settings_button.get_theme_stylebox("normal") == hud.save_button.get_theme_stylebox("normal") and hud.settings_button.get_theme_stylebox("hover") == hud.load_button.get_theme_stylebox("hover")
	save_frame("menu_style")
	hud.close_panels()
	game.ship_camera.fit_grid()
	await settle(2)
	save_frame("expanded_resources")
	report("checks", checks)
	finish()
