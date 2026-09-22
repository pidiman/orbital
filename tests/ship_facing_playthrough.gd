extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m: StationModel = game.model
	m.materials = 10000
	for x in range(1, 10): m.build(Vector2(x * 58, 0), "solar")
	m.build(Vector2(0, 58), "space_depot")
	for kind: String in m.ship_catalog: m.buy_ship(kind)
	await settle(3)
	var motion = game.ship_motion
	motion.set_process(false)
	var before: Dictionary = game.persistence.snapshot()
	checks.all_roles_smooth = true
	for id: int in m.ships:
		var target: Vector2 = motion.target_for(id)
		motion.points[id] = target - Vector2(200, 0)
		motion.angles[id] = 0.0
	motion.advance_visual(0.05)
	for id: int in m.ships:
		checks.all_roles_smooth = checks.all_roles_smooth and is_equal_approx(motion.angle_for(id), deg_to_rad(12.0)) and motion.points[id].distance_to(motion.target_for(id)) < 200.0
	checks.model_unchanged = before == game.persistence.snapshot()
	for i in range(200): motion.advance_visual(0.05)
	checks.idle_up = true
	for id: int in m.ships: checks.idle_up = checks.idle_up and absf(wrapf(motion.angle_for(id), -PI, PI)) < 0.001
	var miner: int = 1
	var target_id: int = game.fleet.asteroids.keys()[0]
	checks.dispatched = game.fleet.dispatch(target_id, miner).is_empty()
	motion.advance_visual(0.05)
	var job_before: Dictionary = game.fleet.jobs[miner].duplicate(true)
	var start_angle: float = motion.angle_for(miner)
	for i in range(15): motion.advance_visual(0.05)
	checks.turns_on_mining_leg = not is_equal_approx(start_angle, motion.angle_for(miner))
	checks.timer_unchanged = game.fleet.jobs[miner] == job_before
	game.fleet.jobs[miner].remaining = 1
	var old_angle: float = motion.angle_for(miner)
	motion.advance_visual(0.05)
	checks.return_turn_limited = absf(angle_difference(old_angle, motion.angle_for(miner))) <= deg_to_rad(12.01)
	var save: Dictionary = game.persistence.snapshot()
	checks.restore = game.persistence.restore(save).is_empty()
	checks.transient = not save.extensions.has("angles") and game.persistence.snapshot() == save
	await settle(3)
	save_frame("ship_facing")
	report("checks", checks)
	finish()
