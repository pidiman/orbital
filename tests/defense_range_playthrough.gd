extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var preferences = game.preferences
	preferences.path = "user://defense-radius-test-%d.cfg" % OS.get_process_id()
	preferences.enabled = true
	var view = game.defense_ranges
	checks.default_off = not preferences.values.get("show_defense_radius", true) and not view.visible and not view.is_processing()
	checks.settings_toggle = game.hud.settings_toggles.has("show_defense_radius") and game.hud.settings_toggles.show_defense_radius.text == "Defense radius"

	game.model.materials = 5000
	game.model.changed.emit()
	for index in range(4):
		var solar_position: Vector2 = first_buildable(game.model, "solar")
		if solar_position == Vector2.INF or not game.model.build(solar_position, "solar").is_empty():
			checks.setup_failure = "Could not place a Home Solar Panel."
			report("checks", checks)
			finish()
			return
	var defenses: Array[Vector2] = []
	var turret_position: Vector2 = Vector2.INF
	for kind: String in ["defense_turret", "missile_silo", "defense_turret", "missile_silo", "defense_turret", "defense_turret", "defense_turret", "defense_turret"]:
		var position: Vector2 = first_buildable(game.model, kind)
		if position == Vector2.INF or not game.model.build(position, kind).is_empty():
			checks.setup_failure = "Could not place eight powered Home defenses."
			report("checks", checks)
			finish()
			return
		defenses.append(position)
		if turret_position == Vector2.INF and kind == "defense_turret": turret_position = position
	checks.eight_defenses = defenses.size() == 8 and game.model.power_balance() >= 0
	game.board.inspected_position = turret_position
	game.threat_field.queue_redraw()
	await settle(3)
	save_frame("defense_radius_off_selected")
	var frame_rate_off: float = await sample_frame_rate(90)

	var snapshot_before_preference: Dictionary = game.persistence.snapshot()
	await use(game.hud.settings_button)
	await use(game.hud.settings_toggles.show_defense_radius)
	game.hud.close_panels()
	await settle(3)
	checks.enabled_visible = preferences.values.show_defense_radius and view.visible
	checks.gameplay_save_unchanged = snapshot_before_preference == game.persistence.snapshot()
	checks.active_coverage = view.is_coverage_active(turret_position) and view.coverage_radius(turret_position) > 0.0
	save_frame("defense_radius_all")
	var frame_rate_on: float = await sample_frame_rate(90)
	checks.fps = {"off": frame_rate_off, "on": frame_rate_on}
	checks.fps_within_ten_percent = frame_rate_off <= 0.0 or frame_rate_on >= frame_rate_off * 0.9

	var radius_before: float = view.coverage_radius(turret_position)
	checks.turret_upgrade = game.model.upgrade_module(turret_position).is_empty() and view.coverage_radius(turret_position) > radius_before
	save_frame("defense_radius_upgraded")
	var hp: int = game.model.module_hp(turret_position)
	game.model.damage_module(turret_position, hp)
	checks.zero_hp_dimmed = game.model.module_hp(turret_position) == 0 and not view.is_coverage_active(turret_position)
	save_frame("defense_radius_damaged")
	game.model.repair_module(turret_position, game.model.module_max_hp(turret_position))
	game.model.recalculate()

	var world = game.model.locations
	var outpost_id: String = "station:outpost:defense-test"
	world.stations[outpost_id] = {
		"id": outpost_id, "owner": "player", "region": "venus", "kind": "mining_outpost",
		"inventory": {"minerals": 0, "xenocrystal": 0, "materials": 300},
		"grid": {"columns": 9, "rows": 9}
	}
	world.add_structure(outpost_id, "mining_outpost", Vector2.ZERO)
	game.fleet.regions.records.venus.discovered = true
	game.fleet.regions.set_location("venus")
	await settle(3)
	var outpost: StationModel = game.board.model
	var outpost_solar: Vector2 = first_buildable(outpost, "solar")
	var outpost_setup_ok: bool = outpost_solar != Vector2.INF and outpost.build(outpost_solar, "solar").is_empty()
	var outpost_turret: Vector2 = first_buildable(outpost, "defense_turret") if outpost_setup_ok else Vector2.INF
	outpost_setup_ok = outpost_setup_ok and outpost_turret != Vector2.INF and outpost.build(outpost_turret, "defense_turret").is_empty()
	checks.outpost_setup = outpost_setup_ok
	game.hud.close_panels()
	await settle(3)
	checks.outpost_visible = view.visible and view.station.station_id == outpost_id and view.is_coverage_active(outpost_turret)
	save_frame("defense_radius_outpost")

	var restored = preload("res://scripts/client_preferences.gd").new()
	restored.path = preferences.path
	restored.load_preferences()
	checks.preference_restart = restored.values.get("show_defense_radius", false)
	preferences.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences.path))
	report("checks", checks)
	finish()

func first_buildable(station: StationModel, kind: String) -> Vector2:
	var dimensions: Vector2i = station.build_grid_dimensions()
	var half: Vector2i = (dimensions - Vector2i.ONE) / 2
	for y: int in range(-half.y, half.y + 1):
		for x: int in range(-half.x, half.x + 1):
			var position := Vector2(x, y) * 58.0
			if station.placement_error(position, kind).is_empty(): return position
	return Vector2.INF

func sample_frame_rate(frames: int) -> float:
	var started: int = Time.get_ticks_usec()
	for _frame in range(frames):
		await get_tree().process_frame
	var elapsed: int = maxi(1, Time.get_ticks_usec() - started)
	return float(frames) * 1000000.0 / float(elapsed)
