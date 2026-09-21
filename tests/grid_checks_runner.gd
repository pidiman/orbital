extends SceneTree
const Fleet = preload("res://scripts/mining_fleet.gd")
const Supply = preload("res://scripts/sector_supply.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	checks.data_dimensions = StationGeometry.grid_dimensions == Vector2i(17, 17)
	# Generate a real v2 snapshot under the previous 9×9 bounds.
	StationGeometry.grid_dimensions = Vector2i(9, 9)
	var old := StationModel.new()
	old.materials = 10000
	for x in range(1, 5): old.build(Vector2(x * 58, 0), "solar")
	old.build(Vector2(-58, 13.25), "storage") # Preserve continuous coordinates too.
	var old_fleet := Fleet.new(old)
	var old_supply := Supply.new(old, old_fleet)
	var old_store := Store.new(old, old_fleet, old_supply)
	old_store.path = "/tmp/orbital-legacy-grid-%d.json" % OS.get_process_id()
	checks.old_v2_written = old_store.save_game().is_empty()
	var snapshot: Dictionary = old_store.snapshot()
	var old_modules: Dictionary = old.modules.duplicate(true)
	var old_identities: Dictionary = old.locations.structures.duplicate(true)
	StationGeometry.grid_dimensions = Vector2i(17, 17)
	var model := StationModel.new()
	var fleet := Fleet.new(model)
	var supply := Supply.new(model, fleet)
	var persistence := Store.new(model, fleet, supply)
	persistence.enabled = true
	persistence.path = old_store.path
	checks.old_v2_loads = persistence.load_game().is_empty()
	DirAccess.remove_absolute(old_store.path)
	checks.exact_positions_and_ids = model.modules == old_modules and model.locations.structures == old_identities
	checks.old_snapshot_exact = persistence.snapshot() == snapshot
	for x in range(5, 9):
		checks["build outer %d" % x] = model.build(Vector2(x * 58, 0), "solar").is_empty()
	checks.boundary_inclusive = StationGeometry.contains_center(Vector2(464, -464))
	checks.outside_rejected = model.placement_error(Vector2(522, 0), "solar").contains("entire footprint")
	checks.positions_still_fixed = old_modules.keys().all(func(point: Vector2) -> bool: return model.modules.get(point) == old_modules[point])
	model.build(Vector2(0, 58), "research_lab")
	fleet.diplomacy.inventory.tech = 2
	fleet.research.research("teleportation")
	var gate := Vector2(435, 87)
	checks.gate_outer_build = model.build(gate, "teleport_gate").is_empty()
	checks.gate_four_reserved = model.footprint_points(gate, "teleport_gate").size() == 4
	for point: Vector2 in model.footprint_points(gate, "teleport_gate"):
		checks.gate_four_reserved = checks.gate_four_reserved and model.placement_error(point, "solar").contains("overlap")
	checks.gate_edge_rejected = model.placement_error(Vector2(493, -87), "teleport_gate").contains("entire footprint")
	var expanded: Dictionary = persistence.snapshot()
	checks.expanded_v2_roundtrip = persistence.restore(expanded).is_empty() and persistence.snapshot() == expanded
	checks.no_schema_change = snapshot.keys() == expanded.keys() and snapshot.extensions.keys() == expanded.extensions.keys()
	checks.demolish_gate = model.demolish_module(gate).is_empty()
	checks.freed_four_cells = model.placement_error(gate, "teleport_gate").is_empty()
	StationGeometry.grid_dimensions = Vector2i(19, 11)
	checks.rectangular_dimensions = StationGeometry.build_extent() == Vector2(522, 290) and StationGeometry.contains_center(Vector2(522, 290)) and not StationGeometry.contains_center(Vector2(0, 348))
	StationGeometry.grid_dimensions = Vector2i(17, 17)
	var failed: Array = []
	for name: String in checks:
		if not checks[name]: failed.append(name)
	print("Grid checks: ", checks.size() - failed.size(), "/", checks.size(), "; failures: ", failed)
	quit(0 if failed.is_empty() else 1)
