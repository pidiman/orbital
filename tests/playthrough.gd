extends "res://tests/autopilot/probe_base.gd"
var game: Node
var checks: Dictionary = {}

func _ready() -> void:
	await super._ready()
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	Engine.time_scale = 5.0
	report("start_frame", Engine.get_process_frames())
	save_frame("start")
	await select("habitat")
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks["power_rejection_no_spend"] = game.model.materials == 40 and game.model.modules.size() == 1
	await select("solar")
	await click(game.board.cell_position(Vector2i(3, 3)))
	checks["disconnected_no_spend"] = game.model.materials == 40
	await click(game.board.cell_position(Vector2i.ZERO))
	checks["occupied_no_spend"] = game.model.materials == 40
	await click(game.board.cell_position(Vector2i(1, 0)))
	checks["solar_placed"] = game.model.modules.size() == 2 and game.model.power_balance() == 6 and game.model.materials == 20
	await select("habitat")
	await click(game.board.cell_position(Vector2i(0, 1)))
	checks["materials_rejection_no_spend"] = game.model.materials == 20 and game.model.modules.size() == 2
	await gather(30)
	await click(game.board.cell_position(Vector2i(0, 1)))
	checks["habitat_placed"] = game.model.modules.get(Vector2(0, 58)) == "habitat"
	await gather(25)
	await select("storage")
	await click(game.board.cell_position(Vector2i(-1, 0)))
	checks["storage_placed"] = game.model.capacity == 175
	for cell: Vector2i in [Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		await gather(20)
		await select("solar")
		await click(game.board.cell_position(cell))
	checks["goal_reached"] = game.model.modules.size() == 9 and game.model.level == 3
	checks["clock_ticking"] = game.model.ticks > 0
	report("checks", checks)
	report("end_frame", Engine.get_process_frames())
	report("module_count", game.model.modules.size())
	report("materials", game.model.materials)
	report("power_balance", game.model.power_balance())
	await settle(2)
	save_frame("colony")
	finish()

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
