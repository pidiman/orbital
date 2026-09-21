extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	# Disposable comparison gallery, existing spawn path and unchanged definitions.
	var found: Dictionary = {}
	var xeno: int = -1
	for i in range(1000):
		game.supply._spawn_debris()
		var id: int = game.supply.next_debris_id
		var piece: Dictionary = game.supply.floating.home.pieces[id]
		if piece.resource == "materials": found[piece.visual_variant] = id
		if piece.resource == "xenocrystal": xeno = id
		if found.size() == 5 and xeno > 0: break
	var gallery: Dictionary = {}
	var index: int = 0
	for id: int in found.values() + [xeno]:
		gallery[id] = game.supply.floating.home.pieces[id]
		gallery[id].position = Vector2(0.1 + index * 0.15, 0.65)
		index += 1
	game.supply.floating.home.pieces = gallery
	for target: int in game.fleet.resource_targets.keys():
		game.fleet.asteroids.erase(target)
	game.fleet.resource_targets.clear()
	game.supply.sync_mining_nodes()
	game.asteroids._sync_view()
	game.debris._sync_view()
	var target: int = game.supply.mining_target("home", xeno)
	var before: Dictionary = game.persistence.snapshot()
	for zoom: float in [0.15, 1.0, 2.0]:
		game.ship_camera.zoom_view(zoom / game.ship_camera.zoom.x)
		game.ship_camera.position = game.board.center + Vector2(0, 45)
		game.ship_camera.force_update_scroll()
		await settle(3)
		var module_width: float = game.board.cell_size * zoom
		var crystal_width: float = 56 * game.asteroids._marker_scale(target) * zoom
		checks["crystal_ratio_%s" % zoom] = is_equal_approx(crystal_width / module_width, 56.0 * 0.75 / 58.0)
		checks["crystal_smaller_%s" % zoom] = crystal_width < module_width
		for piece: Dictionary in game.debris.pieces:
			if piece.resource != "materials": continue
			var width: float = 40 * game.debris._visual_scale(piece) * zoom
			checks["%s_ratio_%s" % [piece.visual_variant, zoom]] = is_equal_approx(width / module_width, 40.0 / 58.0)
		save_frame("zoom_%s" % zoom)
	checks.game_unchanged = before == game.persistence.snapshot()
	report("checks", checks)
	finish()
