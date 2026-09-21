extends RefCounted
const Supply = preload("res://scripts/sector_supply.gd")
const Store = preload("res://scripts/save_store.gd")

static func run() -> Dictionary:
	var checks: Dictionary = {}
	var model := StationModel.new()
	var fleet := MiningFleet.new(model)
	fleet.regions.records = RegionModel.new(42).records
	var supply := Supply.new(model, fleet, 42)
	var store := Store.new(model, fleet, supply)
	checks.grid_33 = StationGeometry.grid_dimensions == Vector2i(33, 33)
	var original := model.modules.duplicate(true)
	model.materials = 100000
	var builds_ok: bool = true
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		for step in range(1, 17):
			builds_ok = model.build(direction * step * 58, "solar").is_empty() and builds_ok
	checks.symmetric_builds = builds_ok
	checks.positions_unchanged = original.keys().all(func(p: Vector2) -> bool: return model.modules[p] == original[p])
	checks.grid_roundtrip = store.restore(store.snapshot()).is_empty()
	var counts: Dictionary = {"materials": 0, "minerals": 0, "xenocrystal": 0}
	var amounts: Dictionary = {"materials": {}, "minerals": {}, "xenocrystal": {}}
	var quadrants: Dictionary = {}
	for i in range(20000):
		clear_pool(supply)
		supply._spawn_debris()
		var piece: Dictionary = supply.floating.home.pieces.values()[0]
		counts[piece.resource] += 1
		amounts[piece.resource][piece.amount] = true
		quadrants[Vector2(signf(piece.position.x - 0.5), signf(piece.position.y - 0.5))] = true
	checks.all_types = counts.values().all(func(n: int) -> bool: return n > 0)
	checks.rare_crystals = counts.xenocrystal < counts.minerals / 20 and counts.minerals < counts.materials
	checks.random_amounts = amounts.materials.size() == 7 and amounts.minerals.size() == 3 and amounts.xenocrystal.keys() == [1]
	checks.whole_grid = quadrants.size() == 4
	model.materials = 0
	for kind: String in counts:
		for resource: String in supply.floating_rules.types: supply.floating_rules.types[resource].weight = 1 if resource == kind else 0
		clear_pool(supply)
		supply._spawn_debris()
		var id: int = supply.next_debris_id
		var piece: Dictionary = supply.floating.home.pieces[id]
		piece.resource = kind
		piece.amount = 1
		var before: int = model.materials if kind == "materials" else (model.minerals if kind == "minerals" else fleet.diplomacy.inventory.xenocrystal)
		var received: int = supply.salvage(id)
		var after: int = model.materials if kind == "materials" else (model.minerals if kind == "minerals" else fleet.diplomacy.inventory.xenocrystal)
		checks["credit_" + kind] = (received == 0 and after == before) if kind == "xenocrystal" else (received == 1 and after == before + 1)
	supply.floating_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/floating_resources.json"))
	fleet._discover_region("venus")
	supply.advance(0.1)
	checks.remote_pool = supply.debris_in("venus").size() == 5
	var snapshot: Dictionary = store.snapshot()
	supply.advance(8.0)
	var future: Dictionary = store.snapshot()
	var error: String = store.restore(snapshot)
	checks.restore_ok = error.is_empty()
	supply.advance(8.0)
	checks.future_deterministic = store.snapshot() == future
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.extensions.erase("floating_resources")
	legacy.extensions.erase("resource_mining")
	var legacy_rocks: Dictionary = store._decode(legacy.state.fleet.asteroids)
	var legacy_bindings: Dictionary = store._decode(snapshot.extensions.resource_mining.resource_targets)
	for target: int in legacy_bindings: legacy_rocks.erase(target)
	legacy.state.fleet.asteroids = store._encode(legacy_rocks)
	checks.old_save_loads = store.restore(legacy).is_empty() and supply.floating.is_empty()
	supply.advance(0.05)
	checks.old_save_initializes = supply.floating.has("home") and supply.floating.has("venus")
	var invalid: Dictionary = store.snapshot()
	invalid.extensions.floating_resources.schema_version = 999
	var stable: Dictionary = store.snapshot()
	checks.invalid_atomic = not store.restore(invalid).is_empty() and store.snapshot() == stable
	print("Floating distribution: ", counts, "; restore error: ", error)
	return checks

static func clear_pool(supply: RefCounted) -> void:
	for target: int in supply.fleet.resource_targets.keys():
		if supply.fleet.resource_targets[target].region == "home":
			supply.fleet.asteroids.erase(target)
			supply.fleet.resource_targets.erase(target)
	supply.floating.home.pieces.clear()
