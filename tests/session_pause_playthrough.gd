extends "res://tests/outpost_playthrough.gd"

func space() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	get_viewport().push_input(event, true)
	await settle(2)
	event = InputEventKey.new()
	event.keycode = KEY_SPACE
	get_viewport().push_input(event, true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.model.materials = 1000
	game.model.minerals = 100
	game.model.build(Vector2(58, 0), "solar")
	game.model.build(Vector2(116, 0), "solar")
	game.model.build(Vector2(0, 58), "refinery")
	game.model.buy_ship("miner")
	var miner: int = game.model.next_ship_id
	checks.mining_active = game.fleet.dispatch(1, miner).is_empty()
	await settle(2)
	game.hud.inspect_module(Vector2(0, 58))
	await space()
	checks.paused = get_tree().paused and game.session_pause.indicator.visible and game.session_pause.button.text == "▶"
	var before: Dictionary = game.persistence.snapshot()
	var motion: Dictionary = game.ship_motion.points.duplicate(true)
	var mining: Dictionary = game.fleet.jobs.duplicate(true)
	var camera: Vector2 = game.ship_camera.position
	var status_time: float = game.hud.status_time
	await get_tree().create_timer(1.3, true).timeout
	checks.ship_frozen = motion == game.ship_motion.points and mining == game.fleet.jobs
	checks.simulation_frozen = before == game.persistence.snapshot() and status_time == game.hud.status_time and camera == game.ship_camera.position
	await click(game.hud.upgrade_button.get_global_rect().get_center())
	await click(Vector2(500, 500))
	var debug := InputEventKey.new()
	debug.keycode = KEY_F9
	debug.pressed = true
	get_viewport().push_input(debug, true)
	await settle(2)
	checks.input_blocked = before == game.persistence.snapshot() and not game.hud.dev_panel.visible
	save_frame("paused")
	var close: Button = game.hud.panel_closes[game.hud.panel.get_instance_id()]
	await click(close.get_global_rect().get_center())
	checks.close_allowed = not game.hud.panel.visible and get_tree().paused
	await click(game.session_pause.button.get_global_rect().get_center())
	checks.icon_resume = not get_tree().paused and not game.session_pause.indicator.visible
	await get_tree().create_timer(1.2, true).timeout
	checks.resumes = before != game.persistence.snapshot() and game.model.ticks > int(game.persistence._decode(before.state.station.ticks))
	checks.mining_resumes = mining != game.fleet.jobs
	await click(game.session_pause.button.get_global_rect().get_center())
	checks.icon_pause = get_tree().paused
	await space()
	checks.space_resume = not get_tree().paused
	# A focused gameplay button must not also activate through Godot ui_accept.
	game.hud.inspect_module(Vector2(0, 58))
	game.hud.upgrade_button.grab_focus()
	var tier: int = game.model.tier_at(Vector2(0, 58))
	await space()
	checks.space_not_accept = get_tree().paused and game.model.tier_at(Vector2(0, 58)) == tier
	var path: String = "user://pause-test-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	checks.save_paused = game.persistence.save_game().is_empty() and get_tree().paused
	checks.load_running = game.persistence.load_game().is_empty() and not get_tree().paused and game.session_pause.button.text == "Ⅱ"
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	report("checks", checks)
	finish()
