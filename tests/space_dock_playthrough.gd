extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var m = game.model
	m.materials = 10000
	for x in range(1, 9): m.build(Vector2(x * 58, 0), "solar")
	var dock := Vector2(0, 58)
	await use(game.hud.tool_buttons.space_dock)
	await click(game.get_viewport().get_canvas_transform() * game.board.world_to_screen(dock))
	checks.build = m.modules.get(dock) == "space_dock"
	checks.only_universal_buildable = true
	for kind: String in m.catalog:
		if m.catalog[kind].has("docking") and kind != "space_dock": checks.only_universal_buildable = checks.only_universal_buildable and not game.hud.tool_buttons.has(kind)
	for role: String in m.ship_catalog: m.buy_ship(role)
	game.fleet.docking.reconcile()
	var dock_id: String = m.structure_id_at(dock)
	checks.t1 = game.fleet.docking.usage[dock_id].size() == 1
	game.hud.inspect_module(dock)
	for tier in range(2, 5):
		await use(game.hud.upgrade_button)
		checks["tier_%d" % tier] = m.tier_at(dock) == tier and game.fleet.docking.usage[dock_id].size() == tier
	checks.no_t5 = m.next_upgrade(dock).is_empty() and game.hud.upgrade_button.disabled
	checks.full_message = game.fleet.docking.waiting_message().contains("Space Dock")
	checks.mixed_roles = true
	# Every role uses the same dock, including the two roles beyond its capacity.
	for id: int in m.ships:
		checks.mixed_roles = checks.mixed_roles and game.fleet.docking.compatible(id, dock_id, game.fleet.docking.docks())
	var miner: int = 1
	checks.task_frees = game.fleet.dispatch(1, miner).is_empty() and game.fleet.docking.status(miner) == "working" and not game.fleet.docking.usage[dock_id].values().has(miner)
	var snapshot: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(snapshot).is_empty() and snapshot == game.persistence.snapshot()
	await settle(2)
	save_frame("space_dock")
	# Legacy definitions remain available for validation, but never for new construction.
	checks.migrations = true
	for kind: String in m.catalog:
		if not m.catalog[kind].has("migration_tiers"): continue
		for tier in range(1, 6):
			var old := StationModel.new()
			var fleet := MiningFleet.new(old)
			var supply := SectorSupply.new(old, fleet, 42)
			old.materials = 10000
			for x in range(1, 9): old.build(Vector2(x * 58, 0), "solar")
			var stable_id: String = old.locations.add_structure(old.locations.primary_station(), kind, dock)
			old.locations.structures[stable_id].state["tier"] = tier
			old.recalculate()
			var capacity: int = old.definition_at(dock).docking.capacity
			for i in range(capacity): old.buy_ship(old.catalog[kind].docking.ship_type)
			var store = preload("res://scripts/save_store.gd").new(old, fleet, supply)
			var error: String = store.restore(store.snapshot())
			var expected_tier: int = [2, 3, 4, 4, 4][tier - 1]
			checks.migrations = checks.migrations and error.is_empty() and old.modules[dock] == "space_dock" and old.structure_id_at(dock) == stable_id and old.tier_at(dock) == expected_tier and fleet.docking.usage[stable_id].size() == mini(capacity, 4)
			var migrated: Dictionary = store.snapshot()
			checks.migrations = checks.migrations and store.restore(migrated).is_empty() and migrated == store.snapshot()
	# Free reservations in order and verify every remaining role actually parks.
	var parked_roles: Dictionary = {}
	for id: int in m.ships.keys():
		if game.fleet.unit_busy(id): game.fleet.cancel_unit(id)
	for cycle in range(m.ships.size()):
		game.fleet.docking.reconcile()
		for id: int in m.ships.keys():
			if game.fleet.docking.status(id) != "parked": continue
			parked_roles[m.ships[id]] = true
			m.decommission_ship(id)
			break
	checks.every_role_parks = parked_roles.size() == m.ship_catalog.size()
	m.buy_ship("scout")
	var remote_id: int = m.next_ship_id
	m.locations.ships[remote_id].region = "venus"
	game.fleet.docking.reconcile()
	checks.remote_stays_homeless = game.fleet.docking.status(remote_id) == "homeless" and m.locations.ship_region(remote_id) == "venus"
	m.locations.ships[remote_id].region = "home"
	game.fleet.docking.reconcile()
	checks.demolition = m.demolish_module(dock).is_empty() and game.fleet.docking.waiting_message().contains("Space Dock")
	report("checks", checks)
	finish()
