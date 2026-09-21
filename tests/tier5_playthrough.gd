extends "res://tests/ship_tray_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 10000
	game.model.minerals = 1000
	game.supply.debris.clear()
	game.debris._sync_view()
	for x in range(1, 5): game.model.build(Vector2(x * 58, 0), "solar")
	game.model.build(Vector2(0, 58), "miner_dock")
	for i in range(8): game.model.buy_ship("miner")
	for point: Vector2 in [Vector2(58, 0), Vector2(0, 58)]:
		hud.close_panels()
		await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(point))
		var kind: String = game.model.modules[point]
		checks[kind + " compact preview"] = hud.upgrade_detail.text.begins_with("Next:") and not hud.upgrade_detail.text.contains("T5") and hud.upgrade_detail.text.contains("Materials")
		for tier in range(2, 6):
			var upgrade: Dictionary = game.model.next_upgrade(point)
			var funds: int = game.model.materials
			checks["%s T%d preview" % [kind, tier]] = hud.upgrade_button.text.contains("T%d" % tier) and hud.upgrade_detail.text.contains(upgrade.description)
			await use(hud.upgrade_button)
			checks["%s T%d UI upgrade" % [kind, tier]] = game.model.tier_at(point) == tier and game.model.materials == funds - int(upgrade.cost.materials) and hud.upgrade_title.text.contains("Tier %d" % tier)
			if kind == "miner_dock": checks["dock T%d slots" % tier] = game.fleet.docking.usage[game.model.structure_id_at(point)].size() == int(game.model.definition_at(point).docking.capacity)
		checks[kind + " max UI"] = hud.upgrade_button.disabled and hud.upgrade_detail.text.contains("Maxed") and not hud.upgrade_detail.text.contains("Next:")
		checks[kind + " footer clearance"] = hud.panel.get_global_rect().end.y < hud.footer.position.y
		save_frame(kind + "_tier5")
	# Insufficient Materials is visible as disabled button + clear tooltip.
	hud.inspect_module(Vector2(116, 0))
	game.model.materials = 0
	game.model.changed.emit()
	await settle(2)
	checks.short_materials_UI = hud.upgrade_button.disabled and hud.upgrade_button.tooltip_text.contains("Materials") and hud.upgrade_detail.text.contains("Upgrade needs")
	var path: String = "user://orbital-tier5-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	await use(hud.save_button)
	var expected: Dictionary = game.persistence.snapshot()
	game.persistence.autosave_blocked = true
	game.model.materials = 1
	await use(hud.load_button)
	await settle(3)
	checks.disk_roundtrip = game.persistence.snapshot() == expected and game.model.tier_at(Vector2(58, 0)) == 5 and game.fleet.docking.usage[game.model.structure_id_at(Vector2(0, 58))].size() == 8
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	checks.only_2d = no_3d(game)
	report("checks", checks)
	finish()
