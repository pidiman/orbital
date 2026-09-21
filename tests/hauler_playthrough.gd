extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	var fleet = game.fleet
	m.materials = 2000
	for x in range(1, 5): m.build(Vector2(x * 58, 0), "solar")
	var refinery := Vector2(0, 58)
	m.build(refinery, "refinery")
	m.build(Vector2(58, 58), "space_dock")
	await use(game.hud.ship_buttons.hauler)
	var id: int = m.next_ship_id
	checks.parks = fleet.docking.status(id) == "parked"
	m.materials = 0
	m.minerals = 100
	for tick in range(18): m.tick()
	checks.buffer_full = m.refinery_buffer(refinery).get("materials") == 30 and m.materials == 0 and m.minerals == 90 and m.refinery_status(refinery) == "buffer full · paused"
	await use(game.hud.ship_tiles[id])
	await use(game.hud.capability_buttons[id].hauling)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(refinery))
	checks.assigned = fleet.hauling.jobs.has(id) and fleet.docking.status(id) == "working"
	for tick in range(3): m.tick()
	checks.five_pickup = fleet.hauling.jobs[id].cargo.get("materials") == 5 and m.refinery_buffer(refinery).materials == 25
	var snapshot: Dictionary = game.persistence.snapshot()
	checks.inflight_roundtrip = game.persistence.restore(snapshot).is_empty() and snapshot == game.persistence.snapshot()
	for tick in range(3): m.tick()
	checks.delivered = m.materials == 5 and fleet.hauling.jobs[id].cargo.is_empty()
	for tick in range(6): m.tick()
	checks.refinery_resumes = m.minerals < 90 and m.materials >= 10
	m.materials = m.capacity
	for tick in range(6): m.tick()
	checks.storage_wait = fleet.hauling.jobs[id].waiting and not fleet.hauling.jobs[id].cargo.is_empty() and fleet.hauling.waiting_message().contains("storage full")
	game.hud.status_time = 0
	await settle(3)
	checks.bottom_message = game.hud.status_label.text.contains("Hauler waiting")
	checks.wait_roundtrip = game.persistence.restore(game.persistence.snapshot()).is_empty()
	m.materials -= 5
	m.tick()
	checks.resume_delivery = m.materials == m.capacity and fleet.hauling.jobs[id].cargo.is_empty()
	await use(game.hud.ship_tiles[id])
	await use(game.hud.capability_buttons[id].hauling)
	checks.stop_parks = not fleet.hauling.jobs.has(id) and fleet.docking.status(id) == "parked"
	# Tech uses the same buffer/hauling route, not direct production.
	m.refinery_buffer(refinery).clear()
	m.set_refinery_recipe(refinery, "materials_tech")
	m.materials = 100
	for tick in range(20): m.tick()
	checks.tech_buffered = m.refinery_buffer(refinery).tech == 1 and fleet.diplomacy.inventory.tech == 0 and m.materials == 80
	fleet.hauling.assign(id, refinery)
	for tick in range(6): m.tick()
	checks.tech_delivered = fleet.diplomacy.inventory.tech == 1
	game.hud.inspect_module(refinery)
	await settle(2)
	save_frame("hauler_refinery")
	checks.buffer_ui = game.hud.upgrade_stats.text.contains("Buffer:") and game.hud.upgrade_stats.text.contains("Haulers assigned: 1")
	# Missing additive fields = empty buffers, no assignments, old stock retained.
	fleet.hauling.cancel(id)
	var legacy: Dictionary = game.persistence.snapshot()
	legacy.extensions.erase("refinery_hauling")
	var structures: Dictionary = game.persistence._decode(legacy.extensions.world_locations.structures)
	for structure: Dictionary in structures.values(): structure.state.erase("output_buffer")
	legacy.extensions.world_locations.structures = game.persistence._encode(structures)
	var stock: int = m.materials
	checks.old_save = game.persistence.restore(legacy).is_empty() and m.refinery_buffer(refinery).is_empty() and m.materials == stock and fleet.hauling.jobs.is_empty()
	m.set_refinery_recipe(refinery, "minerals_materials")
	m.set_refinery_recipe(refinery, "materials_tech")
	m.materials = 1000
	for tick in range(620): m.tick()
	checks.tech_full_buffer = m.refinery_buffer(refinery).tech == 30 and m.materials == 400 and m.refinery_status(refinery) == "buffer full · paused"
	fleet.hauling.assign(id, refinery)
	fleet.diplomacy.inventory.tech = m.capacity
	for tick in range(6): m.tick()
	checks.tech_storage_wait = fleet.hauling.jobs[id].cargo.get("tech") == 5 and fleet.hauling.jobs[id].waiting
	var path: String = "user://hauler-test-%d.json" % OS.get_process_id()
	game.persistence.path = path
	game.persistence.enabled = true
	checks.disk_save = game.persistence.save_game().is_empty()
	var disk: Dictionary = game.persistence.snapshot()
	checks.disk_load = game.persistence.load_game().is_empty() and disk == game.persistence.snapshot()
	game.persistence.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	fleet.diplomacy.inventory.tech -= 5
	m.tick()
	checks.tech_wait_resumes = fleet.hauling.jobs[id].cargo.is_empty() and fleet.diplomacy.inventory.tech == m.capacity
	# Invalid cargo rejects atomically, without mutating either inventory.
	var invalid: Dictionary = game.persistence.snapshot()
	var hauling: Dictionary = game.persistence._decode(invalid.extensions.refinery_hauling.jobs)
	hauling[id].cargo["tech"] = 99
	invalid.extensions.refinery_hauling.jobs = game.persistence._encode(hauling)
	var stable: Dictionary = game.persistence.snapshot()
	checks.invalid_atomic = not game.persistence.restore(invalid).is_empty() and stable == game.persistence.snapshot()
	checks.demolish_pickup_safe = m.demolish_module(refinery).is_empty() and not fleet.hauling.jobs.has(id) and game.persistence.restore(game.persistence.snapshot()).is_empty()
	# A loaded ship finishes its normal delivery before Stop frees its dock slot.
	m.materials = 1000
	m.build(refinery, "refinery")
	m.materials = 0
	m.minerals = 10
	for tick in range(3): m.tick()
	fleet.hauling.assign(id, refinery)
	for tick in range(3): m.tick()
	fleet.hauling.stop(id)
	checks.stop_keeps_cargo = fleet.hauling.jobs.has(id) and fleet.hauling.jobs[id].stop_after_delivery and m.materials == 0
	for tick in range(3): m.tick()
	checks.stop_delivers_then_parks = not fleet.hauling.jobs.has(id) and m.materials == 5 and fleet.docking.status(id) == "parked"
	fleet.hauling.assign(id, refinery)
	for tick in range(3): m.tick()
	m.demolish_module(refinery)
	checks.demolish_cargo_save = game.persistence.restore(game.persistence.snapshot()).is_empty()
	for tick in range(3): m.tick()
	checks.demolish_cargo_finishes = not fleet.hauling.jobs.has(id)
	report("checks", checks)
	finish()
