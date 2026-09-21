extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var stock = game.supply
	print("Resolved floating spawn table: ", JSON.stringify(stock.floating_rules))
	report("resolved_spawn_table", stock.floating_rules)
	# Optional read-only reproduction from a local save; never overwrite it.
	var audit_path: String = OS.get_environment("ORBITAL_AUDIT_SAVE")
	if not audit_path.is_empty():
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(audit_path))
		report("existing_save_restore", game.persistence.restore(saved))
	else:
		var model := StationModel.new()
		var fleet := MiningFleet.new(model)
		fleet.regions.records = RegionModel.new(0).records
		fleet._discover_region("venus")
		var seeded := SectorSupply.new(model, fleet, 0)
		var store = preload("res://scripts/save_store.gd").new(model, fleet, seeded)
		checks.fixture = game.persistence.restore(store.snapshot()).is_empty()
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	var visible_nodes: int = 0
	for tick in range(1200):
		stock.advance_floating(1.0)
		for region: String in stock.floating:
			if not counts.has(region): counts[region] = {"materials": 0, "minerals": 0, "xenocrystal": 0}
			for id: int in stock.floating[region].pieces:
				if seen.has(id): continue
				seen[id] = true
				var piece: Dictionary = stock.floating[region].pieces[id]
				counts[region][piece.resource] += 1
				if region == "home" and piece.resource == "xenocrystal":
					game.asteroids._sync_view()
					var target: int = stock.mining_target(region, id)
					var screen: Vector2 = game.get_viewport().get_canvas_transform() * game.asteroids.rocks[target].point
					if game.get_viewport_rect().has_point(screen) and not game.hud.pointer_over_ui(screen): visible_nodes += 1
					if not checks.has("captured"):
						checks.captured = true
						game.ship_camera.position = game.asteroids.rocks[target].point
						game.ship_camera.force_update_scroll()
						await settle(2)
						save_frame("xeno_crystal")
						game.ship_camera.zoom_view(0.2)
						await settle(2)
						save_frame("xeno_zoomed_out")
						checks.world_scale = is_equal_approx(game.asteroids._marker_scale(target), 0.75 * game.board.cell_size / 58.0)
						checks.mining_only = stock.salvage(id, Callable(), -1, region) == 0
						game.ship_camera.reset_view()
	report("generated_over_20_minutes", counts)
	report("home_nodes_visible_at_default_camera", visible_nodes)
	for region: String in counts:
		checks[region + "_spawns_xeno"] = counts[region].xenocrystal > 0 and counts[region].xenocrystal < counts[region].materials
	checks.crystal_visual = stock.floating_rules.types.xenocrystal.get("visual") == "crystal"
	checks.crystal_label = stock.floating_rules.types.xenocrystal.get("label") == "Xenocrystals"
	var saved_state: Dictionary = game.persistence.snapshot()
	stock.advance(30.0)
	var expected: Dictionary = game.persistence.snapshot()
	checks.restore = game.persistence.restore(saved_state).is_empty()
	stock.advance(30.0)
	checks.seeded_continuation = game.persistence.snapshot() == expected
	report("checks", checks)
	finish()
