extends "res://tests/hud_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	var initial_level: String = hud.level_label.text
	game.model.materials = 10000
	game.model.minerals = 100
	for x in range(1, 4): game.model.build(Vector2(x * 58, 0), "solar")
	game.model.build(Vector2(0, 58), "refinery")
	game.model.buy_ship("miner")
	await settle(3)
	checks.level_live = initial_level != hud.level_label.text and hud.level_label.text.contains("Level 02")
	checks.refinery_live = hud.refinery_label.text.contains("1") and hud.refinery_label.text.contains("storage full")
	checks.miner_live = hud.fleet_label.text.contains("1 idle / 1 total")
	var target: int = game.asteroids.rocks.keys()[0]
	game.fleet.dispatch(target, 1)
	await settle(2)
	checks.miner_busy_live = hud.fleet_label.text.contains("0 idle / 1 total")
	for i in range(8): game.fleet.tick()
	await settle(2)
	checks.miner_idle_live = hud.fleet_label.text.contains("1 idle / 1 total")
	game.model.materials = 0
	game.model.changed.emit()
	await settle(2)
	checks.refinery_unpaused_live = not hud.refinery_label.text.contains("storage full")
	game.model.materials = 10000
	game.model.changed.emit()
	for tier in range(1, 6):
		var before: Dictionary = game.persistence.snapshot()
		hud.inspect_module(Vector2(58, 0))
		await settle(3)
		checks["T%d current" % tier] = hud.upgrade_title.text.contains("Tier %d" % tier) and hud.upgrade_stats.text.contains(str(int(game.model.definition_at(Vector2(58, 0)).power_output)))
		checks["T%d no full list" % tier] = not hud.upgrade_detail.text.contains("T1") and not hud.upgrade_detail.text.contains("[CURRENT]") and not hud.upgrade_detail.text.contains("NEXT T")
		checks["T%d view only" % tier] = before == game.persistence.snapshot()
		if tier < 5:
			checks["T%d next" % tier] = hud.upgrade_detail.text.begins_with("Next:") and hud.upgrade_detail.text.contains(game.model.upgrade_cost_text(game.model.next_upgrade(Vector2(58, 0)).cost))
			if tier == 2: save_frame("compact_current_next")
			await use(hud.upgrade_button)
		else:
			checks.maxed_only = hud.upgrade_detail.text.contains("Maxed") and not hud.upgrade_detail.text.contains("Next:")
			save_frame("compact_maxed")
	for dimensions: Vector2i in [Vector2i(1280, 860), Vector2i(960, 720)]:
		get_window().content_scale_size = dimensions
		get_window().size = dimensions
		await settle(5)
		for menu: String in hud.menu_buttons:
			hud.close_panels()
			await touch(hud.menu_buttons[menu])
			for label: Label in [hud.fleet_label, hud.refinery_label, hud.level_label]:
				checks["%s %s %s bar" % [dimensions, menu, label.name]] = label.is_visible_in_tree() and hud.resource_bar.is_ancestor_of(label) and hud.resource_bar.get_global_rect().encloses(label.get_global_rect()) and not hud.panel.is_ancestor_of(label) and not hud.toolbar.is_ancestor_of(label)
			checks["%s %s clearance" % [dimensions, menu]] = hud.resource_bar.get_global_rect().end.y <= hud.ship_tray.get_global_rect().position.y and hud.ship_tray.get_global_rect().end.y < hud.panel.position.y
		save_frame("resource_bar_%d" % dimensions.x)
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()
