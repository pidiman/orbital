extends SceneTree
const SaveStore = preload("res://scripts/save_store.gd")
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/region_supply.gd")

func _initialize() -> void:
	var model := StationModel.new()
	model.apply_starting_resources()
	var fleet := Fleet.new(model)
	var supply := Supply.new(model, fleet, 7)
	var store := SaveStore.new(model, fleet, supply)
	# Exercise the persisted fields called out in the regression: ship tier,
	# automatic mining state, and module HP.
	var e := model.build(Vector2(174, 0), "solar")
	assert(e.is_empty(), e)
	e = model.build(Vector2(174, 58), "space_depot")
	assert(e.is_empty(), e)
	e = model.build(Vector2(232, 0), "space_dock")
	assert(e.is_empty(), e)
	assert(model.buy_ship("miner").is_empty())
	var miner_id: int = model.next_ship_id
	model.locations.ships[miner_id].tier = 2
	assert(model.damage_module(Vector2(174, 0), 2))
	fleet.auto_mining[miner_id] = true
	var document: Dictionary = store.snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(document))
	assert(parsed is Dictionary)
	var restored_model := StationModel.new()
	var restored_fleet := Fleet.new(restored_model)
	var restored_supply := Supply.new(restored_model, restored_fleet, 8)
	var restored_store := SaveStore.new(restored_model, restored_fleet, restored_supply)
	var error: String = restored_store.restore(parsed)
	assert(error.is_empty(), error)
	assert(restored_fleet.auto_mining.get(miner_id, false) == true)
	assert(restored_model.locations.ships[miner_id].tier == 2)
	assert(restored_model.module_hp(Vector2(174, 0)) < restored_model.module_max_hp(Vector2(174, 0)))
	var second: Dictionary = restored_store.snapshot()
	var strict_model := StationModel.new()
	var strict_fleet := Fleet.new(strict_model)
	var strict_supply := Supply.new(strict_model, strict_fleet, 9)
	var strict_store := SaveStore.new(strict_model, strict_fleet, strict_supply)
	assert(strict_store.restore(JSON.parse_string(JSON.stringify(second))).is_empty())
	print("PASS: save key round-trip (auto miner, T2 ship, damaged module)")
	quit(0)
