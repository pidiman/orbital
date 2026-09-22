extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var model: StationModel = game.model
	checks.starter_tubes = model.modules.values().count("connector_tube") == 5
	checks.tube_data = model.catalog.connector_tube.cost == 5 and model.catalog.connector_tube.power_use == 0 and model.catalog.connector_tube.upgrades.size() == 3
	model.materials = 1000
	var chained: String = model.build(Vector2(174, 0), "connector_tube")
	checks.chain = chained.is_empty()
	checks.visual_kind = model.modules.get(Vector2(174, 0)) == "connector_tube"
	checks.adjacent_module = model.build(Vector2(232, 0), "solar").is_empty()
	var blocked: String = model.build(Vector2(400, 400), "solar")
	checks.blocked = blocked == "Must be placed next to an existing module or tube."
	model.build(Vector2(290, 0), "connector_tube")
	checks.second_bridge = model.build(Vector2(348, 0), "solar").is_empty()
	model.research.researched["teleportation"] = true
	model.recalculate()
	checks.gate_adjacency = model.build(Vector2(435, 0), "teleport_gate").is_empty()
	var saved: Dictionary = game.persistence.snapshot()
	checks.roundtrip = game.persistence.restore(saved).is_empty() and game.persistence.snapshot() == saved
	# Outpost core is an adjacency anchor and permits a local tube/module chain.
	var fleet = game.fleet
	model.materials = 1000
	model.build(Vector2(-116, 0), "space_depot")
	model.buy_ship("jump_ship")
	var founder: int = model.next_ship_id
	fleet._discover_region("venus")
	for id: int in model.ships:
		if id == founder:
			model.locations.ships[id].region = "venus"
			if fleet.outposts.found(id).is_empty(): break
	fleet.regions.set_location("venus")
	await settle(2)
	var local: StationModel = game.board.model
	local.materials = 500
	var outpost_tube_error: String = local.build(Vector2(58, 0), "connector_tube")
	var outpost_solar_error: String = local.build(Vector2(116, 0), "solar")
	checks.outpost_tube = outpost_tube_error.is_empty()
	checks.outpost_adjacent = outpost_solar_error.is_empty()
	report("outpost_errors", {"tube": outpost_tube_error, "solar": outpost_solar_error, "station": local.station_id, "modules": local.modules})
	# A legacy layout with separated modules remains valid after restore.
	var old_model := StationModel.new()
	old_model.locations.add_structure(old_model.locations.primary_station(), "solar", Vector2(400, 400))
	old_model.recalculate()
	var old_fleet := preload("res://scripts/mining_fleet.gd").new(old_model)
	var old_supply := preload("res://scripts/region_supply.gd").new(old_model, old_fleet, 0)
	var old_store := OrbitalSaveStore.new(old_model, old_fleet, old_supply)
	var old_error: String = game.persistence.restore(old_store.snapshot())
	checks.legacy_load = old_error.is_empty() and game.model.modules.has(Vector2(400, 400))
	report("legacy_error", old_error)
	report("checks", checks)
	finish()
