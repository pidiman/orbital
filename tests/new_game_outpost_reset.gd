extends "res://tests/outpost_playthrough.gd"

func _ready() -> void:
	await settle(3)
	game = get_tree().root.get_node("Orbital")
	game.get_node("ResourceClock").set_process(false)
	var home_save: Dictionary = game.persistence.snapshot()
	game.model.materials = 2000
	game.model.build(Vector2(58, 0), "solar")
	game.model.buy_ship("jump_ship")
	game.fleet._discover_region("venus")
	game.model.locations.ships[game.model.next_ship_id].region = "venus"
	checks.founded = game.fleet.outposts.found(game.model.next_ship_id).is_empty()
	game.fleet.regions.set_location("venus")
	var outpost_save: Dictionary = game.persistence.snapshot()
	game.save_dialogs.show_new()
	await use(game.save_dialogs.body.get_child(1))
	checks.fresh_home = game.board.model == game.model and game.model.capacity == 100 and game.model.locations.stations.size() == 1
	checks.outpost_load = game.persistence.restore(outpost_save).is_empty() and game.board.model.capacity == 300
	checks.home_load_from_outpost = game.persistence.restore(home_save).is_empty() and game.board.model == game.model and game.model.capacity == 100
	var isolated := StationModel.new()
	isolated.station_id = isolated.locations.primary_station()
	isolated.recalculate()
	checks.explicit_home = isolated.capacity == 100
	isolated.station_id = "station:outpost:missing"
	isolated.recalculate()
	checks.missing_station = isolated.capacity == 100
	isolated.locations.stations[isolated.station_id] = {"kind": "unknown"}
	isolated.recalculate()
	checks.missing_kind = isolated.capacity == 100
	var legacy: Dictionary = home_save.duplicate(true)
	legacy.extensions.erase("world_locations")
	legacy.extensions.erase("outposts")
	checks.legacy_home = game.persistence.restore(legacy).is_empty() and game.model.capacity == 100
	report("checks", checks)
	finish()
