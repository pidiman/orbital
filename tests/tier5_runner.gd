extends SceneTree
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/region_supply.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	var model := StationModel.new()
	var fleet := Fleet.new(model)
	var supply := Supply.new(model, fleet)
	var store := Store.new(model, fleet, supply)
	model.materials = 100000
	model.minerals = 1000
	for x in range(1, 9): model.build(Vector2(x * 58, 0), "solar")
	var index: int = 0
	for kind: String in model.catalog:
		if not model.catalog[kind].has("upgrades"): continue
		var point := Vector2(index * 58, 58)
		if kind == "habitat": point = Vector2.ZERO
		else: model.build(point, kind)
		index += 1
		var structure_id: String = model.structure_id_at(point)
		checks[kind + " four upgrades"] = model.catalog[kind].upgrades.size() == 4
		if model.catalog[kind].has("docking"):
			for i in range(8): model.locations.add_ship(model.next_ship_id + i + 1, model.catalog[kind].docking.ship_type, model.locations.primary_station())
			model.next_ship_id += 8
			model.recalculate()
			model.changed.emit()
		for tier in range(2, 6):
			var upgrade: Dictionary = model.next_upgrade(point)
			var money: int = model.materials
			var ore: int = model.minerals
			var old: Dictionary = model.definition_at(point)
			checks["%s T%d upgrade" % [kind, tier]] = model.upgrade_module(point).is_empty() and model.tier_at(point) == tier
			checks["%s T%d cost" % [kind, tier]] = model.materials == money - int(upgrade.cost.materials) and model.minerals == ore - int(upgrade.cost.get("minerals", 0))
			var updated: Dictionary = model.definition_at(point)
			checks["%s T%d identity" % [kind, tier]] = model.structure_id_at(point) == structure_id
			if not updated.has("docking"):
				var improves: bool = updated.capacity > old.capacity or updated.power_output > old.power_output
				if updated.has("conversion"):
					improves = float(updated.conversion.output) / updated.conversion.seconds > float(old.conversion.output) / old.conversion.seconds
				checks["%s T%d improves" % [kind, tier]] = improves
			if updated.has("docking"):
				checks["%s T%d capacity" % [kind, tier]] = updated.docking.capacity > old.docking.capacity and fleet.docking.usage[structure_id].size() == int(updated.docking.capacity)
		var before: Dictionary = store.snapshot()
		checks[kind + " max atomic"] = model.upgrade_error(point).contains("Maximum") and not model.upgrade_module(point).is_empty() and store.snapshot() == before
	model.materials = 0
	model.minerals = 6
	model.tick()
	checks.refinery_T5_recipe = model.materials == 18 and model.minerals == 0
	var saved: Dictionary = store.snapshot()
	checks.high_tiers_roundtrip = store.restore(saved).is_empty() and store.snapshot() == saved
	# Real old definitions: T2 ceiling and non-upgradeable T1 docks.
	var old_model := StationModel.new()
	for definition: Dictionary in old_model.catalog.values():
		if definition.has("docking"): definition.erase("upgrades")
		elif definition.has("upgrades"): definition.upgrades.resize(1)
	var old_fleet := Fleet.new(old_model)
	var old_store := Store.new(old_model, old_fleet, Supply.new(old_model, old_fleet))
	old_model.materials = 1000
	old_model.minerals = 100
	old_model.build(Vector2(58, 0), "solar")
	old_model.upgrade_module(Vector2(58, 0))
	old_model.build(Vector2(0, 58), "miner_dock")
	old_model.buy_ship("miner")
	var legacy: Dictionary = old_store.snapshot()
	checks.legacy_unchanged = store.restore(legacy).is_empty() and store.snapshot() == legacy and model.tier_at(Vector2(58, 0)) == 2 and model.tier_at(Vector2(0, 58)) == 1
	checks.legacy_can_continue = model.upgrade_module(Vector2(58, 0)).is_empty() and model.tier_at(Vector2(58, 0)) == 3
	model.materials = 0
	var before: Dictionary = store.snapshot()
	checks.short_materials = model.upgrade_module(Vector2(0, 58)).contains("Materials") and store.snapshot() == before
	# Additional resource costs are data-only and fail atomically if insufficient.
	model.catalog.miner_dock.upgrades[0].cost = {"materials": 1, "tech": 2, "xenocrystal": 1}
	model.materials = 1
	fleet.diplomacy.inventory.tech = 1
	fleet.diplomacy.inventory.xenocrystal = 1
	before = store.snapshot()
	checks.future_currency_block = not model.upgrade_module(Vector2(0, 58)).is_empty() and store.snapshot() == before
	fleet.diplomacy.inventory.tech = 2
	checks.future_currency_pay = model.upgrade_module(Vector2(0, 58)).is_empty() and model.materials == 0 and fleet.diplomacy.inventory.tech == 0 and fleet.diplomacy.inventory.xenocrystal == 0
	var failed: Array = []
	for name: String in checks:
		if not checks[name]: failed.append(name)
	print("Tier 5 checks: ", checks.size() - failed.size(), "/", checks.size(), "; failures: ", failed)
	quit(0 if failed.is_empty() else 1)
