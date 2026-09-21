extends "res://tests/autopilot/probe_base.gd"
const Store = preload("res://scripts/save_store.gd")
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	checks["verification_isolated_from_player_save"] = not game.persistence.enabled
	var test_path: String = "user://orbital-ui-test-%d.json" % OS.get_process_id()
	game.persistence.path = test_path
	game.persistence.enabled = true
	Engine.time_scale = 3.0
	await select("solar")
	await click(game.get_viewport().get_canvas_transform() * (game.board.cell_position(Vector2i(1, 0))))
	checks["build_autosaves"] = FileAccess.file_exists(test_path) and not game.persistence.dirty
	await gather(45)
	await page(1)
	game.hud.ship_buttons.miner.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.miner)
	await settle(2)
	await use(game.hud.ship_buttons.miner)
	var miner: int = game.model.next_ship_id
	await gather(35)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await use(game.hud.ship_buttons.scout)
	var scout: int = game.model.next_ship_id
	await use(game.hud.command_buttons[miner])
	var asteroid_id: int = game.asteroids.rocks.keys()[0]
	await click(game.get_viewport().get_canvas_transform() * (game.asteroids.rocks[asteroid_id].point))
	await use(game.hud.command_buttons[scout])
	game.get_node("ResourceClock").set_process(false)
	checks["active_jobs_before_save"] = game.fleet.jobs.has(miner) and game.fleet.survey_jobs.has(scout)
	await use(game.hud.save_button)
	checks["save_button_feedback"] = game.hud.status_label.text.contains("Colony saved")
	var expected: Dictionary = game.persistence.snapshot()
	var next_id: int = game.model.next_ship_id
	var mining_remaining: int = game.fleet.jobs[miner].remaining
	var survey_remaining: int = game.fleet.survey_jobs[scout].remaining
	save_frame("saved_active_jobs")
	# Simulate an unsaved change without allowing autosave to replace the checkpoint.
	game.persistence.enabled = false
	await use(game.hud.sell_buttons[miner])
	checks["session_changed_after_save"] = not game.model.ships.has(miner)
	game.persistence.enabled = true
	game.persistence.autosave_blocked = true
	await use(game.hud.load_button)
	checks["load_button_restores_exact_state"] = game.persistence.snapshot() == expected
	checks["load_restores_jobs_and_ids"] = game.fleet.jobs[miner].remaining == mining_remaining and game.fleet.survey_jobs[scout].remaining == survey_remaining and game.model.next_ship_id == next_id
	checks["load_refreshes_hud_and_views"] = game.hud.command_buttons.has(miner) and game.asteroids.rocks.has(asteroid_id) and game.hud.materials_label.text.begins_with(str(game.model.materials) + " /")
	save_frame("loaded_active_jobs")
	# Real scene teardown + fresh startup exercises automatic resume without the player slot.
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
	checks["fresh_start_auto_resumes_exact_state"] = game.persistence.snapshot() == expected
	checks["resume_status_visible"] = game.hud.status_label.text.contains("Colony restored")
	checks["entire_runtime_2d"] = no_3d(game)
	game.process_mode = Node.PROCESS_MODE_INHERIT
	var attempts: int = 0
	while (game.fleet.total_mined == 0 or game.fleet.sector_state("dawn") != "revealed") and attempts < 250:
		attempts += 1
		await get_tree().create_timer(0.1).timeout
	checks["restored_jobs_complete"] = game.fleet.total_mined == 18 and game.fleet.sector_state("dawn") == "revealed"
	checks["discovery_autosave_runs"] = not game.persistence.dirty and game.persistence.last_error.is_empty()
	await settle(2)
	save_frame("resumed_jobs_complete")
	# Exit-tree save captures final simulation state even between periodic autosaves.
	game.get_node("ResourceClock").set_process(false)
	var final_state: Dictionary = game.persistence.snapshot()
	game.queue_free()
	await get_tree().process_frame
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	var supply := preload("res://scripts/sector_supply.gd").new(model, fleet)
	var reader := Store.new(model, fleet, supply)
	reader.path = test_path
	checks["graceful_exit_saves_last_state"] = reader.load_game().is_empty() and reader.snapshot() == final_state
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	report("checks", checks)
	finish()

func page(index: int) -> void:
	var menu: String = "Build" if index == 0 else "Ships"
	if game.hud.active_menu != menu: await click(game.hud.menu_buttons[menu].get_global_rect().get_center())

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
	await use(button)

func gather(target: int) -> void:
	var attempts: int = 0
	while game.model.materials < target and attempts < 500:
		attempts += 1
		if game.debris.pieces.is_empty():
			await get_tree().create_timer(0.4).timeout
		else:
			var candidates: Array = game.debris.pieces.filter(func(piece: Dictionary) -> bool:
				var screen: Vector2 = game.get_viewport().get_canvas_transform() * piece.point
				return screen.x > 30 and screen.x < 780 and screen.y > 275 and screen.y < game.get_viewport_rect().size.y - 85)
			if candidates.is_empty():
				await get_tree().create_timer(0.3).timeout
				continue
			var point: Vector2 = candidates[0].point
			if point.x < 30:
				await get_tree().create_timer(0.3).timeout
				continue
			var before: int = game.model.materials
			await click(game.get_viewport().get_canvas_transform() * point)
			if game.model.materials > before:
				checks["debris_collection"] = true

func use(button: Control) -> void:
	if game.hud.ship_context.is_ancestor_of(button) and not button.is_visible_in_tree():
		for ship_id: int in game.hud.ship_entries:
			if game.hud.ship_entries[ship_id].is_ancestor_of(button):
				game.hud.ship_tray.ensure_control_visible(game.hud.ship_tiles[ship_id])
				await settle(2)
				await click(game.hud.ship_tiles[ship_id].get_global_rect().get_center())
				break
	var hud = game.hud
	if not button.is_visible_in_tree():
		var menu: String = ""
		if hud.tool_buttons.values().has(button): menu = "Build"
		elif hud.region_navigation.panel.is_ancestor_of(button) or button == hud.map_button: menu = "Outposts/Regions"
		elif hud.panel.is_ancestor_of(button): menu = "Ships"
		elif hud.gate_panel.is_ancestor_of(button): menu = "Gate/Travel"
		elif hud.research_panel.is_ancestor_of(button): menu = "Research"
		elif hud.trade_panel.is_ancestor_of(button): menu = "Trade/Contacts"
		if not menu.is_empty():
			if hud.active_menu == menu: await click(hud.menu_buttons[menu].get_global_rect().get_center())
			await click(hud.menu_buttons[menu].get_global_rect().get_center())
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle(2)
	await click(button.get_global_rect().get_center())
