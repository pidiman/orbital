extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	m.materials = 1000
	m.build(Vector2(58, 0), "solar")
	m.build(Vector2(116, 0), "solar")
	var first := Vector2(0, 58)
	var second := Vector2(58, 58)
	m.build(first, "refinery")
	m.build(second, "refinery")
	checks.default_running = m.refinery_running(first) and m.refinery_running(second)
	game.hud.inspect_module(first)
	await settle(2)
	var selector: OptionButton = game.hud.refinery_selector
	await use(selector)
	await settle(1)
	checks.popup_opened = selector.get_popup().visible
	for i in range(10):
		game.hud.refresh()
		await settle(1)
	checks.popup_survives_refresh = selector.get_popup().visible
	await click(Vector2(400, 300))
	checks.click_away_closes = not selector.get_popup().visible
	await use(selector)
	selector.get_popup().set_focused_item(1)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter, true)
	await settle(2)
	checks.popup_selection = m.refinery_recipe_id(first) == "materials_tech" and not selector.get_popup().visible
	game.hud.refinery_run_button.pressed.emit()
	checks.stop_ui = not m.refinery_running(first) and m.refinery_status(first) == "Stopped" and game.hud.refinery_run_button.text.contains("Run")
	m.materials = 100
	m.minerals = 20
	for i in range(20): m.tick()
	checks.independent_stop = m.materials == 100 and m.refinery_buffer(first).is_empty() and m.refinery_buffer(second).get("materials", 0) == 30
	checks.running_full_pause = m.refinery_running(second) and m.refinery_status(second) == "buffer full · paused"
	game.hud.refinery_run_button.pressed.emit()
	for i in range(7): m.tick()
	var progress: int = m.refinery_progress[first]
	m.set_refinery_running(first, false)
	for i in range(25): m.tick()
	checks.frozen_progress = progress == 7 and m.refinery_progress[first] == progress and m.materials == 100
	var before: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(before).is_empty() and game.persistence.snapshot() == before and not m.refinery_running(first) and m.refinery_running(second)
	var path: String = "user://refinery-controls-test-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	checks.disk_save = game.persistence.save_game().is_empty()
	checks.disk_load = game.persistence.load_game().is_empty() and not m.refinery_running(first) and m.refinery_running(second)
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	m.set_refinery_running(first, true)
	for i in range(13): m.tick()
	checks.resumed = m.materials == 80 and m.refinery_buffer(first).get("tech", 0) == 1
	m.refinery_buffer(first)["tech"] = 30
	checks.tech_full_pause = m.refinery_status(first) == "buffer full · paused"
	m.set_refinery_running(first, false)
	checks.stopped_overrides_full = m.refinery_status(first) == "Stopped"
	game.hud.inspect_module(first)
	await settle(2)
	save_frame("refinery_stopped")
	var legacy: Dictionary = game.persistence.snapshot()
	var records: Dictionary = game.persistence._decode(legacy.extensions.world_locations.structures)
	for record: Dictionary in records.values(): record.state.erase("refinery_running")
	legacy.extensions.world_locations.structures = game.persistence._encode(records)
	var legacy_error: String = game.persistence.restore(legacy)
	checks.old_save_running = legacy_error.is_empty() and m.refinery_running(first) and m.refinery_running(second)
	var invalid: Dictionary = game.persistence.snapshot()
	records = game.persistence._decode(invalid.extensions.world_locations.structures)
	records[m.structure_id_at(first)].state["refinery_running"] = "false"
	invalid.extensions.world_locations.structures = game.persistence._encode(records)
	before = game.persistence.snapshot()
	checks.invalid_atomic = not game.persistence.restore(invalid).is_empty() and before == game.persistence.snapshot()
	report("checks", checks)
	finish()
