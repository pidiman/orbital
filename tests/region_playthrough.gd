extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 3.0
	checks["player_checkpoint_isolated"] = not game.persistence.enabled
	var test_path: String = "user://orbital-region-ui-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	await select("solar")
	await click(game.board.cell_position(Vector2i(1, 0)))
	await gather(35)
	await page(1)
	await click(game.hud.ship_buttons.scout.get_global_rect().get_center())
	var scout: int = game.model.next_ship_id
	await gather(45)
	await click(game.hud.ship_buttons.miner.get_global_rect().get_center())
	var miner: int = game.model.next_ship_id
	var nav: Control = game.hud.region_navigation
	checks["home_indicator_and_overview"] = nav.location_label.text.contains("HOME") and nav.region_buttons.size() == 4
	checks["home_station_and_earth_visible"] = game.background.visible and game.board.visible and not game.region_view.visible
	var legacy: Dictionary = game.persistence.snapshot()
	legacy.extensions.erase("regions")
	var station_positions: Dictionary = game.model.modules.duplicate(true)
	await click(nav.region_buttons.venus.get_global_rect().get_center())
	checks["unexplored_region_panel"] = nav.panel.visible and nav.status_label.text == "UNKNOWN" and nav.jump_button.disabled
	checks["scout_travel_duration"] = nav.scout_picker.get_selected_id() == scout and nav.send_button.text.contains("6s")
	await click(nav.send_button.get_global_rect().get_center())
	checks["adjacent_survey_started"] = game.fleet.regions.survey_jobs.has(scout) and nav.status_label.text.contains("SURVEYING")
	checks["region_survey_autosaved"] = not game.persistence.dirty and FileAccess.file_exists(test_path)
	await wait_region("venus")
	checks["survey_unlocks_random_content"] = not nav.jump_button.disabled and game.fleet.regions.records.venus.asteroid_ids.size() >= 2
	await click(nav.jump_button.get_global_rect().get_center())
	checks["jump_changes_indicator"] = game.fleet.regions.current_region == "venus" and nav.location_label.text.contains("VENUS")
	checks["planet_replaces_home_view"] = not game.background.visible and not game.board.visible and game.region_view.visible and not game.debris.visible
	checks["regional_asteroids_rendered"] = game.asteroids.rocks.size() == game.fleet.regions.records.venus.asteroid_ids.size()
	checks["station_fixed_home_only"] = game.model.modules == station_positions and game.hud.tool_buttons.solar.disabled and not game.board.is_processing_unhandled_input()
	await settle(3)
	save_frame("venus_region")
	var target: int = game.fleet.regions.records.venus.asteroid_ids[0]
	await click(game.hud.command_buttons[miner].get_global_rect().get_center())
	await click(game.asteroids.rocks[target].point)
	checks["regional_asteroid_click_mines"] = game.fleet.jobs.has(miner) and game.fleet.jobs[miner].target == target
	game.get_node("ResourceClock").set_process(false)
	await click(game.hud.save_button.get_global_rect().get_center())
	var expected: Dictionary = game.persistence.snapshot()
	var markers: Dictionary = game.asteroids.rocks.duplicate(true)
	game.persistence.autosave_blocked = true
	await click(nav.region_buttons.home.get_global_rect().get_center())
	checks["home_return_restores_original_view"] = game.background.visible and game.board.visible and game.fleet.regions.current_region == "home"
	await click(game.hud.load_button.get_global_rect().get_center())
	nav = game.hud.region_navigation
	checks["save_load_exact_remote_state"] = game.persistence.snapshot() == expected
	checks["save_load_location_and_content_visible"] = nav.location_label.text.contains("VENUS") and game.asteroids.rocks == markers and not game.board.visible
	checks["regional_rng_and_contents_stable"] = expected.extensions.regions.records == game.persistence.snapshot().extensions.regions.records
	game.persistence.enabled = false
	game.queue_free()
	await get_tree().process_frame
	var scene: PackedScene = load("res://orbital.tscn")
	game = scene.instantiate()
	game.save_path = test_path
	game.verification_persistence = true
	game.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = game
	nav = game.hud.region_navigation
	checks["remote_fresh_start_restores_exact_state"] = game.persistence.snapshot() == expected
	checks["remote_startup_rebuilds_planet_view"] = nav.location_label.text.contains("VENUS") and not game.board.visible and game.region_view.visible
	game.get_node("ResourceClock").set_process(false)
	game.process_mode = Node.PROCESS_MODE_INHERIT
	await click(nav.region_buttons.home.get_global_rect().get_center())
	game.get_node("ResourceClock").set_process(true)
	var before: int = game.model.minerals
	var attempts: int = 0
	while game.model.minerals == before and attempts < 150:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["remote_mining_continues_at_home"] = game.model.minerals > before and game.fleet.regions.current_region == "home"
	# Multi-hop route: survey Mars, visit it, then scout Pluto.
	await click(nav.region_buttons.pluto.get_global_rect().get_center())
	checks["pluto_blocked_from_home"] = nav.send_button.disabled and nav.jump_button.disabled
	await click(nav.route_buttons.mars.get_global_rect().get_center())
	await click(nav.send_button.get_global_rect().get_center())
	await wait_region("mars")
	await click(nav.jump_button.get_global_rect().get_center())
	await settle(3)
	save_frame("mars_region")
	await click(nav.region_buttons.pluto.get_global_rect().get_center())
	checks["pluto_adjacent_from_mars"] = not nav.send_button.disabled
	await click(nav.send_button.get_global_rect().get_center())
	await wait_region("pluto")
	await click(nav.jump_button.get_global_rect().get_center())
	checks["multi_hop_pluto_location"] = nav.location_label.text.contains("PLUTO") and game.fleet.regions.current_region == "pluto"
	await settle(3)
	save_frame("pluto_region")
	game.get_node("ResourceClock").set_process(false)
	# A real old-format JSON file, restored with the same Load button.
	game.persistence.autosave_blocked = true
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy, "\t", false, true))
	file.close()
	await click(game.hud.load_button.get_global_rect().get_center())
	checks["old_save_loads_home_ui"] = game.fleet.regions.current_region == "home" and game.hud.region_navigation.location_label.text.contains("HOME") and game.board.visible and game.background.visible
	checks["old_save_preserves_core_state"] = game.persistence.snapshot().state == legacy.state
	checks["runtime_stays_2d"] = no_3d(game)
	await settle(3)
	save_frame("restored_home")
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	report("checks", checks)
	finish()

func wait_region(region_id: String) -> void:
	var attempts: int = 0
	while not game.fleet.regions.is_discovered(region_id) and attempts < 200:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	await settle(3)

func page(index: int) -> void:
	var bar: TabBar = game.hud.tabs.get_tab_bar()
	await click(bar.global_position + bar.get_tab_rect(index).get_center())

func no_3d(node: Node) -> bool:
	if node.is_class("Node3D"):
		return false
	for child: Node in node.get_children():
		if not no_3d(child):
			return false
	return true

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up, true)
	await settle(2)

func select(kind: String) -> void:
	var button: Button = game.hud.tool_buttons[kind]
	await click(button.get_global_rect().get_center())

func gather(target: int) -> void:
	var attempts: int = 0
	while game.model.materials < target and attempts < 500:
		attempts += 1
		if game.debris.pieces.is_empty():
			await get_tree().create_timer(0.4).timeout
		else:
			var point: Vector2 = game.debris.pieces[0].point
			if point.x < 30:
				await get_tree().create_timer(0.3).timeout
				continue
			var before: int = game.model.materials
			await click(point)
			if game.model.materials > before:
				checks["debris_collection"] = true
