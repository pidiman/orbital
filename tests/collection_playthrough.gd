extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 5.0
	await select("solar")
	await click(game.get_viewport().get_canvas_transform() * (game.board.cell_position(Vector2i(1, 0))))
	await gather(40)
	await page(1)
	game.hud.ship_buttons.material_ship.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.material_ship)
	await settle(2)
	await use(game.hud.ship_buttons.material_ship)
	var ship_id: int = game.model.next_ship_id
	await use(game.hud.command_buttons[ship_id])
	checks.no_depot_message = game.hud.status_label.text.contains("Space Depot")
	await gather(35)
	await page(0)
	await select("space_depot")
	await click(game.get_viewport().get_canvas_transform() * (game.board.cell_position(Vector2i(-1, 0))))
	checks.depot_built = game.model.modules.get(Vector2(-58, 0)) == "space_depot"
	await page(1)
	await use(game.hud.command_buttons[ship_id])
	checks.deployed = game.supply.collection.jobs.has(ship_id)
	var attempts: int = 0
	while game.supply.collection.depots[Vector2(-58, 0)].delivered < 3 and attempts < 800:
		attempts += 1
		await get_tree().physics_frame
	checks.repeated_delivery = game.supply.collection.depots[Vector2(-58, 0)].delivered >= 3
	save_frame("collection_delivering")
	game.model.materials = game.model.capacity
	game.model.changed.emit()
	attempts = 0
	while not game.supply.collection.jobs[ship_id].waiting and attempts < 400:
		attempts += 1
		await get_tree().physics_frame
	checks.waiting_with_one = game.supply.collection.jobs[ship_id].waiting and game.supply.collection.jobs[ship_id].cargo == 1
	checks.bottom_message = game.hud.status_label.text.contains("storage full")
	save_frame("collection_storage_full")
	game.get_node("ResourceClock").set_process(false)
	var snapshot: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(snapshot).is_empty() and snapshot == game.persistence.snapshot()
	await settle(2)
	checks.restored_ui = game.hud.command_buttons[ship_id].text.contains("Storage full")
	game.get_node("ResourceClock").set_process(true)
	game.hud.ship_buttons.scout.get_parent().get_parent().ensure_control_visible(game.hud.ship_buttons.scout)
	await settle(2)
	await use(game.hud.ship_buttons.scout)
	await settle(15)
	checks.resume_after_purchase = not game.supply.collection.jobs[ship_id].waiting
	checks.only_2d = no_3d(game)
	save_frame("collection_resumed")
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
