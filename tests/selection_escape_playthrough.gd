extends "res://tests/outpost_playthrough.gd"

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event, true)
	await settle(2)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	get_viewport().push_input(event, true)
	await settle(2)

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var hud = game.hud
	game.model.materials = 1000
	game.model.build(Vector2(58, 0), "solar")
	game.model.buy_ship("miner")
	var first: int = game.model.next_ship_id
	game.model.buy_ship("miner")
	var second: int = game.model.next_ship_id
	game.fleet.dispatch(1, first)
	var snapshot: Dictionary = game.persistence.snapshot()
	await use(hud.ship_tiles[first])
	checks.selected = hud.selected_ship_id == first and hud.ship_tiles[first].selected_ship and hud.ship_context.visible
	await escape()
	checks.first_escape = not hud.ship_context.visible and hud.selected_ship_id == first and hud.ship_tiles[first].selected_ship
	save_frame("first_escape_selected")
	await escape()
	checks.second_escape = hud.selected_ship_id == -1 and hud.ship_tiles.values().all(func(tile: Control) -> bool: return not tile.selected_ship)
	checks.map_ring_cleared = not game.model.ships.has(hud.selected_ship_id)
	checks.job_unchanged = snapshot == game.persistence.snapshot() and game.fleet.jobs.has(first)
	save_frame("second_escape_deselected")
	await use(hud.ship_tiles[first])
	await use(hud.ship_tiles[second])
	checks.selection_moves = hud.selected_ship_id == second and hud.ship_tiles[second].selected_ship and not hud.ship_tiles[first].selected_ship
	await use(hud.panel_closes[hud.ship_context.get_instance_id()])
	checks.close_keeps_selection = not hud.ship_context.visible and hud.selected_ship_id == second and hud.ship_tiles[second].selected_ship
	await escape()
	checks.escape_after_close_deselects = hud.selected_ship_id == -1 and not hud.ship_tiles[second].selected_ship
	var path: String = "user://selection-escape-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	await use(hud.save_button)
	checks.save_closed = not hud.menu_panel.visible and hud.active_menu.is_empty() and FileAccess.file_exists(path)
	checks.saved_confirmation = hud.status_label.text.contains("saved")
	game.persistence.autosave_blocked = true
	game.model.add_minerals(1)
	await use(hud.load_button)
	checks.load_closed = not hud.menu_panel.visible and hud.active_menu.is_empty()
	checks.load_roundtrip = snapshot == game.persistence.snapshot()
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await use(hud.settings_button)
	checks.settings_still_opens = hud.settings_panel.visible and not hud.menu_panel.visible
	report("checks", checks)
	finish()
